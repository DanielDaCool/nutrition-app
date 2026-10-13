import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
import 'package:nutrition_app/features/food/screens/add_food_screen.dart';
import 'package:nutrition_app/features/food/widgets/meals_section.dart';

import '../../helpers/test_db.dart';
import 'meals_section_test.dart' show settle;

const _day = '2026-09-25';

const _toast = Recipe(
  id: 'test-toast',
  name: 'Test toast',
  category: Meal.breakfast,
  servings: 2,
  perServing: Macros(kcal: 300, proteinG: 20, fatG: 10, carbsG: 30),
  ingredients: ['bread'],
  steps: ['toast it'],
);

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = FoodRepository(db, () => DateTime(2026, 9, 25, 12));
  });
  tearDown(() => db.close());

  Future<Food> food(String name, double kcal) => repo.createCustom(
    CustomFoodInput(
      name: name,
      per100g: Macros(kcal: kcal, proteinG: 10, fatG: 2, carbsG: 10),
    ),
  );

  group('saved meals (repository)', () {
    test(
      'create, list with totals at current food values, log, undo',
      () async {
        final bread = await food('Bread', 250);
        final egg = await food('Egg', 150);
        final id = await repo.createSavedMeal('  Usual breakfast ', [
          (foodId: bread.id, grams: 60),
          (foodId: egg.id, grams: 100),
        ]);

        var meals = await repo.savedMeals();
        expect(meals.single.name, 'Usual breakfast');
        expect(meals.single.items.map((i) => i.foodName), ['Bread', 'Egg']);
        expect(meals.single.total.kcal, closeTo(300, 1e-9));

        // A later edit of the food moves the saved meal, not past entries.
        final batch = await repo.logSavedMeal(
          dayKey: _day,
          meal: Meal.breakfast,
          savedMealId: id,
        );
        expect(batch.entryIds, hasLength(2));
        await repo.updateCustom(
          bread.id,
          const CustomFoodInput(
            name: 'Bread',
            per100g: Macros(kcal: 300, proteinG: 10, fatG: 2, carbsG: 10),
          ),
        );
        meals = await repo.savedMeals();
        expect(meals.single.total.kcal, closeTo(330, 1e-9));
        final entries = await db.select(db.foodLogEntries).get();
        expect(entries.map((e) => e.kcal), [150, 150]);
        expect(entries.map((e) => e.meal), everyElement(Meal.breakfast.index));

        await repo.undoLogMany(batch);
        expect(await db.select(db.foodLogEntries).get(), isEmpty);
      },
    );

    test('rename, delete cascades to items, entries stay', () async {
      final bread = await food('Bread', 250);
      final id = await repo.createSavedMeal('A', [
        (foodId: bread.id, grams: 50),
      ]);
      await repo.logSavedMeal(dayKey: _day, meal: Meal.lunch, savedMealId: id);
      await repo.renameSavedMeal(id, ' Toast ');
      expect((await repo.savedMeals()).single.name, 'Toast');

      await repo.deleteSavedMeal(id);
      expect(await repo.savedMeals(), isEmpty);
      expect(await db.select(db.savedMealItems).get(), isEmpty);
      expect(await db.select(db.foodLogEntries).get(), hasLength(1));
      // A deleted meal logs nothing.
      final none = await repo.logSavedMeal(
        dayKey: _day,
        meal: Meal.lunch,
        savedMealId: id,
      );
      expect(none.entryIds, isEmpty);
    });

    test('rejects a blank name, no items and non-positive grams', () async {
      final bread = await food('Bread', 250);
      expect(
        () => repo.createSavedMeal(' ', [(foodId: bread.id, grams: 5)]),
        throwsArgumentError,
      );
      expect(() => repo.createSavedMeal('X', []), throwsArgumentError);
      expect(
        () => repo.createSavedMeal('X', [(foodId: bread.id, grams: 0)]),
        throwsArgumentError,
      );
      expect(() => repo.renameSavedMeal(1, ''), throwsArgumentError);
      expect(await db.select(db.savedMeals).get(), isEmpty);
    });

    test('watchSavedMeals re-emits when a meal is added', () async {
      final bread = await food('Bread', 250);
      final seen = <int>[];
      final sub = repo.watchSavedMeals().listen((m) => seen.add(m.length));
      await pumpEventQueue();
      await repo.createSavedMeal('A', [(foodId: bread.id, grams: 50)]);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });

  group('recipe logging (repository)', () {
    test('logs servings as perServing x servings and is idempotent', () async {
      final a = await repo.logRecipe(
        dayKey: _day,
        meal: Meal.breakfast,
        recipe: _toast,
        servings: 1.5,
      );
      final b = await repo.logRecipe(
        dayKey: _day,
        meal: Meal.lunch,
        recipe: _toast,
        servings: 1,
      );
      expect(a, isNot(b));
      final foods = await db.select(db.foods).get();
      expect(foods, hasLength(1));
      expect(foods.single.source, FoodSource.recipe);
      expect(foods.single.externalId, 'test-toast');
      expect(foods.single.servingGrams, 100);
      final e = await db.select(db.foodLogEntries).get();
      expect(e.first.kcal, closeTo(450, 1e-9));
      expect(e.first.proteinG, closeTo(30, 1e-9));
      expect(e.first.grams, 150);
      expect(e.last.kcal, closeTo(300, 1e-9));
    });

    test('a changed catalog updates the food, not logged entries', () async {
      await repo.logRecipe(
        dayKey: _day,
        meal: Meal.breakfast,
        recipe: _toast,
        servings: 1,
      );
      const changed = Recipe(
        id: 'test-toast',
        name: 'Test toast',
        category: Meal.breakfast,
        servings: 2,
        perServing: Macros(kcal: 400, proteinG: 20, fatG: 10, carbsG: 30),
        ingredients: [],
        steps: [],
      );
      await repo.logRecipe(
        dayKey: _day,
        meal: Meal.breakfast,
        recipe: changed,
        servings: 1,
      );
      expect(await db.select(db.foods).get(), hasLength(1));
      final e = await db.select(db.foodLogEntries).get();
      expect(e.map((x) => x.kcal), [300, 400]);
    });

    test('rejects zero servings', () {
      expect(
        () => repo.logRecipe(
          dayKey: _day,
          meal: Meal.lunch,
          recipe: _toast,
          servings: 0,
        ),
        throwsArgumentError,
      );
    });

    test('recipe foods stay out of describe matching but not Recent', () async {
      await repo.logRecipe(
        dayKey: _day,
        meal: Meal.breakfast,
        recipe: _toast,
        servings: 1,
      );
      await food('Bread', 250);
      expect((await repo.watchAllFoods().first).map((f) => f.name), ['Bread']);
      expect((await repo.watchRecent().first).map((f) => f.name), [
        'Test toast',
      ]);
      final items = await repo.watchDayItems(_day).first;
      expect(items.single.source, FoodSource.recipe);
    });
  });

  group('saved meals (UI)', () {
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

    const section = Scaffold(
      body: SingleChildScrollView(child: MealsSection(dayKey: _day)),
    );

    testWidgets('Save as a meal stores the meal entries under a name', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bread = await food('Bread', 250);
        await repo.logFood(
          dayKey: _day,
          meal: Meal.breakfast,
          foodId: bread.id,
          grams: 60,
        );
      });
      await pump(tester, section);
      await tester.tap(find.byKey(const Key('meal-menu-breakfast')));
      await settle(tester);
      await tester.tap(find.text('Save as a meal…'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('saved-meal-name')),
        'Toast time',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('saved-meal-name-ok')));
      await settle(tester);

      final meals = await tester.runAsync(() => repo.savedMeals());
      expect(meals!.single.name, 'Toast time');
      expect(meals.single.items.single.grams, 60);
      await finish(tester);
    });

    testWidgets('Save as a meal is disabled for an empty meal', (tester) async {
      await pump(tester, section);
      await tester.tap(find.byKey(const Key('meal-menu-lunch')));
      await settle(tester);
      expect(find.text('Save as a meal…'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is PopupMenuItem && !w.enabled),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('gate off: the meal menu has only its two copy items', (
      tester,
    ) async {
      await pump(tester, section, featuresOff: const {AppFeature.savedMeals});
      await tester.tap(find.byKey(const Key('meal-menu-breakfast')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Copy from yesterday'), findsOneWidget);
      expect(find.text('Copy from another day…'), findsOneWidget);
      expect(find.text('Save as a meal…'), findsNothing);
      await finish(tester);
    });

    testWidgets('Saved tab logs a meal and Undo takes it back', (tester) async {
      late int mealId;
      await tester.runAsync(() async {
        final bread = await food('Bread', 250);
        final egg = await food('Egg', 150);
        mealId = await repo.createSavedMeal('Usual', [
          (foodId: bread.id, grams: 60),
          (foodId: egg.id, grams: 100),
        ]);
      });
      await pump(tester, const AddFoodScreen(dayKey: _day, meal: Meal.dinner));
      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(find.text('Usual'), findsOneWidget);
      expect(find.text('2 items · 300 kcal'), findsOneWidget);

      await tester.tap(find.byKey(Key('saved-meal-$mealId')));
      await settle(tester);
      var entries = await tester.runAsync(
        () => db.select(db.foodLogEntries).get(),
      );
      expect(entries, hasLength(2));
      expect(entries!.map((e) => e.meal), everyElement(Meal.dinner.index));
      expect(find.textContaining('Added Usual · 2 items'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      entries = await tester.runAsync(() => db.select(db.foodLogEntries).get());
      expect(entries, isEmpty);
      await finish(tester);
    });

    testWidgets('Saved tab shows a hint when there are no saved meals', (
      tester,
    ) async {
      await pump(tester, const AddFoodScreen(dayKey: _day, meal: Meal.dinner));
      // All five tabs fit a 432 dp wide phone without scrolling.
      for (final t in ['Recent', 'Favorites', 'My foods', 'Search', 'Saved']) {
        expect(tester.getRect(find.text(t)).right, lessThan(432), reason: t);
      }
      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(
        find.text('Save a meal from its \u22EE menu on Today.'),
        findsOneWidget,
      );
      await finish(tester);
    });

    Future<int> seedOldMeal(WidgetTester tester) async {
      late int id;
      await tester.runAsync(() async {
        final bread = await food('Bread', 250);
        id = await repo.createSavedMeal('Old', [(foodId: bread.id, grams: 60)]);
      });
      return id;
    }

    testWidgets('Saved tab: rename a meal', (tester) async {
      final id = await seedOldMeal(tester);
      await pump(tester, const AddFoodScreen(dayKey: _day, meal: Meal.dinner));
      await tester.tap(find.text('Saved'));
      await settle(tester);
      await tester.tap(find.byKey(Key('saved-meal-menu-$id')));
      await settle(tester);
      await tester.tap(find.text('Rename'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('saved-meal-name')), 'New');
      await tester.pump();
      await tester.tap(find.byKey(const Key('saved-meal-name-ok')));
      await settle(tester);
      expect(find.text('New'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Saved tab: delete a meal after confirming', (tester) async {
      final id = await seedOldMeal(tester);
      await pump(tester, const AddFoodScreen(dayKey: _day, meal: Meal.dinner));
      await tester.tap(find.text('Saved'));
      await settle(tester);
      await tester.tap(find.byKey(Key('saved-meal-menu-$id')));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('saved-meal-delete-ok')));
      await settle(tester);
      expect(find.text('Old'), findsNothing);
      final left = await tester.runAsync(() => repo.savedMeals());
      expect(left, isEmpty);
      await finish(tester);
    });

    testWidgets('gate off: four tabs and no Saved tab', (tester) async {
      await pump(
        tester,
        const AddFoodScreen(dayKey: _day, meal: Meal.dinner),
        featuresOff: const {AppFeature.savedMeals},
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Saved'), findsNothing);
      for (final t in ['Recent', 'Favorites', 'My foods', 'Search']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.byType(Tab), findsNWidgets(4));
      await finish(tester);
    });
  });
}
