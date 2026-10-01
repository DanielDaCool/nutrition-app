/// Pure filtering logic for the Recipes tab: free-text ingredient/name search
/// plus optional macro goal bounds. No Flutter or DB imports, so this stays
/// unit-testable on its own.
library;

import 'package:nutrition_app/domain/models.dart';

/// Search text plus optional goal bounds to narrow the recipe catalog by.
/// All fields are optional; [RecipeFilters.empty] means "no filtering".
class RecipeFilters {
  const RecipeFilters({
    this.query = '',
    this.maxKcal,
    this.minProteinG,
    this.maxCarbsG,
    this.maxFatG,
  });

  /// No search text, no goal bounds: matches every recipe unchanged.
  static const empty = RecipeFilters();

  /// Free-text search, matched case-insensitively against the recipe name
  /// and its ingredients.
  final String query;

  /// Keep only recipes with `perServing.kcal <= maxKcal`, if set.
  final double? maxKcal;

  /// Keep only recipes with `perServing.proteinG >= minProteinG`, if set.
  final double? minProteinG;

  /// Keep only recipes with `perServing.carbsG <= maxCarbsG`, if set.
  final double? maxCarbsG;

  /// Keep only recipes with `perServing.fatG <= maxFatG`, if set.
  final double? maxFatG;

  bool get isEmpty =>
      query.isEmpty &&
      maxKcal == null &&
      minProteinG == null &&
      maxCarbsG == null &&
      maxFatG == null;

  RecipeFilters copyWith({
    String? query,
    double? maxKcal,
    double? minProteinG,
    double? maxCarbsG,
    double? maxFatG,
    bool clearMaxKcal = false,
    bool clearMinProteinG = false,
    bool clearMaxCarbsG = false,
    bool clearMaxFatG = false,
  }) {
    return RecipeFilters(
      query: query ?? this.query,
      maxKcal: clearMaxKcal ? null : (maxKcal ?? this.maxKcal),
      minProteinG: clearMinProteinG ? null : (minProteinG ?? this.minProteinG),
      maxCarbsG: clearMaxCarbsG ? null : (maxCarbsG ?? this.maxCarbsG),
      maxFatG: clearMaxFatG ? null : (maxFatG ?? this.maxFatG),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecipeFilters &&
      other.query == query &&
      other.maxKcal == maxKcal &&
      other.minProteinG == minProteinG &&
      other.maxCarbsG == maxCarbsG &&
      other.maxFatG == maxFatG;

  @override
  int get hashCode =>
      Object.hash(query, maxKcal, minProteinG, maxCarbsG, maxFatG);
}

/// Returns the recipes in [recipes] that match [filters]: the search text
/// (against name or any ingredient, case-insensitive) AND every goal bound
/// that is set. With [RecipeFilters.empty], returns [recipes] unchanged
/// (same order).
List<Recipe> applyRecipeFilters(List<Recipe> recipes, RecipeFilters filters) {
  if (filters.isEmpty) return recipes;

  final query = filters.query.trim().toLowerCase();

  return recipes.where((recipe) {
    if (query.isNotEmpty) {
      final nameMatches = recipe.name.toLowerCase().contains(query);
      final ingredientMatches = recipe.ingredients.any(
        (i) => i.toLowerCase().contains(query),
      );
      if (!nameMatches && !ingredientMatches) return false;
    }

    final macros = recipe.perServing;
    if (filters.maxKcal != null && macros.kcal > filters.maxKcal!) {
      return false;
    }
    if (filters.minProteinG != null &&
        macros.proteinG < filters.minProteinG!) {
      return false;
    }
    if (filters.maxCarbsG != null && macros.carbsG > filters.maxCarbsG!) {
      return false;
    }
    if (filters.maxFatG != null && macros.fatG > filters.maxFatG!) {
      return false;
    }
    return true;
  }).toList();
}
