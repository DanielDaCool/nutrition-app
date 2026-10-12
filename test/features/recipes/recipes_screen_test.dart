import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/recipes/data/recipe_catalog.dart';
import 'package:nutrition_app/features/recipes/recipes_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpRecipes(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('shows a section per meal category', (tester) async {
    await pumpRecipes(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);

    // The catalog now has 25 recipes per category, so Dinner/Snacks sit
    // past the initial cache extent and need scrolling into view.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Dinner'),
      500,
      scrollable: scrollable,
    );
    expect(find.text('Dinner'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Snacks'),
      500,
      scrollable: scrollable,
    );
    expect(find.text('Snacks'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Log a serving adds perServing x servings, with Undo', (
    tester,
  ) async {
    await pumpRecipes(tester);
    final recipe = recipeCatalog.firstWhere(
      (r) => r.category == Meal.breakfast,
    );
    final card = find.text(recipe.name).first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('log-recipe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('log-meal-breakfast')), findsOneWidget);
    await tester.tap(find.byKey(const Key('servings-plus')));
    await tester.pump();
    expect(find.text('1.5 servings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-meal-dinner')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-recipe-add')));
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();

    final entries = await tester.runAsync(
      () => db.select(db.foodLogEntries).get(),
    );
    expect(entries, hasLength(1));
    expect(entries!.single.dayKey, '2026-09-25');
    expect(entries.single.meal, Meal.dinner.index);
    expect(entries.single.kcal, closeTo(recipe.perServing.kcal * 1.5, 1e-9));
    expect(
      entries.single.proteinG,
      closeTo(recipe.perServing.proteinG * 1.5, 1e-9),
    );
    expect(find.textContaining('1.5 servings'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Undo'));
    await settle();
    final after = await tester.runAsync(
      () => db.select(db.foodLogEntries).get(),
    );
    expect(after, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
