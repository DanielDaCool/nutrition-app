import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
import 'package:nutrition_app/features/food/quick_calories.dart';
import 'package:nutrition_app/features/food/screens/add_food_screen.dart';
import 'package:nutrition_app/features/food/widgets/meals_section.dart';

import '../../helpers/test_db.dart';
import 'meals_section_test.dart' show settle;

const _day = '2026-09-25';

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = FoodRepository(db, () => DateTime(2026, 9, 25, 12));
  });
  tearDown(() => db.close());

  group('pure helpers', () {
    test('macroKcal uses 4/9/4 and treats blanks as 0', () {
      expect(macroKcal(proteinG: 10, fatG: 5, carbsG: 20), 40 + 45 + 80);
      expect(macroKcal(), 0);
      expect(macroKcal(fatG: 10), 90);
    });

    test('macrosExceedKcal tolerates rounding, flags clear excess', () {
      // 165 implied vs 150 entered: 10% over, fine.
      expect(macrosExceedKcal(150, proteinG: 10, fatG: 5, carbsG: 20), isFalse);
      // 400 implied vs 200 entered.
      expect(macrosExceedKcal(200, proteinG: 50, carbsG: 50), isTrue);
      // Small absolute difference is ignored even when large in percent.
      expect(macrosExceedKcal(10, carbsG: 5), isFalse);
      // Blank macros never trigger it.
      expect(macrosExceedKcal(500), isFalse);
    });

    test('incompleteKcal adds only incomplete entries', () {
      expect(incompleteKcal([(300, true), (200, false), (50, true)]), 350);
      expect(incompleteKcal(const []), 0);
    });
  });

  group('FoodRepository.logQuickCalories', () {
    test('typed macros round-trip exactly as source quick', () async {
      final id = await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.lunch,
        kcal: 612.5,
        proteinG: 31.2,
        fatG: 20,
        carbsG: 70.4,
        label: '  Canteen lunch ',
      );
      final entry = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(entry.grams, 100);
      expect(entry.kcal, 612.5);
      expect(entry.proteinG, 31.2);
      expect(entry.fatG, 20);
      expect(entry.carbsG, 70.4);
      final food = await repo.foodById(entry.foodId);
      expect(food.source, FoodSource.quick);
      expect(food.name, 'Canteen lunch');
      expect(food.externalId, isNull);
      expect(food.servingGrams, 100);
    });

    test('a blank macro makes it quickKcal with 0 stored', () async {
      final id = await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.snack,
        kcal: 400,
        proteinG: 20,
      );
      final entry = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(entry.kcal, 400);
      expect(entry.proteinG, 20);
      expect(entry.fatG, 0);
      final food = await repo.foodById(entry.foodId);
      expect(food.source, FoodSource.quickKcal);
      expect(food.name, 'Quick add');
      final items = await repo.watchDayItems(_day).first;
      expect(items.single.isQuick, isTrue);
      expect(items.single.macrosIncomplete, isTrue);
    });

    test('a typed zero is complete, not quickKcal', () async {
      await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.snack,
        kcal: 90,
        proteinG: 0,
        fatG: 0,
        carbsG: 22,
      );
      final items = await repo.watchDayItems(_day).first;
      expect(items.single.source, FoodSource.quick);
      expect(items.single.macrosIncomplete, isFalse);
    });

    test('identical quick adds share one food row', () async {
      for (var i = 0; i < 2; i++) {
        await repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.lunch,
          kcal: 500,
          proteinG: 30,
          fatG: 10,
          carbsG: 60,
        );
      }
      await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.lunch,
        kcal: 500,
        proteinG: 30,
        fatG: 10,
        carbsG: 61,
      );
      expect(await db.select(db.foods).get(), hasLength(2));
      expect(await db.select(db.foodLogEntries).get(), hasLength(3));
    });

    test('rejects zero, negative and NaN', () async {
      for (final bad in [0.0, -5.0, double.nan]) {
        expect(
          () =>
              repo.logQuickCalories(dayKey: _day, meal: Meal.lunch, kcal: bad),
          throwsArgumentError,
        );
      }
      expect(
        () => repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.lunch,
          kcal: 100,
          fatG: -1,
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.foodLogEntries).get(), isEmpty);
    });

    test('counts toward the day intake', () async {
      await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.dinner,
        kcal: 700,
        proteinG: 40,
        fatG: 25,
        carbsG: 80,
      );
      final intake = (await repo.intakeRange(_day, _day)).single;
      expect(intake.total.kcal, 700);
      expect(intake.byMeal[Meal.dinner]!.proteinG, 40);
    });

    test('hidden from Recent, Favorites, all foods and My foods', () async {
      await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.lunch,
        kcal: 500,
        proteinG: 1,
        fatG: 1,
        carbsG: 1,
      );
      await repo.logQuickCalories(dayKey: _day, meal: Meal.lunch, kcal: 300);
      // Even starred, they stay out of Favorites.
      await (db.update(db.foods))
          .write(const FoodsCompanion(isFavorite: Value(true)));
      final normal = await repo.createCustom(
        const CustomFoodInput(
          name: 'Rice',
          per100g: Macros(kcal: 130, proteinG: 2, fatG: 0, carbsG: 28),
        ),
      );
      await repo.logFood(
        dayKey: _day,
        meal: Meal.lunch,
        foodId: normal.id,
        grams: 100,
      );
      expect((await repo.watchRecent().first).map((f) => f.name), ['Rice']);
      expect(await repo.watchFavorites().first, isEmpty);
      expect((await repo.watchAllFoods().first).map((f) => f.name), ['Rice']);
      expect((await repo.watchCustom().first).map((f) => f.name), ['Rice']);
    });

    test('deleting and restoring an entry works like any other', () async {
      final id = await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.lunch,
        kcal: 250,
      );
      final removed = await repo.deleteEntry(id);
      expect(removed, isNotNull);
      expect(await repo.watchDayItems(_day).first, isEmpty);
      await repo.restoreEntry(removed!);
      expect((await repo.watchDayItems(_day).first).single.macros.kcal, 250);
    });

    test('updateEntry scales a quick add with the new grams', () async {
      final id = await repo.logQuickCalories(
        dayKey: _day,
        meal: Meal.lunch,
        kcal: 400,
        proteinG: 20,
        fatG: 10,
        carbsG: 50,
      );
      await repo.updateEntry(id, grams: 50);
      final item = (await repo.watchDayItems(_day).first).single;
      expect(item.macros.kcal, 200);
      expect(item.macros.proteinG, 10);
    });
  });

  group('UI', () {
    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      Set<AppFeature> featuresOff = const {},
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
            if (featuresOff.isNotEmpty)
              featureEnabledProvider.overrideWith(
                (ref, f) => !featuresOff.contains(f),
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

    /// A page whose button opens the add-food screen, so popping works.
    const launcher = _Launcher();

    testWidgets('the bolt button logs calories and closes the screen', (
      tester,
    ) async {
      await pump(tester, launcher);
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('quick-calories-button')));
      await settle(tester);
      expect(find.text('Quick add calories'), findsWidgets);

      // Calories are required.
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pump();
      expect(find.text('Enter calories above 0'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('quick-kcal')), '420');
      await tester.enterText(find.byKey(const Key('quick-protein')), '30');
      await tester.enterText(find.byKey(const Key('quick-name')), 'Pasta');
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await settle(tester);

      expect(find.byType(AddFoodScreen), findsNothing);
      expect(find.textContaining('Added Pasta · 420 kcal'), findsOneWidget);
      final items = await tester.runAsync(() => repo.watchDayItems(_day).first);
      expect(items!.single.foodName, 'Pasta');
      expect(items.single.macros.kcal, 420);
      expect(items.single.macros.proteinG, 30);
      expect(items.single.macrosIncomplete, isTrue);
      await finish(tester);
    });

    testWidgets('warns when macros exceed the calories but still adds', (
      tester,
    ) async {
      await pump(tester, launcher);
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('quick-calories-button')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('quick-kcal')), '200');
      await tester.enterText(find.byKey(const Key('quick-protein')), '50');
      await tester.enterText(find.byKey(const Key('quick-carbs')), '50');
      await tester.pump();
      expect(find.byKey(const Key('quick-warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await settle(tester);
      final items = await tester.runAsync(() => repo.watchDayItems(_day).first);
      expect(items!.single.macros.kcal, 200);
      await finish(tester);
    });

    testWidgets('gate off: no quick-add button, screen still renders', (
      tester,
    ) async {
      await pump(
        tester,
        const AddFoodScreen(dayKey: _day, meal: Meal.lunch),
        featuresOff: const {AppFeature.quickCalories},
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quick-calories-button')), findsNothing);
      expect(find.byTooltip('Quick add calories'), findsNothing);
      expect(find.byKey(const Key('new-food-button')), findsOneWidget);
      expect(find.byKey(const Key('describe-button')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('meals list shows the incomplete-macros note and edits kcal', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.lunch,
          kcal: 400,
          proteinG: 20,
        );
        await repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.dinner,
          kcal: 250,
          label: 'Soup',
        );
        await repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.dinner,
          kcal: 100,
          proteinG: 1,
          fatG: 1,
          carbsG: 1,
        );
      });
      const section = Scaffold(
        body: SingleChildScrollView(child: MealsSection(dayKey: _day)),
      );
      await pump(tester, section);
      expect(
        find.text('Includes 650 kcal without protein, fat or carb details.'),
        findsOneWidget,
      );
      expect(find.text('Quick add · macros not entered'), findsNWidgets(2));
      expect(find.text('Quick add · P 1 g · F 1 g · C 1 g'), findsOneWidget);

      // Edit Soup from 250 to 125 kcal.
      await tester.tap(find.text('Soup'));
      await settle(tester);
      expect(find.text('Calories'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('grams-field')), '125');
      await tester.tap(find.byKey(const Key('save-entry')));
      await settle(tester);
      expect(
        find.text('Includes 525 kcal without protein, fat or carb details.'),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('the note stays when the gate is off (existing data)', (
      tester,
    ) async {
      await tester.runAsync(
        () => repo.logQuickCalories(dayKey: _day, meal: Meal.lunch, kcal: 300),
      );
      const section = Scaffold(
        body: SingleChildScrollView(child: MealsSection(dayKey: _day)),
      );
      await pump(
        tester,
        section,
        featuresOff: const {AppFeature.quickCalories},
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Includes 300 kcal'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('no note when nothing is incomplete', (tester) async {
      await tester.runAsync(
        () => repo.logQuickCalories(
          dayKey: _day,
          meal: Meal.lunch,
          kcal: 300,
          proteinG: 1,
          fatG: 1,
          carbsG: 1,
        ),
      );
      const section = Scaffold(
        body: SingleChildScrollView(child: MealsSection(dayKey: _day)),
      );
      await pump(tester, section);
      expect(find.byKey(const Key('macros-incomplete-note')), findsNothing);
      await finish(tester);
    });
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddFoodScreen(dayKey: _day, meal: Meal.lunch),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}
