/// Pure scoring logic for ranking recipe suggestions against a day's
/// remaining macro budget. No Flutter or DB imports, so this stays
/// unit-testable on its own.
library;

import 'package:nutrition_app/domain/models.dart';

/// Sorts [recipes] best-fit-first against [remaining] (the macros still left
/// for the day). Returns a new list; does not mutate [recipes].
List<Recipe> rankRecipesByFit(List<Recipe> recipes, Macros remaining) {
  final sorted = List<Recipe>.of(recipes);
  sorted.sort((a, b) {
    final fitCompare = _overshoots(a, remaining) ? 1 : 0;
    final otherFitCompare = _overshoots(b, remaining) ? 1 : 0;
    if (fitCompare != otherFitCompare) return fitCompare - otherFitCompare;
    return _macroDistance(a, remaining).compareTo(_macroDistance(b, remaining));
  });
  return sorted;
}

// kcal fit is checked first and treated as a hard-ish gate (with a small
// overshoot allowance) because blowing the calorie budget matters more than
// a slightly worse protein/fat/carb match — a recipe that fits calories but
// has imperfect macros is still a reasonable suggestion, while one that
// busts the budget rarely is, however well its macro ratios line up.
bool _overshoots(Recipe recipe, Macros remaining) {
  const overshootAllowance = 1.10;
  return recipe.perServing.kcal > remaining.kcal * overshootAllowance;
}

double _macroDistance(Recipe recipe, Macros remaining) {
  final p = recipe.perServing;
  return _proportionalDiff(p.proteinG, remaining.proteinG) +
      _proportionalDiff(p.fatG, remaining.fatG) +
      _proportionalDiff(p.carbsG, remaining.carbsG);
}

double _proportionalDiff(double value, double target) {
  final denom = target.abs() < 1 ? 1 : target.abs();
  return (value - target).abs() / denom;
}
