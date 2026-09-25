import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/sync/pc_sync_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('syncNow throws when no token is saved', () async {
    final repo = PcSyncRepository(db, DateTime.now, client: MockClient((_) async {
      fail('should not call the network without a token');
    }));
    await expectLater(repo.syncNow(), throwsA(isA<PcSyncException>()));
  });

  test('syncNow creates a gist on first sync and remembers its id', () async {
    http.Request? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.github.com/gists');
      expect(request.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['public'], false);
      return http.Response(
        jsonEncode({'id': 'abc123', 'html_url': 'https://gist.github.com/abc123'}),
        201,
      );
    });
    final repo = PcSyncRepository(db, () => DateTime(2026, 1, 1), client: client);
    await repo.saveToken('test-token');

    final result = await repo.syncNow();

    expect(result.gistId, 'abc123');
    expect(result.gistUrl, 'https://gist.github.com/abc123');
    expect(await repo.readGistId(), 'abc123');
    expect(sentRequest, isNotNull);
  });

  test('syncNow patches the existing gist on later syncs', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (requests.length == 1) {
        return http.Response(
          jsonEncode({'id': 'g1', 'html_url': 'https://gist.github.com/g1'}),
          201,
        );
      }
      expect(request.method, 'PATCH');
      expect(request.url.toString(), 'https://api.github.com/gists/g1');
      return http.Response(
        jsonEncode({'id': 'g1', 'html_url': 'https://gist.github.com/g1'}),
        200,
      );
    });
    final repo = PcSyncRepository(db, () => DateTime(2026, 1, 1), client: client);
    await repo.saveToken('test-token');

    await repo.syncNow();
    await repo.syncNow();

    expect(requests, hasLength(2));
  });

  test('syncNow surfaces a PcSyncException on an error response', () async {
    final client = MockClient((_) async => http.Response('nope', 401));
    final repo = PcSyncRepository(db, () => DateTime(2026, 1, 1), client: client);
    await repo.saveToken('bad-token');

    await expectLater(repo.syncNow(), throwsA(isA<PcSyncException>()));
  });
}
