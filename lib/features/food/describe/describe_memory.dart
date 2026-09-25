/// What the describe screen has learned from the user's corrections: which
/// food a phrase means ("cottage" -> his Tnuva cottage) and how much his
/// spoon, cup or piece weighs for a food. Stored as KeyValues rows with keys
/// prefixed `describe.`.
///
/// Pure Dart: no Flutter or DB imports.
library;

import 'food_text.dart';
import 'meal_text_parser.dart';

/// Learned names and unit weights.
class DescribeMemory {
  const DescribeMemory({this.aliases = const {}, this.unitGrams = const {}});

  static const empty = DescribeMemory();

  /// Prefix of every KeyValues key this feature writes.
  static const keyPrefix = 'describe.';
  static const _aliasPrefix = 'describe.alias.';
  static const _gramsPrefix = 'describe.grams.';

  /// Normalized phrase -> food candidate key.
  final Map<String, String> aliases;

  /// `<food key>|<unit>` -> grams per unit.
  final Map<String, double> unitGrams;

  /// The food the user picked for [phrase] before, if any.
  String? foodFor(String phrase) => aliases[normalizePhrase(phrase)];

  /// Grams per [unit] the user taught for [foodKey], if any. A null unit
  /// ("hummus", no amount) is stored as a serving.
  double? gramsPerUnit(String foodKey, MeasureUnit? unit) =>
      unitGrams[_unitKey(foodKey, unit)];

  static String _unitKey(String foodKey, MeasureUnit? unit) =>
      '$foodKey|${(unit ?? MeasureUnit.serving).name}';

  /// KeyValues row for "[phrase] means [foodKey]". Null when the phrase has
  /// no food words.
  static MapEntry<String, String>? aliasEntry(String phrase, String foodKey) {
    final p = normalizePhrase(phrase);
    if (p.isEmpty) return null;
    return MapEntry('$_aliasPrefix$p', foodKey);
  }

  /// KeyValues row for "one [unit] of [foodKey] weighs [grams]". Null for
  /// units that are already weights (g, kg, ml, l) or a non-positive amount.
  static MapEntry<String, String>? gramsEntry(
    String foodKey,
    MeasureUnit? unit,
    double grams,
  ) {
    if (unit != null && unit.isMeasured) return null;
    if (grams.isNaN || grams <= 0 || grams.isInfinite) return null;
    final rounded = (grams * 10).round() / 10;
    return MapEntry(
      '$_gramsPrefix${_unitKey(foodKey, unit)}',
      rounded.toString(),
    );
  }

  /// Rebuilds the memory from KeyValues rows (other keys are ignored).
  factory DescribeMemory.fromKeyValues(Map<String, String> rows) {
    final aliases = <String, String>{};
    final grams = <String, double>{};
    rows.forEach((k, v) {
      if (k.startsWith(_aliasPrefix)) {
        aliases[k.substring(_aliasPrefix.length)] = v;
      } else if (k.startsWith(_gramsPrefix)) {
        final g = double.tryParse(v);
        if (g != null && g > 0) grams[k.substring(_gramsPrefix.length)] = g;
      }
    });
    return DescribeMemory(aliases: aliases, unitGrams: grams);
  }
}
