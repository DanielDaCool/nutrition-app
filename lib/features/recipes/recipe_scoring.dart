// PLACEHOLDER: trivial stand-in for the sibling task's real fit-scoring
// logic, just enough to compile and test the recipes UI against. Will be
// overwritten when that task's file is merged in.
import '../../domain/models.dart';

/// Ranks [recipes] best-fit-first for [remaining] macros.
///
/// This placeholder makes no attempt at ranking; it's here only so the
/// recipes UI has something to call.
List<Recipe> rankRecipesByFit(List<Recipe> recipes, Macros remaining) =>
    recipes;
