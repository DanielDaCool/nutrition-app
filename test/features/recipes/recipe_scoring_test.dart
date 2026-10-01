import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/recipes/recipe_scoring.dart';

Recipe recipe({
  required String id,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbsG,
}) => Recipe(
      id: id,
      name: id,
      category: Meal.dinner,
      servings: 1,
      perServing: Macros(kcal: kcal, proteinG: proteinG, fatG: fatG, carbsG: carbsG),
      ingredients: const ['ingredient'],
      steps: const ['step'],
    );

void main() {
  group('rankRecipesByFit', () {
    test('in-budget recipe ranks above one that blows the kcal budget', () {
      const remaining = Macros(kcal: 500, proteinG: 30, fatG: 15, carbsG: 50);
      final inBudget = recipe(
        id: 'in-budget',
        kcal: 480,
        proteinG: 30,
        fatG: 15,
        carbsG: 50,
      );
      final overBudget = recipe(
        id: 'over-budget',
        kcal: 900, // well beyond the 10% overshoot allowance
        proteinG: 30,
        fatG: 15,
        carbsG: 50,
      );

      final ranked = rankRecipesByFit([overBudget, inBudget], remaining);

      expect(ranked.map((r) => r.id).toList(), ['in-budget', 'over-budget']);
    });

    test('allows a small overshoot within the fixed allowance', () {
      const remaining = Macros(kcal: 500, proteinG: 30, fatG: 15, carbsG: 50);
      // 520 kcal is a 4% overshoot, inside the 10% allowance.
      final slightlyOver = recipe(
        id: 'slightly-over',
        kcal: 520,
        proteinG: 30,
        fatG: 15,
        carbsG: 50,
      );
      final wayOver = recipe(
        id: 'way-over',
        kcal: 900,
        proteinG: 30,
        fatG: 15,
        carbsG: 50,
      );

      final ranked = rankRecipesByFit([wayOver, slightlyOver], remaining);

      expect(ranked.first.id, 'slightly-over');
    });

    test('among in-budget recipes, closer macro match ranks first', () {
      const remaining = Macros(kcal: 500, proteinG: 40, fatG: 15, carbsG: 50);
      final closeMatch = recipe(
        id: 'close-match',
        kcal: 480,
        proteinG: 38,
        fatG: 16,
        carbsG: 48,
      );
      final farMatch = recipe(
        id: 'far-match',
        kcal: 460,
        proteinG: 10,
        fatG: 40,
        carbsG: 10,
      );

      final ranked = rankRecipesByFit([farMatch, closeMatch], remaining);

      expect(ranked.map((r) => r.id).toList(), ['close-match', 'far-match']);
    });

    test('does not mutate the input list', () {
      const remaining = Macros(kcal: 500, proteinG: 30, fatG: 15, carbsG: 50);
      final a = recipe(id: 'a', kcal: 900, proteinG: 30, fatG: 15, carbsG: 50);
      final b = recipe(id: 'b', kcal: 480, proteinG: 30, fatG: 15, carbsG: 50);
      final input = [a, b];

      rankRecipesByFit(input, remaining);

      expect(input.map((r) => r.id).toList(), ['a', 'b']);
    });
  });
}
