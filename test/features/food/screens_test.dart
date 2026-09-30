import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
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

    testWidgets('switching the basis converts the numbers already entered', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // An incomplete Open Food Facts product: per 100 g, no fat.
      await pump(
        tester,
        const CustomFoodScreen(
          draft: RemoteFood(
            source: 'off',
            externalId: '7290000000055',
            name: 'Granola',
            kcalPer100g: 250,
            proteinPer100g: 10,
            carbsPer100g: 40,
            servingGrams: 30,
          ),
        ),
      );
      String field(String key) =>
          tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
      expect(field('kcal-field'), '250');

      // The label gives fat per serving, so switch to per serving.
      await tester.tap(find.text('Per serving'));
      await tester.pump();
      expect(field('kcal-field'), '75');
      expect(field('protein-field'), '3');
      expect(field('carbs-field'), '12');
      await tester.enterText(find.byKey(const Key('fat-field')), '1.5');
      await tester.pump();
      expect(find.textContaining('Per 100 g: 250 kcal'), findsOneWidget);

      // Back to per 100 g: the same food, fat converted too.
      await tester.tap(find.text('Per 100 g'));
      await tester.pump();
      expect(field('kcal-field'), '250');
      expect(field('fat-field'), '5');

      // Per serving again, then a bigger serving: converted numbers follow.
      await tester.tap(find.text('Per serving'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('serving-grams-field')),
        '40',
      );
      await tester.pump();
      expect(field('kcal-field'), '100');
      expect(field('fat-field'), '2');

      await tester.ensureVisible(find.byKey(const Key('save-food')));
      await tester.tap(find.byKey(const Key('save-food')));
      await settle(tester);
      final f = (await tester.runAsync(() => db.select(db.foods).get()))!
          .single;
      expect(f.kcalPer100g, closeTo(250, 1e-9));
      expect(f.proteinPer100g, closeTo(10, 1e-9));
      expect(f.fatPer100g, closeTo(5, 1e-9));
      expect(f.carbsPer100g, closeTo(40, 1e-9));
      expect(f.servingGrams, 40);
      await finish(tester);
    });

    testWidgets('per serving needs a serving size to convert numbers', (
      tester,
    ) async {
      await pump(tester, const CustomFoodScreen());
      await tester.enterText(find.byKey(const Key('kcal-field')), '300');
      await tester.pump();
      await tester.tap(find.text('Per serving'));
      await tester.pump();
      expect(
        find.text(
          'Enter the serving size first, so the values can be converted.',
        ),
        findsOneWidget,
      );
      expect(find.text('Energy per 100 g'), findsOneWidget);
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

    testWidgets('macros the source lacks are flagged and required', (
      tester,
    ) async {
      // Tall enough that the whole form is built at once.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        const CustomFoodScreen(
          draft: RemoteFood(
            source: 'off',
            externalId: '7290000000048',
            name: 'Crackers',
            kcalPer100g: 420,
            carbsPer100g: 70,
          ),
        ),
      );
      expect(find.byKey(const Key('missing-macros')), findsOneWidget);
      expect(find.textContaining('no protein or fat'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('save-food')));
      await tester.tap(find.byKey(const Key('save-food')));
      await settle(tester);
      expect(find.text('Required'), findsNWidgets(2));
      expect(await tester.runAsync(() => db.select(db.foods).get()), isEmpty);
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

  group('last amount, undo and day titles', () {
    Future<Food> yogurt() => repo.createCustom(
      const CustomFoodInput(
        name: 'Greek yogurt',
        per100g: Macros(kcal: 97, proteinG: 9, fatG: 5, carbsG: 4),
        servingName: '1 cup',
        servingGrams: 150,
      ),
    );

    testWidgets('prefills servings from last time, selected; Add confirms '
        'with Undo', (tester) async {
      final food = await tester.runAsync(() async {
        final f = await yogurt();
        await repo.logFood(
          dayKey: '2026-09-20',
          meal: Meal.breakfast,
          foodId: f.id,
          grams: 300,
        );
        return f;
      });
      await pump(
        tester,
        _Launcher(
          (_) => PortionScreen(
            food: food!,
            dayKey: '2026-09-25',
            meal: Meal.breakfast,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('Add to Breakfast'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('amount-field')),
      );
      expect(field.controller!.text, '2');
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(find.text('= 300 g · Same as last time'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-button')));
      await settle(tester);
      expect(find.byType(PortionScreen), findsNothing);
      expect(
        find.text('Added Greek yogurt · 300 g · 291 kcal to Breakfast'),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(() => db.select(db.foodLogEntries).get()),
        hasLength(2),
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(
        await tester.runAsync(() => db.select(db.foodLogEntries).get()),
        hasLength(1),
      );
      await finish(tester);
    });

    testWidgets('uneven last amount is prefilled in grams; other day in '
        'title', (tester) async {
      final food = await tester.runAsync(() async {
        final f = await yogurt();
        await repo.logFood(
          dayKey: '2026-09-20',
          meal: Meal.breakfast,
          foodId: f.id,
          grams: 130,
        );
        return f;
      });
      await pump(
        tester,
        PortionScreen(food: food!, dayKey: '2026-09-24', meal: Meal.lunch),
      );
      expect(find.text('Add to Lunch · Yesterday'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('amount-field')),
      );
      expect(field.controller!.text, '130');
      expect(find.text('g'), findsOneWidget); // grams suffix
      await finish(tester);
    });

    testWidgets('Recent shows last time and quick-adds it with Undo', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final f = await yogurt();
        await repo.logFood(
          dayKey: '2026-09-24',
          meal: Meal.breakfast,
          foodId: f.id,
          grams: 150,
        );
      });
      await pump(
        tester,
        _Launcher(
          (_) => const AddFoodScreen(dayKey: '2026-09-23', meal: Meal.snack),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Add to Snacks · Wed 23 Sep'), findsOneWidget);
      expect(find.text('150 g last time · 146 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Add 150 g'));
      await settle(tester);
      expect(
        find.text('Added Greek yogurt · 150 g · 146 kcal to Snacks'),
        findsOneWidget,
      );
      // Stays open to add more.
      expect(find.byType(AddFoodScreen), findsOneWidget);
      var entries = await tester.runAsync(
        () => db.select(db.foodLogEntries).get(),
      );
      expect(entries!.last.dayKey, '2026-09-23');
      expect(entries.last.meal, Meal.snack.index);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      entries = await tester.runAsync(() => db.select(db.foodLogEntries).get());
      expect(entries, hasLength(1));
      await finish(tester);
    });
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

    testWidgets('Search tab finds common foods as you type; picking one '
        'saves it and opens the portion screen', (tester) async {
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
      await tester.enterText(find.byKey(const Key('search-field')), 'banan');
      await settle(tester);
      expect(requests, isEmpty);
      expect(find.text('Your foods'), findsOneWidget);
      expect(find.byKey(const Key('local-builtin:banana')), findsOneWidget);

      // Online search only on the button, both sources queried together.
      await tester.tap(find.byKey(const Key('search-online-button')));
      await settle(tester);
      expect(requests, hasLength(2));

      await tester.tap(find.byKey(const Key('local-builtin:banana')));
      await settle(tester);
      expect(find.byType(PortionScreen), findsOneWidget);
      final foods = await tester.runAsync(() => db.select(db.foods).get());
      expect(foods!.single.source, 'builtin');
      expect(foods.single.name, 'Banana');
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
      expect(requests, hasLength(2));
      expect(
        requests.map((r) => r.url.host),
        containsAll(['api.nal.usda.gov', 'world.openfoodfacts.org']),
      );
      expect(
        find.text('Chicken, breast, boneless, skinless, raw'),
        findsOneWidget,
      );
      expect(find.text('107 kcal/100 g'), findsOneWidget);
      await finish(tester);
    });

    testWidgets(
      'a branded product with nothing on USDA still shows up from Open '
      'Food Facts',
      (tester) async {
        await pump(
          tester,
          const AddFoodScreen(dayKey: '2026-09-25', meal: Meal.lunch),
          client: mock(
            (req) => http.Response.bytes(
              utf8.encode(
                fixtureText(
                  req.url.host == 'world.openfoodfacts.org'
                      ? 'off_search_nutella.json'
                      : 'usda_search_empty.json',
                ),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        await tester.tap(find.text('Search'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('search-field')),
          'nutella',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester);
        expect(requests, hasLength(2));
        expect(
          requests.map((r) => r.url.host),
          containsAll(['api.nal.usda.gov', 'world.openfoodfacts.org']),
        );
        expect(find.text('Nutella'), findsOneWidget);
        expect(find.text('Ferrero · 539 kcal/100 g'), findsOneWidget);
        await finish(tester);
      },
    );

    testWidgets(
      'both sources return results: both are shown, Open Food Facts first',
      (tester) async {
        await pump(
          tester,
          const AddFoodScreen(dayKey: '2026-09-25', meal: Meal.lunch),
          client: mock(
            (req) => http.Response.bytes(
              utf8.encode(
                fixtureText(
                  req.url.host == 'world.openfoodfacts.org'
                      ? 'off_search_nutella.json'
                      : 'usda_search.json',
                ),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        await tester.tap(find.text('Search'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('search-field')),
          'chicken nutella',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester);
        expect(find.text('Nutella'), findsOneWidget);
        expect(
          find.text('Chicken, breast, boneless, skinless, raw'),
          findsOneWidget,
        );
        final tiles = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .toList();
        expect(
          tiles.indexOf('Nutella'),
          lessThan(tiles.indexOf('Chicken, breast, boneless, skinless, raw')),
        );
        await finish(tester);
      },
    );
  });
}

/// A home screen with an "open" button that pushes [builder], so screens
/// that pop (and their snackbars) behave like in the app.
class _Launcher extends StatelessWidget {
  const _Launcher(this.builder);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: builder)),
        child: const Text('open'),
      ),
    ),
  );
}
