// Parsing of what the user types for a set's reps and weight. Pure Dart: no
// Flutter or DB imports.

/// Most reps a single set can have; anything above is a typo.
const int maxLiftReps = 1000;

/// Heaviest weight (kg) a set can have; anything above is a typo.
const double maxLiftWeightKg = 1000;

final _wholeNumber = RegExp(r'^\d+$');
final _decimalNumber = RegExp(r'^\d+([.,]\d+)?$');

/// The reps in [text] (a whole number from 1 to [maxLiftReps]), or null
/// when it isn't one.
int? parseLiftReps(String text) {
  final trimmed = text.trim();
  if (!_wholeNumber.hasMatch(trimmed)) return null;
  final reps = int.tryParse(trimmed);
  if (reps == null || reps <= 0 || reps > maxLiftReps) return null;
  return reps;
}

/// The weight in kg in [text] (0 to [maxLiftWeightKg], "." or "," as the
/// decimal separator), or null when it isn't one.
///
/// Empty text is 0 with [emptyIsZero] (a bodyweight exercise without extra
/// weight) and invalid otherwise.
double? parseLiftWeightKg(String text, {bool emptyIsZero = false}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return emptyIsZero ? 0 : null;
  if (!_decimalNumber.hasMatch(trimmed)) return null;
  final weightKg = double.tryParse(trimmed.replaceFirst(',', '.'));
  if (weightKg == null || weightKg > maxLiftWeightKg) return null;
  return weightKg;
}
