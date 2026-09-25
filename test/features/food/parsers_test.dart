import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/data/off_parser.dart';
import 'package:nutrition_app/features/food/data/usda_parser.dart';

import 'fixture.dart';

void main() {
  group('Open Food Facts', () {
    test('full product: English name, first brand, serving grams', () {
      final f = parseOffProductResponse(
        fixtureJson('off_product_hummus.json'),
        barcode: '7290000066318',
      )!;
      expect(f.source, 'off');
      expect(f.externalId, '7290000066318');
      expect(f.name, 'Hummus Salad');
      expect(f.brand, 'Sabra');
      expect(f.kcalPer100g, 282);
      expect(f.proteinPer100g, 7.5);
      expect(f.fatPer100g, 22);
      expect(f.carbsPer100g, 14);
      expect(f.servingGrams, 50);
      expect(f.servingName, '50 g');
      expect(f.isComplete, isTrue);
    });

    test('kJ-only product: kcal = kJ / 4.184, Hebrew generic name, '
        'string numbers', () {
      final f = parseOffProductResponse(
        fixtureJson('off_product_kj_only.json'),
        barcode: '7290011194246',
      )!;
      expect(f.name, 'לחם מחיטה מלאה');
      expect(f.brand, isNull);
      expect(f.kcalPer100g, closeTo(1046 / 4.184, 1e-6));
      expect(f.proteinPer100g, 10.5);
      expect(f.carbsPer100g, 41.2);
      expect(f.servingGrams, 60);
    });

    test('product without nutriments is incomplete', () {
      final f = parseOffProductResponse(
        fixtureJson('off_product_no_nutrition.json'),
        barcode: '7290104720064',
      )!;
      expect(f.name, 'Cottage Cheese 5%');
      expect(f.kcalPer100g, isNull);
      expect(f.proteinPer100g, isNull);
      expect(f.servingGrams, isNull); // 250ml isn't grams
      expect(f.isComplete, isFalse);
    });

    test('status 0 means not found', () {
      expect(
        parseOffProductResponse(
          fixtureJson('off_product_not_found.json'),
          barcode: '7290000000017',
        ),
        isNull,
      );
    });

    test('search skips nameless products and parses energy_100g as kJ', () {
      final list = parseOffSearchResponse(fixtureJson('off_search.json'));
      expect(list.map((f) => f.name), ['Cottage cheese 5%', 'Greek Yogurt 0%']);
      expect(list[0].servingGrams, 250);
      expect(list[1].kcalPer100g, closeTo(100, 1e-9));
      expect(list[1].fatPer100g, isNull);
      expect(list[1].servingGrams, isNull); // ml
    });

    test('missing fields do not throw', () {
      expect(parseOffProduct({}), isNull);
      expect(parseOffProduct({'code': '123456'}), isNull);
      final f = parseOffProduct({
        'code': '123456',
        'product_name': 'X',
        'nutriments': 'oops',
      })!;
      expect(f.isComplete, isFalse);
      expect(parseOffSearchResponse({}), isEmpty);
    });
  });

  group('USDA', () {
    final foods = parseUsdaSearchResponse(fixtureJson('usda_search.json'));

    test('Foundation food without 1008 falls back to 2047', () {
      final f = foods.firstWhere((f) => f.externalId == '2646170');
      expect(f.source, 'usda');
      expect(f.name, 'Chicken, breast, boneless, skinless, raw');
      expect(f.kcalPer100g, 107);
      expect(f.proteinPer100g, 22.5);
      expect(f.fatPer100g, 1.93);
      expect(f.carbsPer100g, 0);
      expect(f.brand, isNull);
    });

    test('SR Legacy food uses 1008', () {
      final f = foods.firstWhere((f) => f.externalId == '171477');
      expect(f.kcalPer100g, 165);
      expect(f.proteinPer100g, 31);
    });

    test('kJ-only energy is converted; no energy is incomplete', () {
      final water = foods.firstWhere((f) => f.externalId == '999999');
      expect(water.kcalPer100g, 0);
      expect(water.isComplete, isTrue);
      final mystery = foods.firstWhere((f) => f.externalId == '888888');
      expect(mystery.isComplete, isFalse);
    });

    test('bad entries are skipped', () {
      expect(parseUsdaFood({'description': 'no id'}), isNull);
      expect(parseUsdaSearchResponse({'foods': 'x'}), isEmpty);
    });
  });
}
