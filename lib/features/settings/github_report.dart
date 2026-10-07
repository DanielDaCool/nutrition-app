// GitHub's OAuth device flow, so "Report a problem" can file the issue
// directly under the user's own GitHub account instead of going through the
// anonymous relay (report_problem.dart). Device flow needs only the OAuth
// App's client id — a public value, never a secret — so the app never
// holds a token that isn't the user's own.
//
// Android only: github.com's device-flow endpoints don't send
// Access-Control-Allow-Origin, so a browser can't call them directly; see
// AppFeature.githubReport.
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The GitHub OAuth App's client id, baked in at build time with
/// `--dart-define=GITHUB_OAUTH_CLIENT_ID=...`. Empty until Daniel creates
/// the OAuth App and sets it in CI, in which case [githubReportAvailable]
/// is false and the "post as me" choice is hidden — same graceful
/// degradation as [reportRelayUrl] in report_problem.dart.
const githubOAuthClientId = String.fromEnvironment('GITHUB_OAUTH_CLIENT_ID');

/// Scope needed to create an issue on this (public) repo as the signed-in
/// user.
const githubReportScope = 'public_repo';

const _repo = 'DanielDaCool/nutrition-app';

const _requestTimeout = Duration(seconds: 10);

/// Whether the "post as me on GitHub" choice should be offered at all.
bool githubReportAvailable({String clientId = githubOAuthClientId}) =>
    clientId.isNotEmpty;

/// A device code from GitHub's `/login/device/code`, to show the user while
/// they authorize in their browser.
class GithubDeviceCode {
  const GithubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.intervalSeconds,
    required this.expiresInSeconds,
  });

  /// Opaque code polled with [pollGithubAccessToken]; never shown to the
  /// user.
  final String deviceCode;

  /// Short code the user types in at [verificationUri].
  final String userCode;

  /// Where the user authorizes (normally `https://github.com/login/device`).
  final String verificationUri;

  /// Minimum delay between polls.
  final int intervalSeconds;

  /// How long [deviceCode] stays valid.
  final int expiresInSeconds;
}

/// Starts GitHub's OAuth device flow. Returns null on any failure (network,
/// timeout, non-2xx, unexpected body) so the UI can show a generic error.
Future<GithubDeviceCode?> requestGithubDeviceCode(
  http.Client client, {
  String clientId = githubOAuthClientId,
}) async {
  if (clientId.isEmpty) return null;
  try {
    final response = await client
        .post(
          Uri.parse('https://github.com/login/device/code'),
          headers: const {'Accept': 'application/json'},
          body: {'client_id': clientId, 'scope': githubReportScope},
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final deviceCode = body['device_code'] as String?;
    final userCode = body['user_code'] as String?;
    final verificationUri = body['verification_uri'] as String?;
    if (deviceCode == null || userCode == null || verificationUri == null) {
      return null;
    }
    return GithubDeviceCode(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verificationUri,
      intervalSeconds: (body['interval'] as num?)?.toInt() ?? 5,
      expiresInSeconds: (body['expires_in'] as num?)?.toInt() ?? 900,
    );
  } catch (_) {
    return null;
  }
}

/// What one poll of GitHub's token endpoint found. The caller waits
/// [GithubDeviceCode.intervalSeconds] between polls (longer after
/// [slowDown]) and gives up after [GithubDeviceCode.expiresInSeconds].
enum GithubPollOutcome {
  /// [GithubPollResult.accessToken] is set; authorization is done.
  authorized,

  /// The user hasn't finished authorizing yet; poll again.
  pending,

  /// Polled too fast; wait longer before the next poll.
  slowDown,

  /// The code expired or the user declined; the flow must restart.
  deniedOrExpired,

  /// A network or server error; safe to retry.
  error,
}

class GithubPollResult {
  const GithubPollResult(this.outcome, [this.accessToken]);

  final GithubPollOutcome outcome;
  final String? accessToken;
}

/// One poll of `/login/oauth/access_token` for [deviceCode]. Never throws.
Future<GithubPollResult> pollGithubAccessToken(
  http.Client client, {
  required String deviceCode,
  String clientId = githubOAuthClientId,
}) async {
  try {
    final response = await client
        .post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: const {'Accept': 'application/json'},
          body: {
            'client_id': clientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const GithubPollResult(GithubPollOutcome.error);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    if (token != null) {
      return GithubPollResult(GithubPollOutcome.authorized, token);
    }
    switch (body['error'] as String?) {
      case 'authorization_pending':
        return const GithubPollResult(GithubPollOutcome.pending);
      case 'slow_down':
        return const GithubPollResult(GithubPollOutcome.slowDown);
      case 'expired_token':
      case 'access_denied':
        return const GithubPollResult(GithubPollOutcome.deniedOrExpired);
      default:
        return const GithubPollResult(GithubPollOutcome.error);
    }
  } catch (_) {
    return const GithubPollResult(GithubPollOutcome.error);
  }
}

/// Files [description] as an issue on this repo directly under the
/// signed-in user, with the same title/body format and label as the relay
/// (report_problem.dart / tools/report-relay/worker.js). Never throws.
Future<bool> createGithubIssueAsUser(
  http.Client client, {
  required String accessToken,
  required String description,
  required String versionLabel,
  required String platform,
}) async {
  try {
    final response = await client
        .post(
          Uri.parse('https://api.github.com/repos/$_repo/issues'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
            'User-Agent': 'nutrition-app',
          },
          body: jsonEncode({
            'title': 'User report ($platform, $versionLabel)',
            'body':
                '$description\n\n---\nVersion: $versionLabel\nPlatform: $platform',
            'labels': ['user report'],
          }),
        )
        .timeout(_requestTimeout);
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
