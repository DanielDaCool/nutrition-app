import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/food_providers.dart';
import 'package:nutrition_app/features/food/screens/add_food_screen.dart';
import 'package:nutrition_app/features/food/screens/custom_food_screen.dart';
import 'package:nutrition_app/features/food/screens/portion_screen.dart';

import '../../helpers/test_db.dart';
import 'fixture.dart';
import 'meals_section_test.dart' show settle;

void main() {
  late AppDatabase db;
  late FoodRepository repo;
  final requests = <http.Request>[];

  setUp(() {
    db = openTestDatabase();
    repo = FoodRepository(db, () => DateTime(2026, 9, 25, 12));
    requests.clear();
  });
  tearDown(() => db.close());

  http.Client mock(http.Response Function(http.Request) handler) =>
      MockClient((req) async {
        requests.add(req);
        return handler(req);
      });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    http.Client? client,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          foodHttpClientProvider.overrideWithValue(
            client ?? mock((_) => throw StateError('no network in tests')),
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('CustomFoodScreen', () {
    testWidgets('per-serving values are saved per 100 g', (tester) async {
      await pump(tester, const CustomFoodScreen(barcode: '7290000000031'));
      expect(find.text('Add from label'), findsOneWidget);
      expect(find.text('7290000000031'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name-field')), 'Pita');
      await tester.tap(find.text('Per serving'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('serving-grams-field')),
        '80',
      );
      await tester.enterText(find.byKey(const Key('kcal-field')), '200');
      await tester.enterText(find.byKey(const Key('protein-field')), '7,2');
      await tester.enterText(find.byKey(const Key('fat-field')), '0.8');
      await tester.enterText(find.byKey(const Key('carbs-field')), '42');
      await tester.pump();
      expect(find.byKey(const Key('label-warning')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('save-food')));
      await tester.tap(find.byKey(const Key('save-food')));
      await settle(tester);

      final foods = await tester.runAsync(() => db.select(db.foods).get());
      final f = foods!.single;
      expect(f.source, 'custom');
      expect(f.name, 'Pita');
      expect(f.barcode, '7290000000031');
      expect(f.servingGrams, 80);
      expect(f.kcalPer100g, closeTo(250, 1e-9));
      expect(f.proteinPer100g, closeTo(9, 1e-9));
      expect(f.fatPer100g, closeTo(1, 1e-9));
      expect(f.carbsPer100g, closeTo(52.5, 1e-9));
      await finish(tester);
    });

    testWidgets('negative numbers block saving; odd kcal only warns', (
      tester,
    ) async {
      await pump(tester, const CustomFoodScreen());
      await tester.enterText(find.byKey(const Key('name-field')), 'Odd');
      await tester.enterText(find.byKey(const Key('kcal-field')), '500');
      await tester.enterText(find.byKey(const Key('protein-field')), '-1');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save-food')));
      await tester.tap(find.byKey(const Key('save-food')));
      await settle(tester);
      expect(find.text("Can't be negative"), findsOneWidget);
      expect(await tester.runAsync(() => db.select(db.foods).get()), isEmpty);

      await tester.enterText(find.byKey(const Key('protein-field')), '10');
      await tester.enterText(find.byKey(const Key('fat-field')), '1');
      await tester.enterText(find.byKey(const Key('carbs-field')), '10');
      await tester.pump();
      expect(find.byKey(const Key('label-warning')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('save-food')));
      await tester.tap(find.byKey(const Key('save-food')));
      await settle(tester);
      expect(
        await tester.runAsync(() => db.select(db.foods).get()),
        hasLength(1),
      );
      await finish(tester);
    });
  });

  testWidgets('PortionScreen: servings preview, favorite, add', (tester) async {
    final food = await tester.runAsync(
      () => repo.createCustom(
        const CustomFoodInput(
          name: 'Yogurt',
          per100g: Macros(kcal: 60, proteinG: 10, fatG: 0, carbsG: 4),
          servingName: '1 cup',
          servingGrams: 150,
        ),
      ),
    );
    await pump(
      tester,
      PortionScreen(food: food!, dayKey: '2026-09-25', meal: Meal.snack),
    );
    // Defaults to 1 serving = 150 g -> 90 kcal, 15 g protein.
    expect(find.text('90'), findsOneWidget);
    expect(find.text('15 g'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount-field')), '2');
    await tester.pump();
    expect(find.text('180'), findsOneWidget);

    await tester.tap(find.byKey(const Key('favorite-toggle')));
    await settle(tester);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-button')));
    await settle(tester);
    final entries = await tester.runAsync(
      () => db.select(db.foodLogEntries).get(),
    );
    expect(entries!.single.grams, 300);
    expect(entries.single.kcal, closeTo(180, 1e-9));
    expect(entries.single.meal, Meal.snack.index);
    final saved = await tester.runAsync(() => repo.foodById(food.id));
    expect(saved!.isFavorite, isTrue);
    await finish(tester);
  });

  group('AddFoodScreen', () {
    testWidgets('unknown barcode offers Add from label with the barcode', (
      tester,
    ) async {
      await pump(
        tester,
        const AddFoodScreen(dayKey: '2026-09-25', meal: Meal.lunch),
        client: mock(
          (_) => http.Response(fixtureText('off_product_not_found.json'), 404),
        ),
      );
      final state = tester.state(find.byType(AddFoodScreen)) as dynamic;
      // Same path as a camera scan; the future ends when the flow closes.
      state.lookupBarcode('7290000000017');
      await settle(tester);
      expect(find.textContaining("isn't in Open Food Facts"), findsOneWidget);
      await tester.tap(find.text('Add from label'));
      await settle(tester);
      expect(find.byType(CustomFoodScreen), findsOneWidget);
      expect(find.text('7290000000017'), findsOneWidget);
      expect(requests.single.url.path, '/api/v2/product/7290000000017');
      await finish(tester);
    });

    testWidgets('search runs on submit only and shows results', (tester) async {
      await pump(
        tester,
        const AddFoodScreen(dayKey: '2026-09-25', meal: Meal.lunch),
        client: mock(
          (_) => http.Response.bytes(
            utf8.encode(fixtureText('usda_search.json')),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await tester.tap(find.text('Search'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('search-field')), 'chicken');
      await tester.pump();
      expect(requests, isEmpty); // typing doesn't search
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(requests, hasLength(1));
      expect(requests.single.url.host, 'api.nal.usda.gov');
      expect(
        find.text('Chicken, breast, boneless, skinless, raw'),
        findsOneWidget,
      );
      expect(find.text('107 kcal/100 g'), findsOneWidget);
      await finish(tester);
    });
  });
}
