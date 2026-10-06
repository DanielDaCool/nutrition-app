import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/features/settings/report_problem.dart';

void main() {
  group('reportProblemPlatform', () {
    test('Android when not web', () {
      expect(reportProblemPlatform(isWeb: false), 'Android');
    });

    test('Web on the web build', () {
      expect(reportProblemPlatform(isWeb: true), 'Web');
    });
  });

  group('sendProblemReport', () {
    // reportRelayUrl is empty in test builds (no --dart-define); that path
    // is covered explicitly, and every other case passes url: to exercise
    // the actual request without needing a build-time define.
    test('false when no relay URL was baked in', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });
      final ok = await sendProblemReport(
        client,
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
      );
      expect(ok, isFalse);
      expect(called, isFalse);
    });

    test('true on a 2xx response, with the right body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['description'], 'It crashed');
        expect(body['version'], '0.0.0 (build 2)');
        expect(body['platform'], 'Android');
        return http.Response('', 201);
      });
      final ok = await sendProblemReport(
        client,
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
        url: 'https://relay.example/report',
      );
      expect(ok, isTrue);
    });

    test('false on a non-2xx response', () async {
      final client = MockClient((request) async => http.Response('', 429));
      final ok = await sendProblemReport(
        client,
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
        url: 'https://relay.example/report',
      );
      expect(ok, isFalse);
    });

    test('false when the request throws', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final ok = await sendProblemReport(
        client,
        description: 'It crashed',
        versionLabel: '0.0.0 (build 2)',
        platform: 'Android',
        url: 'https://relay.example/report',
      );
      expect(ok, isFalse);
    });
  });
}
