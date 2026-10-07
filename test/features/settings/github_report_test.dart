import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/features/settings/github_report.dart';

void main() {
  group('githubReportAvailable', () {
    test('false with no client id', () {
      expect(githubReportAvailable(clientId: ''), isFalse);
    });

    test('true with a client id', () {
      expect(githubReportAvailable(clientId: 'abc123'), isTrue);
    });
  });

  group('requestGithubDeviceCode', () {
    test('null with no client id, no request sent', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });
      final code = await requestGithubDeviceCode(client, clientId: '');
      expect(code, isNull);
      expect(called, isFalse);
    });

    test('parses a successful response', () async {
      final client = MockClient((request) async {
        expect(request.url, Uri.parse('https://github.com/login/device/code'));
        expect(request.method, 'POST');
        final body = Uri.splitQueryString(request.body);
        expect(body['client_id'], 'abc123');
        expect(body['scope'], 'public_repo');
        return http.Response(
          jsonEncode({
            'device_code': 'devcode',
            'user_code': 'ABCD-1234',
            'verification_uri': 'https://github.com/login/device',
            'expires_in': 900,
            'interval': 5,
          }),
          200,
        );
      });
      final code = await requestGithubDeviceCode(client, clientId: 'abc123');
      expect(code, isNotNull);
      expect(code!.deviceCode, 'devcode');
      expect(code.userCode, 'ABCD-1234');
      expect(code.verificationUri, 'https://github.com/login/device');
      expect(code.expiresInSeconds, 900);
      expect(code.intervalSeconds, 5);
    });

    test('defaults interval and expiry when missing', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'device_code': 'devcode',
            'user_code': 'ABCD-1234',
            'verification_uri': 'https://github.com/login/device',
          }),
          200,
        );
      });
      final code = await requestGithubDeviceCode(client, clientId: 'abc123');
      expect(code!.intervalSeconds, 5);
      expect(code.expiresInSeconds, 900);
    });

    test('null on a non-2xx response', () async {
      final client = MockClient((request) async => http.Response('', 400));
      final code = await requestGithubDeviceCode(client, clientId: 'abc123');
      expect(code, isNull);
    });

    test('null when the request throws', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final code = await requestGithubDeviceCode(client, clientId: 'abc123');
      expect(code, isNull);
    });
  });

  group('pollGithubAccessToken', () {
    test('authorized with the access token', () async {
      final client = MockClient((request) async {
        expect(
          request.url,
          Uri.parse('https://github.com/login/oauth/access_token'),
        );
        return http.Response(jsonEncode({'access_token': 'tok123'}), 200);
      });
      final result = await pollGithubAccessToken(
        client,
        deviceCode: 'devcode',
        clientId: 'abc123',
      );
      expect(result.outcome, GithubPollOutcome.authorized);
      expect(result.accessToken, 'tok123');
    });

    test('pending while the user has not authorized yet', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'authorization_pending'}), 200),
      );
      final result = await pollGithubAccessToken(client, deviceCode: 'devcode');
      expect(result.outcome, GithubPollOutcome.pending);
    });

    test('slowDown tells the caller to back off', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'slow_down'}), 200),
      );
      final result = await pollGithubAccessToken(client, deviceCode: 'devcode');
      expect(result.outcome, GithubPollOutcome.slowDown);
    });

    test('deniedOrExpired on expired_token and access_denied', () async {
      for (final error in ['expired_token', 'access_denied']) {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': error}), 200),
        );
        final result = await pollGithubAccessToken(
          client,
          deviceCode: 'devcode',
        );
        expect(result.outcome, GithubPollOutcome.deniedOrExpired);
      }
    });

    test('error on a non-2xx response', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final result = await pollGithubAccessToken(client, deviceCode: 'devcode');
      expect(result.outcome, GithubPollOutcome.error);
    });

    test('error when the request throws', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final result = await pollGithubAccessToken(client, deviceCode: 'devcode');
      expect(result.outcome, GithubPollOutcome.error);
    });
  });

  group('createGithubIssueAsUser', () {
    test(
      'true on a 2xx response, with the right body and auth header',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url,
            Uri.parse(
              'https://api.github.com/repos/DanielDaCool/nutrition-app/issues',
            ),
          );
          expect(request.headers['Authorization'], 'Bearer tok123');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['title'], 'User report (Android, 0.0.0 (build 2))');
          expect(
            body['body'],
            'It crashed\n\n---\nVersion: 0.0.0 (build 2)\nPlatform: Android',
          );
          expect(body['labels'], ['user report']);
          return http.Response('', 201);
        });
        final ok = await createGithubIssueAsUser(
          client,
          accessToken: 'tok123',
          description: 'It crashed',
          versionLabel: '0.0.0 (build 2)',
          platform: 'Android',
        );
        expect(ok, isTrue);
      },
    );

    test('false on a non-2xx response', () async {
      final client = MockClient((request) async => http.Response('', 403));
      final ok = await createGithubIssueAsUser(
        client,
        accessToken: 'tok123',
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
      );
      expect(ok, isFalse);
    });

    test('false when the request throws', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final ok = await createGithubIssueAsUser(
        client,
        accessToken: 'tok123',
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
      );
      expect(ok, isFalse);
    });
  });
}
