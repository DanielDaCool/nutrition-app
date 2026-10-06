import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/core/update_check_repository.dart';
import 'package:nutrition_app/data/db/database.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  final now = DateTime(2026, 10, 6, 12);

  http.Client clientReturning(int status, [Object? body]) =>
      MockClient((request) async {
        expect(request.headers['User-Agent'], isNotNull);
        return http.Response(body == null ? '' : jsonEncode(body), status);
      });

  test('a fresh check asks GitHub and caches the tag', () async {
    final client = clientReturning(200, {'tag_name': 'v0.1'});
    final tag = await latestReleaseTag(db, client, now);
    expect(tag, 'v0.1');
    expect(await loadUpdateCheckedAt(db), now.toUtc());
  });

  test(
    'a second check within a day reuses the cached tag, no request',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(jsonEncode({'tag_name': 'v0.1'}), 200);
      });
      await latestReleaseTag(db, client, now);
      final tag = await latestReleaseTag(
        db,
        client,
        now.add(const Duration(hours: 1)),
      );
      expect(tag, 'v0.1');
      expect(calls, 1);
    },
  );

  test('a check a day later asks again', () async {
    await latestReleaseTag(db, clientReturning(200, {'tag_name': 'v0.1'}), now);
    final tag = await latestReleaseTag(
      db,
      clientReturning(200, {'tag_name': 'v0.2'}),
      now.add(const Duration(days: 1)),
    );
    expect(tag, 'v0.2');
  });

  test('a failed request keeps the previously known tag', () async {
    await latestReleaseTag(db, clientReturning(200, {'tag_name': 'v0.1'}), now);
    final tag = await latestReleaseTag(
      db,
      clientReturning(500),
      now.add(const Duration(days: 1)),
    );
    expect(tag, 'v0.1');
  });

  test('a thrown exception keeps the previously known tag', () async {
    await latestReleaseTag(db, clientReturning(200, {'tag_name': 'v0.1'}), now);
    final failing = MockClient((request) async => throw Exception('offline'));
    final tag = await latestReleaseTag(
      db,
      failing,
      now.add(const Duration(days: 1)),
    );
    expect(tag, 'v0.1');
  });

  test('never checked and nothing cached reads as null', () async {
    expect(await loadUpdateCheckedAt(db), isNull);
  });

  test('dismissal round-trips', () async {
    expect(await loadUpdateDismissedTag(db), isNull);
    await saveUpdateDismissedTag(db, 'v0.1');
    expect(await loadUpdateDismissedTag(db), 'v0.1');
  });
}
