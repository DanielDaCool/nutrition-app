import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/screens/add_food_screen.dart';
import 'package:nutrition_app/features/food/widgets/meals_section.dart';

import '../../helpers/test_db.dart';

const _day = '2026-09-25';

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = FoodRepository(db, () => DateTime(2026, 9, 25, 12));
  });
  tearDown(() => db.close());

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MealsSection(dayKey: _day)),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Let drift's stream cleanup timers run before tearDown closes the DB.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows four meals, items, subtotals and the fully logged hint', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bread = await repo.createCustom(
        const CustomFoodInput(
          name: 'Whole wheat bread',
          per100g: Macros(kcal: 250, proteinG: 10, fatG: 3, carbsG: 41),
        ),
      );
      final cheese = await repo.createCustom(
        const CustomFoodInput(
          name: 'Cottage 5%',
          per100g: Macros(kcal: 97, proteinG: 11, fatG: 5, carbsG: 3.5),
        ),
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.breakfast,
        foodId: bread.id,
        grams: 60,
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.breakfast,
        foodId: cheese.id,
        grams: 100,
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.dinner,
        foodId: cheese.id,
        grams: 200,
      );
    });
    await pumpSection(tester);

    for (final m in ['Breakfast', 'Lunch', 'Dinner', 'Snacks']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('Whole wheat bread'), findsOneWidget);
    expect(find.text('Cottage 5%'), findsNWidgets(2));
    // Breakfast: 150 + 97 kcal, 6 + 11 g protein.
    expect(find.text('247 kcal · P 17 g'), findsOneWidget);
    expect(find.text('194 kcal · P 22 g'), findsOneWidget);
    // Day total: 441 kcal, 39 g protein.
    expect(find.text('441 kcal · P 39 g'), findsOneWidget);
    expect(find.text('Day fully logged'), findsOneWidget);
    expect(find.text('Counts toward your weekly check-in'), findsOneWidget);
    await tearDownTree(tester);
  });

  testWidgets('switch marks the day fully logged', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    final rows = await tester.runAsync(() => db.select(db.dayStatuses).get());
    expect(rows!.single.fullyLogged, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tearDownTree(tester);
  });

  testWidgets('tap an item to change grams', (tester) async {
    await tester.runAsync(() async {
      final f = await repo.createCustom(
        const CustomFoodInput(
          name: 'Banana',
          per100g: Macros(kcal: 89, proteinG: 1.1, fatG: 0.3, carbsG: 23),
        ),
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.snack,
        foodId: f.id,
        grams: 100,
      );
    });
    await pumpSection(tester);
    await tester.tap(find.text('Banana'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('grams-field')), '150');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final e = await tester.runAsync(() => db.select(db.foodLogEntries).get());
    expect(e!.single.grams, 150);
    expect(e.single.kcal, closeTo(133.5, 1e-9));
    expect(find.textContaining('150 g'), findsOneWidget);
    await tearDownTree(tester);
  });

  Future<void> logBanana() async {
    final f = await repo.createCustom(
      const CustomFoodInput(
        name: 'Banana',
        per100g: Macros(kcal: 89, proteinG: 1.1, fatG: 0.3, carbsG: 23),
      ),
    );
    await repo.logFood(
      dayKey: _day,
      meal: Meal.snack,
      foodId: f.id,
      grams: 120,
    );
  }

  testWidgets('edit sheet: grams preselected, move to another meal', (
    tester,
  ) async {
    await tester.runAsync(logBanana);
    await pumpSection(tester);
    await tester.tap(find.text('Banana'));
    await settle(tester);

    final field = tester.widget<TextField>(
      find.byKey(const Key('grams-field')),
    );
    expect(field.controller!.text, '120');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    await tester.tap(find.byKey(const Key('move-lunch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-entry')));
    await settle(tester);

    final e = await tester.runAsync(() => db.select(db.foodLogEntries).get());
    expect(e!.single.meal, Meal.lunch.index);
    expect(e.single.grams, 120);
    expect(find.text('Moved Banana to Lunch'), findsOneWidget);
    await tearDownTree(tester);
  });

  testWidgets('edit sheet: Delete removes with Undo', (tester) async {
    await tester.runAsync(logBanana);
    await pumpSection(tester);
    await tester.tap(find.text('Banana'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('delete-entry')));
    await settle(tester);

    expect(find.text('Banana'), findsNothing);
    expect(
      await tester.runAsync(() => db.select(db.foodLogEntries).get()),
      isEmpty,
    );
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Banana'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.select(db.foodLogEntries).get()),
      hasLength(1),
    );
    await tearDownTree(tester);
  });

  testWidgets('swipe to delete', (tester) async {
    await tester.runAsync(() async {
      final f = await repo.createCustom(
        const CustomFoodInput(
          name: 'Apple',
          per100g: Macros(kcal: 52, proteinG: 0.3, fatG: 0.2, carbsG: 14),
        ),
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.lunch,
        foodId: f.id,
        grams: 180,
      );
    });
    await pumpSection(tester);
    await tester.drag(find.text('Apple'), const Offset(-600, 0));
    await settle(tester);

    expect(find.text('Apple'), findsNothing);
    final e = await tester.runAsync(() => db.select(db.foodLogEntries).get());
    expect(e, isEmpty);
    expect(find.text('Removed Apple'), findsOneWidget);
    await tearDownTree(tester);
  });

  Future<Food> logYesterdayBreakfast() async {
    final oats = await repo.createCustom(
      const CustomFoodInput(
        name: 'Oats',
        per100g: Macros(kcal: 380, proteinG: 13, fatG: 7, carbsG: 60),
      ),
    );
    final milk = await repo.createCustom(
      const CustomFoodInput(
        name: 'Milk',
        per100g: Macros(kcal: 60, proteinG: 3.3, fatG: 3, carbsG: 4.8),
      ),
    );
    await repo.logMany(
      dayKey: '2026-09-24',
      meal: Meal.breakfast,
      items: [(foodId: oats.id, grams: 50), (foodId: milk.id, grams: 200)],
    );
    return oats;
  }

  testWidgets('empty meal offers "Same as yesterday"; Undo removes it', (
    tester,
  ) async {
    await tester.runAsync(logYesterdayBreakfast);
    await pumpSection(tester);

    // 190 + 120 kcal yesterday; only breakfast had food.
    expect(find.text('Same as yesterday · 2 items · 310 kcal'), findsOneWidget);
    expect(find.byKey(const Key('repeat-lunch')), findsNothing);
    expect(find.text('Tap to add'), findsNWidgets(4));

    await tester.tap(find.byKey(const Key('repeat-breakfast')));
    await settle(tester);
    var today = await tester.runAsync(
      () => (db.select(
        db.foodLogEntries,
      )..where((t) => t.dayKey.equals(_day))).get(),
    );
    expect(today!.map((e) => e.grams), [50, 200]);
    expect(today.every((e) => e.meal == Meal.breakfast.index), isTrue);
    expect(find.text('Added 2 items to Breakfast'), findsOneWidget);
    expect(find.byKey(const Key('repeat-breakfast')), findsNothing);
    // Breakfast subtotal and the day total.
    expect(find.text('310 kcal · P 13 g'), findsNWidgets(2));

    await tester.tap(find.text('Undo'));
    await settle(tester);
    today = await tester.runAsync(
      () => (db.select(
        db.foodLogEntries,
      )..where((t) => t.dayKey.equals(_day))).get(),
    );
    expect(today, isEmpty);
    await tearDownTree(tester);
  });

  testWidgets('meal menu copies from yesterday into a non-empty meal', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final oats = await logYesterdayBreakfast();
      await repo.logFood(
        dayKey: _day,
        meal: Meal.breakfast,
        foodId: oats.id,
        grams: 30,
      );
    });
    await pumpSection(tester);
    expect(find.byKey(const Key('repeat-breakfast')), findsNothing);

    await tester.tap(find.byKey(const Key('meal-menu-breakfast')));
    await settle(tester);
    await tester.tap(find.text('Copy from yesterday'));
    await settle(tester);
    final today = await tester.runAsync(
      () => (db.select(
        db.foodLogEntries,
      )..where((t) => t.dayKey.equals(_day))).get(),
    );
    expect(today!.map((e) => e.grams), [30, 50, 200]);
    expect(find.text('Added 2 items to Breakfast'), findsOneWidget);

    // Nothing to copy for lunch.
    await tester.tap(find.byKey(const Key('meal-menu-lunch')));
    await settle(tester);
    await tester.tap(find.text('Copy from yesterday'));
    await settle(tester);
    expect(find.text('Nothing logged in Lunch Yesterday'), findsNothing);
    expect(find.text('Nothing logged in Lunch yesterday'), findsOneWidget);
    await tearDownTree(tester);
  });

  testWidgets('tapping the whole meal header opens add food', (tester) async {
    await pumpSection(tester);
    final size = tester.getSize(find.byKey(const Key('meal-header-lunch')));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Lunch'));
    await settle(tester);
    expect(find.byType(AddFoodScreen), findsOneWidget);
    expect(find.text('Add to Lunch'), findsOneWidget);
    await tearDownTree(tester);
  });

  testWidgets('+ opens the add food screen for that meal', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.byKey(const Key('add-dinner')));
    await settle(tester);
    expect(find.byType(AddFoodScreen), findsOneWidget);
    expect(find.text('Add to Dinner'), findsOneWidget);
    expect(find.text('Foods you log will show up here.'), findsOneWidget);
    await tearDownTree(tester);
  });
}

/// Lets drift's async queries complete between frames.
Future<void> settle(WidgetTester tester) async {
  // Not pumpAndSettle: a progress indicator never settles while a query is
  // pending, and drift completes its work outside the fake-async zone.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
