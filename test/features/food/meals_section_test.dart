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
