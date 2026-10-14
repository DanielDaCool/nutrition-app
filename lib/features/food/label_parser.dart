/// Reads the text a photo of a nutrition label produced into numbers for the
/// "Add from label" form. Pure Dart: no Flutter or DB imports.
///
/// This is a best-effort reader of noisy OCR text. It only fills in what it
/// finds on the same line (or the line right after) as a nutrient's name, and
/// leaves the rest null; the user always reviews the numbers before saving.
library;

import 'nutrition_math.dart' show kjPerKcal;

/// Whether a scanned label's numbers are per 100 g or per serving.
enum ScannedBasis { per100g, perServing }

/// What [parseNutritionLabel] found. Any field may be null.
class LabelScan {
  const LabelScan({
    this.basis,
    this.kcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.servingGrams,
  });

  /// Which column the numbers came from; null when the label didn't say.
  final ScannedBasis? basis;
  final double? kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;

  /// Size of one serving in grams, if the label states it.
  final double? servingGrams;

  /// True when no nutrition number was found at all.
  bool get isEmpty =>
      kcal == null && proteinG == null && fatG == null && carbsG == null;

  /// Names of the nutrition values that were not found.
  List<String> get missing => [
    if (kcal == null) 'energy',
    if (proteinG == null) 'protein',
    if (fatG == null) 'fat',
    if (carbsG == null) 'carbohydrates',
  ];
}

// A number such as 12, 12.5, 12,5 or <0.5 (trace amounts).
const _num = r'(<?\s*\d+(?:[.,]\d+)?)';

final _kcalRe = RegExp(
  '$_num\\s*(?:kcal|cal|קלוריות|קק"ל|קק״ל|קקל)',
  caseSensitive: false,
);
// Hebrew labels often print the unit before the number: "קלוריות 120".
final _kcalBeforeRe = RegExp(
  '(?:kcal|calories|קלוריות|קק"ל|קק״ל)\\s*[:=]?\\s*$_num',
  caseSensitive: false,
);
final _kjRe = RegExp('$_num\\s*(?:kj|קג"ז|קג״ז)', caseSensitive: false);
final _loneNumberRe = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*$');
final _gramRe = RegExp(
  '$_num\\s*(?:g|gr|gram|grams|גרם|ג\'|ג)(?![a-z֐-׿])',
  caseSensitive: false,
);

final _per100Re = RegExp(
  r'(?:per|for|/)?\s*100\s*(?:g|gr|gram|grams|ml)\b|100\s*(?:גרם|גר|ג\x27|מ"ל)|ל\s*-?\s*100',
  caseSensitive: false,
);
final _perServingRe = RegExp(
  r'per\s+serving|per\s+portion|serving\s+size|\bserving\b|\bportion\b|'
  r'למנה|לכל מנה|גודל מנה|מנה',
  caseSensitive: false,
);
// A column header for a serving ("per serving", "per 30 g", "למנה"), as
// opposed to a mere mention of "serving size". Only this makes a label
// two-column.
final _servingColumnRe = RegExp(
  r'per\s+serving|per\s+portion|\bper\s+(?!100\b)(\d+(?:[.,]\d+)?)\s*(?:g|gr)\b|'
  r'למנה|לכל מנה',
  caseSensitive: false,
);
final _servingGramsRe = RegExp(
  '(?:serving size|serving|per serving|per portion|portion|גודל מנה|למנה|מנה)'
  '[^\\d\\n]{0,24}$_num\\s*(?:g|gr|grams?|גרם|ג\')(?![a-z])',
  caseSensitive: false,
);
final _parenGramsRe = RegExp(
  '\\(\\s*$_num\\s*(?:g|gr|grams?|גרם)\\s*\\)',
  caseSensitive: false,
);

/// Words that mark a sub-line of a nutrient ("of which sugars", "saturated
/// fat"); such a line never gives the parent nutrient's number.
final _subLineRe = RegExp(
  r'of which|saturat|trans|sugar|fib(?:re|er)|polyunsat|monounsat|starch|'
  r'lactose|מתוכם|רוויים|רווי|סוכר|סיבים|טרנס',
  caseSensitive: false,
);

final _energyRe = RegExp(
  r'energy|calorie|kcal|אנרגיה|אנרגטי|קלוריות|קק"ל|קק״ל',
  caseSensitive: false,
);
final _proteinRe = RegExp(r'protein|חלבון|חלבונים', caseSensitive: false);
final _fatRe = RegExp(r'\bfats?\b|שומן|שומנים', caseSensitive: false);
final _carbsRe = RegExp(
  r'carbohydrate|carbs?\b|פחמימה|פחמימות',
  caseSensitive: false,
);

double? _toDouble(String s) {
  final t = s.replaceAll(RegExp(r'\s'), '');
  if (t.startsWith('<')) return 0;
  return double.tryParse(t.replaceAll(',', '.'));
}

