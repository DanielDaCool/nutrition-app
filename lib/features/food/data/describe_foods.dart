// Turns saved foods plus the built-in list into the candidates the
// describe screen matches against.

import '../../../data/db/database.dart';
import '../describe/builtin_foods.dart';
import '../describe/food_matcher.dart';
import 'food_repository.dart';
import 'remote_food.dart';

/// Every saved food as a [FoodCandidate], plus the built-in foods that
/// aren't saved yet. A saved built-in food keeps its built-in key and names.
List<FoodCandidate> describeCandidates(List<Food> foods) {
  final out = [for (final f in foods) candidateOf(f)];
  final saved = {for (final c in out) ?c.builtinKey};
  for (final b in builtinFoods) {
    if (!saved.contains(b.key)) out.add(FoodCandidate.builtin(b));
  }
  return out;
}

/// A saved food as a [FoodCandidate]. A saved built-in food keeps its
/// built-in key, names and "typical values" status.
FoodCandidate candidateOf(Food f) {
  final builtin = f.source == FoodSource.builtin && f.externalId != null
      ? builtinByKey(f.externalId!)
      : null;
  return FoodCandidate(
    key: builtin != null
        ? builtinCandidateKey(builtin.key)
        : foodCandidateKey(f.id),
    name: f.name,
    brand: f.brand,
    per100g: per100gOf(f),
    servingName: f.servingName,
    servingGrams: f.servingGrams,
    aliases: builtin?.aliases ?? const [],
    foodId: f.id,
    builtinKey: builtin?.key,
    isOwn: f.source == FoodSource.custom,
    isFavorite: f.isFavorite,
    lastUsedAt: f.lastUsedAt,
    preferred: builtin?.preferred ?? false,
  );
}
