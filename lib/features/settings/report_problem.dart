// Sends a "Report a problem" message to the report-relay Cloudflare Worker
// (tools/report-relay/), which files it as a GitHub issue. See that
// directory's README for how the Worker is deployed and configured.
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The Worker's URL, baked in at build time with
/// `--dart-define=REPORT_RELAY_URL=...`. Empty until Daniel deploys the
/// Worker and sets the secret in CI, in which case sending always fails
/// gracefully (see [sendProblemReport]).
const reportRelayUrl = String.fromEnvironment('REPORT_RELAY_URL');

/// How long to wait for the relay before giving up.
const reportRelayTimeout = Duration(seconds: 10);

/// "Android" or "Web", for the report.
String reportProblemPlatform({required bool isWeb}) =>
    isWeb ? 'Web' : 'Android';

/// Sends [description] (plus [versionLabel] and [platform]) to the report
/// relay at [url] (the deployed Worker's URL; defaults to [reportRelayUrl]).
/// Never throws: a missing URL, a network failure, a timeout or a non-2xx
/// response all come back as `false` so the UI can show "couldn't send, try
/// again" without crashing.
Future<bool> sendProblemReport(
  http.Client client, {
  required String description,
  required String versionLabel,
  required String platform,
  String url = reportRelayUrl,
}) async {
  if (url.isEmpty) return false;
  try {
    final response = await client
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'description': description,
            'version': versionLabel,
            'platform': platform,
          }),
        )
        .timeout(reportRelayTimeout);
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