List<double> _numbersIn(String line, RegExp re) => [
  for (final m in re.allMatches(line)) ?_toDouble(m.group(1)!),
];

/// Parses OCR [text] from a nutrition label.
LabelScan parseNutritionLabel(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const LabelScan();

  // Column layout: where do the "per 100 g" and "per serving" headers sit?
  // Two-column labels print one number per column, in that order.
  final joined = lines.join('\n');
  final p100 = _per100Re.firstMatch(joined);
  final servingColumn = _servingColumnRe
      .allMatches(joined)
      .where((m) => p100 == null || !_overlaps(m, p100))
      .firstOrNull;
  final twoColumns = p100 != null && servingColumn != null;
  ScannedBasis? basis;
  var column = 0; // which of the numbers on a line to take
  if (twoColumns) {
    basis = ScannedBasis.per100g;
    column = servingColumn.start < p100.start ? 1 : 0;
  } else if (p100 != null) {
    basis = ScannedBasis.per100g;
  } else if (servingColumn != null || _perServingRe.hasMatch(joined)) {
    basis = ScannedBasis.perServing;
  }

  double? servingGrams;
  final sm =
      _servingGramsRe.firstMatch(joined) ?? _parenGramsRe.firstMatch(joined);
  if (sm != null) {
    final v = _toDouble(sm.group(1)!);
    if (v != null && v > 0) servingGrams = v;
  }
  // "per 30 g serving" in a column header.
  if (servingGrams == null && servingColumn?.group(1) != null) {
    final v = _toDouble(servingColumn!.group(1)!);
    if (v != null && v > 0) servingGrams = v;
  }

  // The value in the [column]th position, or the only one there is.
  double? pick(List<double> values) {
    if (values.isEmpty) return null;
    if (values.length == 1) {
      // One number on a two-column label can't be told apart: skip it.
      return twoColumns ? null : values.first;
    }
    return column < values.length ? values[column] : values.first;
  }

  // Text to read a nutrient's numbers from: its own line, or the next line
  // when its own has none and the next is not another nutrient's name.
  String? valueText(int i, RegExp numbers) {
    if (numbers.hasMatch(lines[i])) return lines[i];
    // Two-column labels split into separate lines can't be told apart.
    if (!twoColumns &&
        i + 1 < lines.length &&
        numbers.hasMatch(lines[i + 1]) &&
        !_isNutrientName(lines[i + 1])) {
      return lines[i + 1];
    }
    return null;
  }

  double? find(RegExp name, double? Function(String) read, RegExp numbers) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!name.hasMatch(line)) continue;
      if (_subLineRe.hasMatch(line)) continue;
      final t = valueText(i, numbers);
      if (t == null) continue;
      final v = read(t);
      if (v != null) return v;
    }
    return null;
  }

  double? readGrams(String t) => pick(_numbersIn(t, _gramRe));
  // Energy: a kcal number on the keyword line or the (up to) two lines
  // after it, before falling back to kJ (converted), as many labels print
  // "Energy 1580 kJ" and "378 kcal" on separate lines. With no unit at all,
  // a lone number on the next line ("Calories" / "230") counts.
  double? findEnergy() {
    for (var i = 0; i < lines.length; i++) {
      if (!_energyRe.hasMatch(lines[i]) || _subLineRe.hasMatch(lines[i])) {
        continue;
      }
      final window = <String>[lines[i]];
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        if (_isNutrientName(lines[j])) break;
        if (twoColumns && !_kcalRe.hasMatch(lines[j])) break;
        window.add(lines[j]);
      }
      for (final t in window) {
        final v =
            pick(_numbersIn(t, _kcalRe)) ?? pick(_numbersIn(t, _kcalBeforeRe));
        if (v != null) return v;
      }
      for (final t in window) {
        final v = pick(_numbersIn(t, _kjRe));
        if (v != null) return (v / kjPerKcal).roundToDouble();
      }
      if (!twoColumns && window.length > 1 && !_kjRe.hasMatch(lines[i])) {
        final m = _loneNumberRe.firstMatch(window[1]);
        if (m != null) return _toDouble(m.group(1)!);
      }
    }
    return null;
  }


  return LabelScan(
    basis: basis,
    kcal: findEnergy(),
    proteinG: find(_proteinRe, readGrams, _gramRe),
    fatG: find(_fatRe, readGrams, _gramRe),
    carbsG: find(_carbsRe, readGrams, _gramRe),
    servingGrams: servingGrams,
  );
}

bool _overlaps(RegExpMatch a, RegExpMatch b) =>
    a.start < b.end && b.start < a.end;

bool _isNutrientName(String line) =>
    _energyRe.hasMatch(line) ||
    _proteinRe.hasMatch(line) ||
    _fatRe.hasMatch(line) ||
    _carbsRe.hasMatch(line) ||
    _subLineRe.hasMatch(line);
