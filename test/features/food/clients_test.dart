import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/features/food/data/off_client.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
import 'package:nutrition_app/features/food/data/usda_client.dart';

import 'fixture.dart';

http.Response jsonResponse(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Matcher throwsApi(FoodApiErrorKind kind) => throwsA(
  isA<FoodApiException>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.message, 'message', isNotEmpty),
);

void main() {
  group('OffClient', () {
    test(
      'product: v2 endpoint, only needed fields, custom User-Agent',
      () async {
        late http.Request seen;
        final client = OffClient(
          MockClient((req) async {
            seen = req;
            return jsonResponse(fixtureText('off_product_hummus.json'), 200);
          }),
        );
        final f = await client.product('7290000066318');
        expect(f!.name, 'Hummus Salad');
        expect(seen.method, 'GET');
        expect(seen.url.host, 'world.openfoodfacts.org');
        expect(seen.url.path, '/api/v2/product/7290000066318');
        expect(seen.url.queryParameters['fields'], contains('nutriments'));
        expect(seen.url.queryParameters['fields'], contains('product_name_he'));
        expect(
          seen.headers['User-Agent'],
          'NutritionApp/0.1 (+https://github.com/DanielDaCool/nutrition-app)',
        );
      },
    );

    test('404 and status 0 are "not found" (null)', () async {
      final c404 = OffClient(
        MockClient(
          (_) async =>
              jsonResponse(fixtureText('off_product_not_found.json'), 404),
        ),
      );
      expect(await c404.product('7290000000017'), isNull);
      final c200 = OffClient(
        MockClient(
          (_) async =>
              jsonResponse(fixtureText('off_product_not_found.json'), 200),
        ),
      );
      expect(await c200.product('7290000000017'), isNull);
    });

    test('invalid barcode is rejected without a request', () async {
      var calls = 0;
      final c = OffClient(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(() => c.product('abc'), throwsApi(FoodApiErrorKind.notFound));
      expect(calls, 0);
    });

    test('429, 5xx, bad JSON and network errors map to clear errors', () {
      OffClient withStatus(int s, [String body = '{}']) =>
          OffClient(MockClient((_) async => http.Response(body, s)));
      expect(
        withStatus(429).product('7290000066318'),
        throwsApi(FoodApiErrorKind.rateLimited),
      );
      expect(
        withStatus(503).product('7290000066318'),
        throwsApi(FoodApiErrorKind.server),
      );
      expect(
        withStatus(403).search('hummus'),
        throwsApi(FoodApiErrorKind.badResponse),
      );
      expect(
        withStatus(200, '<html>').product('7290000066318'),
        throwsApi(FoodApiErrorKind.badResponse),
      );
      expect(
        OffClient(MockClient((_) => throw http.ClientException('reset')))
            .product('7290000066318'),
        throwsApi(FoodApiErrorKind.network),
      );
      expect(
        OffClient(
          MockClient((_) => throw const SocketException('Failed host lookup')),
        ).search('hummus'),
        throwsApi(FoodApiErrorKind.network),
      );
    });

    test('search: legacy full-text endpoint, parsed results', () async {
      late Uri seen;
      final c = OffClient(
        MockClient((req) async {
          seen = req.url;
          return jsonResponse(fixtureText('off_search.json'), 200);
        }),
      );
      final list = await c.search('  cottage ');
      expect(list, hasLength(2));
      expect(seen.path, '/cgi/search.pl');
      expect(seen.queryParameters['search_terms'], 'cottage');
      expect(seen.queryParameters['json'], '1');
      expect(await c.search('   '), isEmpty);
    });

    test('local limit: 10 searches per minute', () async {
      var now = DateTime(2026, 9, 25, 12);
      var calls = 0;
      final c = OffClient(
        MockClient((_) async {
          calls++;
          return jsonResponse('{"products":[]}', 200);
        }),
        clock: () => now,
      );
      for (var i = 0; i < 10; i++) {
        await c.search('q$i');
      }
      expect(c.search('eleventh'), throwsApi(FoodApiErrorKind.rateLimited));
      expect(calls, 10);
      // Product reads have their own budget.
      await c.product('7290000066318').catchError((_) => null);
      expect(calls, 11);
      now = now.add(const Duration(seconds: 61));
      await c.search('later');
      expect(calls, 12);
    });

    test('local limit: 15 product reads per minute', () async {
      final now = DateTime(2026, 9, 25, 12);
      final c = OffClient(
        MockClient(
          (_) async =>
              jsonResponse(fixtureText('off_product_not_found.json'), 404),
        ),
        clock: () => now,
      );
      for (var i = 0; i < 15; i++) {
        await c.product('7290000000017');
      }
      expect(
        c.product('7290000000017'),
        throwsApi(FoodApiErrorKind.rateLimited),
      );
    });
  });

  group('UsdaClient', () {
    test(
      'POST /v1/foods/search with Foundation + SR Legacy and api_key',
      () async {
        late http.Request seen;
        final c = UsdaClient(
          MockClient((req) async {
            seen = req;
            return jsonResponse(fixtureText('usda_search.json'), 200);
          }),
          apiKey: 'TESTKEY',
        );
        final list = await c.search('chicken breast');
        expect(list, hasLength(4));
        expect(seen.method, 'POST');
        expect(
          seen.url.toString(),
          'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=TESTKEY',
        );
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['query'], 'chicken breast');
        expect(body['dataType'], ['Foundation', 'SR Legacy']);
      },
    );

    test('default key is DEMO_KEY', () {
      expect(
        UsdaClient(MockClient((_) async => http.Response('', 200))).apiKey,
        'DEMO_KEY',
      );
    });

    test('errors', () {
      UsdaClient withStatus(int s) =>
          UsdaClient(MockClient((_) async => http.Response('{"error":{}}', s)));
      expect(
        withStatus(429).search('rice'),
        throwsApi(FoodApiErrorKind.rateLimited),
      );
      expect(
        withStatus(403).search('rice'),
        throwsApi(FoodApiErrorKind.badKey),
      );
      expect(
        withStatus(500).search('rice'),
        throwsApi(FoodApiErrorKind.server),
      );
      expect(
        UsdaClient(MockClient((_) => throw http.ClientException('offline')))
            .search('rice'),
        throwsApi(FoodApiErrorKind.network),
      );
    });
  });
}
