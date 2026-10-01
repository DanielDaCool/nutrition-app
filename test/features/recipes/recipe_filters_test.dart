import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/recipes/recipe_filters.dart';

Recipe _recipe({
  required String id,
  required String name,
  List<String> ingredients = const [],
  Macros perServing = const Macros(kcal: 400, proteinG: 20, fatG: 10, carbsG: 40),
  Meal category = Meal.lunch,
}) {
  return Recipe(
    id: id,
    name: name,
    category: category,
    servings: 1,
    perServing: perServing,
    ingredients: ingredients,
    steps: const ['Step 1'],
  );
}

void main() {
  group('applyRecipeFilters', () {
    final chickenBowl = _recipe(
      id: 'chicken-bowl',
      name: 'Chicken rice bowl',
      ingredients: const ['200g chicken breast', '150g rice', 'broccoli'],
      perServing: const Macros(kcal: 500, proteinG: 45, fatG: 10, carbsG: 50),
    );
    final veggieSalad = _recipe(
      id: 'veggie-salad',
      name: 'Veggie salad',
      ingredients: const ['lettuce', 'tomato', 'cucumber'],
      perServing: const Macros(kcal: 200, proteinG: 5, fatG: 8, carbsG: 15),
    );
    final beefStew = _recipe(
      id: 'beef-stew',
      name: 'Beef stew',
      ingredients: const ['300g beef chuck', 'potato', 'carrot'],
      perServing: const Macros(kcal: 700, proteinG: 35, fatG: 30, carbsG: 40),
    );

    final catalog = [chickenBowl, veggieSalad, beefStew];

    test('empty filters returns the list unchanged', () {
      final result = applyRecipeFilters(catalog, RecipeFilters.empty);
      expect(result, same(catalog));
    });

    test('searching by an ingredient substring finds the right recipe', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(query: 'chicken breast'),
      );
      expect(result, [chickenBowl]);
    });

    test('searching by name works', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(query: 'veggie'),
      );
      expect(result, [veggieSalad]);
    });

    test('search is case-insensitive', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(query: 'CHICKEN'),
      );
      expect(result, [chickenBowl]);
    });

    test('a maxKcal filter excludes recipes over budget', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(maxKcal: 500),
      );
      expect(result, containsAll([chickenBowl, veggieSalad]));
      expect(result, isNot(contains(beefStew)));
    });

    test('minProteinG keeps only recipes at or above the floor', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(minProteinG: 40),
      );
      expect(result, [chickenBowl]);
    });

    test('maxCarbsG and maxFatG exclude recipes over budget', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(maxCarbsG: 45, maxFatG: 12),
      );
      expect(result, [veggieSalad]);
    });

    test('combining query + a macro bound ANDs correctly', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(query: 'beef', maxKcal: 500),
      );
      // beefStew matches the query but is over the kcal budget.
      expect(result, isEmpty);
    });

    test('combining query + a macro bound that both match', () {
      final result = applyRecipeFilters(
        catalog,
        const RecipeFilters(query: 'chicken', minProteinG: 30),
      );
      expect(result, [chickenBowl]);
    });
  });
}
