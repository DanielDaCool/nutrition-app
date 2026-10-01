// OWNER: recipes UI agent. Riverpod providers for the Recipes tab: recipes
// grouped by meal category, plus a "recommended for you" list computed from
// today's remaining macros.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../food/food_providers.dart';
import '../targets/targets_providers.dart';
import 'data/recipe_catalog.dart';
import 'recipe_scoring.dart';

/// Recipes in [category], in catalog order.
final recipesByCategoryProvider = Provider.family<List<Recipe>, Meal>(
  (ref, category) =>
      recipeCatalog.where((r) => r.category == category).toList(),
);

/// Top 5 recipes that best fit what's left of today's targets, for the day
/// [dayKey]. Empty before the user has a profile (no targets yet).
final recommendedRecipesProvider =
    StreamProvider.family<List<Recipe>, String>((ref, dayKey) {
  final targets = ref.watch(currentTargetsProvider);
  final intake = ref.watch(dayIntakeProvider(dayKey));

  for (final v in [targets, intake]) {
    if (v.hasError) return Stream.error(v.error!, v.stackTrace);
  }
  if (!targets.hasValue || !intake.hasValue) return const Stream.empty();

  final t = targets.value;
  if (t == null) return Stream.value(const []);

  final eaten = intake.value!.total;
  final remaining = Macros(
    kcal: t.macros.kcal - eaten.kcal,
    proteinG: t.macros.proteinG - eaten.proteinG,
    fatG: t.macros.fatG - eaten.fatG,
    carbsG: t.macros.carbsG - eaten.carbsG,
  );
  final ranked = rankRecipesByFit(recipeCatalog, remaining);
  return Stream.value(ranked.take(5).toList());
});
