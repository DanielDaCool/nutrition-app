/// Pure nutrition arithmetic for food logging (no Flutter or DB imports).
library;

import '../../domain/models.dart';

/// Energy conversion used when a label only gives kJ.
const double kjPerKcal = 4.184;

/// [grams] as a number of servings when it is a whole or half number of
/// [servingGrams] (e.g. 300 g of a 150 g serving = 2), else null.
double? evenServings(double grams, double? servingGrams) {
  if (servingGrams == null || servingGrams <= 0 || grams <= 0) return null;
  final halves = grams / servingGrams * 2;
  return (halves - halves.roundToDouble()).abs() < 1e-6
      ? halves.roundToDouble() / 2
      : null;
}

/// Nutrition of [grams] of a food whose values are given per 100 g.
Macros macrosForGrams(Macros per100g, double grams) {
  final f = grams / 100.0;
  return Macros(
    kcal: per100g.kcal * f,
    proteinG: per100g.proteinG * f,
    fatG: per100g.fatG * f,
    carbsG: per100g.carbsG * f,
  );
}

/// Converts label values given per serving of [servingGrams] to per 100 g.
Macros per100gFromServing(Macros perServing, double servingGrams) {
  if (servingGrams <= 0) {
    throw ArgumentError.value(servingGrams, 'servingGrams', 'must be > 0');
  }
  return macrosForGrams(perServing, 100.0 * 100.0 / servingGrams);
}

/// Scales a logged snapshot when only the amount changes, so an edit keeps
/// the nutrition that was copied at log time.
Macros rescaleSnapshot(Macros snapshot, double oldGrams, double newGrams) {
  if (oldGrams <= 0) return snapshot;
  final f = newGrams / oldGrams;
  return Macros(
    kcal: snapshot.kcal * f,
    proteinG: snapshot.proteinG * f,
    fatG: snapshot.fatG * f,
    carbsG: snapshot.carbsG * f,
  );
}

/// kcal implied by the macros (Atwater 4/9/4).
double kcalFromMacros(double proteinG, double fatG, double carbsG) =>
    proteinG * 4 + fatG * 9 + carbsG * 4;

/// A warning (never a blocker) when label values don't add up. Returns null
/// when they look plausible. Values are per 100 g.
String? labelWarning(Macros per100g) {
  final macroGrams = per100g.proteinG + per100g.fatG + per100g.carbsG;
  if (macroGrams > 100.5) {
    return 'Protein + fat + carbs is ${macroGrams.toStringAsFixed(0)} g per '
        '100 g, which is more than 100 g. Check the values.';
  }
  final implied = kcalFromMacros(
    per100g.proteinG,
    per100g.fatG,
    per100g.carbsG,
  );
  final diff = (per100g.kcal - implied).abs();
  // Fibre, alcohol, polyols and rounding explain small gaps.
  if (diff > 25 && diff > 0.2 * per100g.kcal) {
    return 'Calories (${per100g.kcal.round()} kcal) don\'t match the macros '
        '(about ${implied.round()} kcal per 100 g). Check the label.';
  }
  return null;
}

/// Parses a user-typed number ("12", "12.5", "12,5"). Returns null for empty
/// or invalid input.
double? parseAmount(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

// The lookahead also rules out Hebrew letters, so "1 גביע" (a cup) or
// "2 גלילים" (rolls) isn't read as grams from its leading ג.
final _gramsInText = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:g|gr|grams?|גרם|ג)(?![a-z\u05D0-\u05EA])',
  caseSensitive: false,
);

/// Serving size in grams from Open Food Facts fields, or null if it isn't
/// given in grams. [servingQuantity] and [unit] come from `serving_quantity`
/// and `serving_quantity_unit`; [servingSize] is the free text, e.g.
/// "1 slice (30 g)".
double? parseServingGrams({
  String? servingSize,
  Object? servingQuantity,
  String? unit,
}) {
  final q = toDouble(servingQuantity);
  final u = unit?.trim().toLowerCase();
  final textMatches = servingSize == null
      ? const <RegExpMatch>[]
      : _gramsInText.allMatches(servingSize).toList();
  if (q != null && q > 0) {
    if (u == 'g') return q;
    // Without a unit, only trust the number if the text also says grams.
    if ((u == null || u.isEmpty) && textMatches.isNotEmpty) return q;
  }
  if (textMatches.isEmpty) return null;
  // "2 biscuits (25 g)": take the grams value from the text.
  final v = double.tryParse(textMatches.last.group(1)!.replaceAll(',', '.'));
  return (v != null && v > 0) ? v : null;
}

/// Picks the per-100g kcal value from a label/API source that gives both a
/// kcal figure and a kJ figure, guarding against a real, documented Open
/// Food Facts data problem: contributors sometimes type the kJ number into
/// the kcal field (or vice versa), which inflates kcal by roughly the 4.184
/// kJ-per-kcal factor. When both are present but don't agree with that
/// conversion within OFF's own tolerance (about 15% + 5 kcal, matching the
/// tolerance OFF's own data-quality checker uses), the kJ figure is trusted
/// since it is the label's legally required field. Falls back to whichever
/// figure is present when only one is.
double? resolveKcal({required double? kcalField, required double? kjField}) {
  if (kjField == null) return kcalField;
  final fromKj = kjField / kjPerKcal;
  if (kcalField == null) return fromKj;
  final tolerance = fromKj.abs() * 0.15 + 5;
  return (kcalField - fromKj).abs() <= tolerance ? kcalField : fromKj;
}

/// Lenient number conversion for JSON values (num or numeric string).
double? toDouble(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}
