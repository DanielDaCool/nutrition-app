/// Reads the text a photo of a nutrition label produced into numbers for the
/// "Add from label" form. Pure Dart: no Flutter or DB imports.
///
/// This is a best-effort reader of noisy OCR text. It fills in a nutrient from
/// the numbers on its own line (or the next line or two), pairs a run of names
/// with the run of values that follows when OCR split a table into blocks, and
/// leaves anything it is unsure of null; the user always reviews the numbers
/// before saving.
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
  '\\(\\s*$_num\\s*(?:g|gr|grams?|גרם)',
  caseSensitive: false,
);

enum _Kind { energy, protein, fat, carbs, sub, other }

// Word lists per kind. Latin words are matched with a small typo allowance
// (OCR turns "saturates" into "soturates"); Hebrew by substring.
const _energyWords = [
  'energy', 'energie', 'energia', 'energi', 'calories', 'calorie',
  'kalorier', 'kalorien', //
];
const _proteinWords = [
  'protein',
  'proteins',
  'proteine',
  'proteini',
  'proteiner',
  'eiweiss',
  'eiweiß',
  'proteinas',
  'proteinen',
  'beljakovine',
];
const _fatWords = [
  'fat',
  'fats',
  'fett',
  'fedt',
  'fet',
  'lipides',
  'lipids',
  'grasas',
  'maščobe',
  'grăsimi',
  'rasvat',
  'rasva',
  'gras',
];
const _carbWords = [
  'carbohydrate',
  'carbohydrates',
  'carbs',
  'carb',
  'carbohydrat',
  'glucides',
  'kohlenhydrate',
  'kolhydrat',
  'kolhydrater',
  'hydrates',
  'hydrati',
  'hidrati',
  'glucide',
  'hiilihydraatit',
  'karbohydrater',
];
const _subWords = [
  'saturates',
  'saturated',
  'saturats',
  'sugars',
  'sugar',
  'fibre',
  'fiber',
  'starch',
  'polyols',
  'trans',
  'mono',
  'poly',
  'polyunsaturates',
  'monounsaturates',
  'lactose',
  'varav',
  'sockerarter',
  'sukkerarter',
  'zucker',
  'sucres',
  'zuccheri',
];
const _otherWords = [
  'salt',
  'sodium',
  'sel',
  'sale',
  'cholesterol',
  'calcium',
  'iron',
  'potassium',
  'magnesium',
  'zinc',
  'vitamin',
  'vit',
  'natrium',
  'sal',
  'fibres',
  'ballaststoffe',
  'kuitu',
  'kostfiber',
  'vitamina',
];
const _hebrew = {
  _Kind.energy: ['אנרגיה', 'אנרגטי', 'קלוריות', 'קק"ל', 'קק״ל'],
  _Kind.protein: ['חלבון', 'חלבונים'],
  _Kind.fat: ['שומן', 'שומנים'],
  _Kind.carbs: ['פחמימה', 'פחמימות'],
  _Kind.sub: ['מתוכם', 'רוויים', 'רווי', 'סוכר', 'סיבים', 'טרנס'],
};

int _distance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Whether any of [words] is one of [list], allowing OCR typos in the longer
/// list entries (none in entries of 4 letters or fewer, so "facts" is not
/// "fats").
bool _hasWord(List<String> words, List<String> list) {
  for (final t in list) {
    if (t.length < 3) continue;
    final max = t.length <= 4 ? 0 : (t.length <= 7 ? 1 : 2);
    for (final w in words) {
      if ((w.length - t.length).abs() > max) continue;
      if (_distance(w, t, max) <= max) return true;
    }
  }
  return false;
}

/// A nutrient name found in a line: its kind and where the name ends.
typedef _Name = ({_Kind kind, int end});

final _letters = RegExp(r"[^\d\s\p{P}\p{S}]+", unicode: true);

/// What nutrient name [line] holds, or null when it names none.
/// "of which" lines and saturates/sugars/fibre are [_Kind.sub], never the
/// parent nutrient.
_Name? _nameIn(String line) {
  final lower = line.toLowerCase();
  for (final e in _hebrew.entries) {
    for (final h in e.value) {
      final at = line.indexOf(h);
      if (at >= 0) return (kind: e.key, end: at + h.length);
    }
  }
  final which = lower.indexOf('of which');
  if (which >= 0) return (kind: _Kind.sub, end: which + 8);
  final matches = [
    for (final m in _letters.allMatches(lower)) (word: m.group(0)!, end: m.end),
  ];
  if (matches.isEmpty) return null;
  // Order matters: "saturated fat" is a sub-line, "total fat" is fat.
  for (final (kind, list) in [
    (_Kind.sub, _subWords),
    (_Kind.energy, _energyWords),
    (_Kind.protein, _proteinWords),
    (_Kind.carbs, _carbWords),
    (_Kind.fat, _fatWords),
    (_Kind.other, _otherWords),
  ]) {
    for (final m in matches) {
      if (_hasWord([m.word], list)) return (kind: kind, end: m.end);
    }
  }
  return null;
}

// A reference-intake footnote ("8400 kJ/2000 kcal") is not the food's energy.
final _referenceRe = RegExp(
  r'(?:2000|2\.000|2,000)\s*k?cal|8400\s*k?j|reference intake|recommended daily',
  caseSensitive: false,
);

double? _toDouble(String s) {
  final t = s.replaceAll(RegExp(r'\s'), '');
  if (t.startsWith('<')) return 0;
  return double.tryParse(t.replaceAll(',', '.'));
}

// A number written "08" or "05" is a misread ("S08kcal" for 508 kcal):
// real labels write 0.8 or 8.
List<double> _numbersIn(String line, RegExp re) => [
  for (final m in re.allMatches(line))
    if (!RegExp(r'^\s*<?\s*0\d').hasMatch(m.group(1)!)) ?_toDouble(m.group(1)!),
];

// A line that is only a value: "349 kcal", "0.9g", "1475 kJ", "11%".
final _valueLineRe = RegExp(
  r'^\s*(<?\s*\d+(?:[.,]\d+)?)\s*(g|gr|mg|µg|mcg|kj|kcal|cal|ml|%)?\s*$',
  caseSensitive: false,
);

/// Parses OCR [text] from a nutrition label.
LabelScan parseNutritionLabel(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !_referenceRe.hasMatch(l))
      .toList();
  if (lines.isEmpty) return const LabelScan();
  final names = [for (final l in lines) _nameIn(l)];
  final kinds = [for (final n in names) n?.kind];

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
  // A serving size and no "per 100 g" anywhere: the numbers are per serving.
  if (basis == null && servingGrams != null) basis = ScannedBasis.perServing;
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

  bool isName(int i) => kinds[i] != null;

  // Text to read a nutrient's numbers from: its own line, or the next line
  // when its own has none and the next is not another nutrient's name.
  String? valueText(int i, RegExp numbers) {
    final after = lines[i].substring(names[i]?.end ?? 0);
    if (numbers.hasMatch(after)) return after;
    // Two-column labels split into separate lines can't be told apart.
    if (!twoColumns &&
        i + 1 < lines.length &&
        numbers.hasMatch(lines[i + 1]) &&
        !_per100Re.hasMatch(lines[i + 1]) &&
        !isName(i + 1)) {
      return lines[i + 1];
    }
    return null;
  }

  double? find(_Kind kind, RegExp numbers) {
    for (var i = 0; i < lines.length; i++) {
      if (kinds[i] != kind) continue;
      final t = valueText(i, numbers);
      if (t == null) continue;
      final v = pick(_numbersIn(t, numbers));
      if (v != null) return v;
    }
    return null;
  }

  // Energy: a kcal number on the keyword line or the (up to) two lines
  // after it, before falling back to kJ (converted), as many labels print
  // "Energy 1580 kJ" and "378 kcal" on separate lines. With no unit at all,
  // a lone number on the next line ("Calories" / "230") counts.
  double? findEnergy() {
    for (var i = 0; i < lines.length; i++) {
      if (kinds[i] != _Kind.energy) continue;
      final window = <String>[lines[i]];
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        if (isName(j)) break;
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

  var kcal = findEnergy();
  var protein = find(_Kind.protein, _gramRe);
  var fat = find(_Kind.fat, _gramRe);
  var carbs = find(_Kind.carbs, _gramRe);

  // Labels read as a block of names followed by a block of values, in the
  // same order. Used only for what the line-by-line pass did not find, and
  // only when the counts line up exactly, so a mismatch reads nothing
  // rather than the wrong column.
  if (kcal == null || protein == null || fat == null || carbs == null) {
    final aligned = _alignBlocks(lines, kinds, twoColumns: twoColumns);
    kcal ??= aligned[_Kind.energy];
    protein ??= aligned[_Kind.protein];
    fat ??= aligned[_Kind.fat];
    carbs ??= aligned[_Kind.carbs];
  }

  // Per 100 g nothing exceeds 100 g and energy tops out near 900 kcal; such
  // a number is a misread (a "100 g" header, a dropped digit). Unknown
  // basis is treated like per 100 g, as the form will.
  final per100 = basis != ScannedBasis.perServing;
  if (per100) {
    if (kcal != null && kcal > 900) kcal = null;
    if (protein != null && protein > 100) protein = null;
    if (fat != null && fat > 100) fat = null;
    if (carbs != null && carbs > 100) carbs = null;
  }

  return LabelScan(
    basis: basis,
    kcal: kcal,
    proteinG: protein,
    fatG: fat,
    carbsG: carbs,
    servingGrams: servingGrams,
  );
}

/// Pairs a run of nutrient-name lines with the run of value-only lines that
/// follows, by position. Returns nothing for a label whose name and value
/// counts differ (a missed or merged line makes every pairing after it wrong).
/// Energy takes a kJ and a kcal value when both are printed.
Map<_Kind, double> _alignBlocks(
  List<String> lines,
  List<_Kind?> kinds, {
  required bool twoColumns,
}) {
  // Longest run of consecutive name-only lines.
  int? runStart;
  var bestStart = -1, bestLen = 0;
  for (var i = 0; i <= lines.length; i++) {
    final nameOnly =
        i < lines.length &&
        kinds[i] != null &&
        !RegExp(r'\d').hasMatch(lines[i]);
    if (nameOnly) {
      runStart ??= i;
    } else if (runStart != null) {
      if (i - runStart > bestLen) {
        bestStart = runStart;
        bestLen = i - runStart;
      }
      runStart = null;
    }
  }
  if (bestLen < 3) return const {};
  final names = [for (var i = 0; i < bestLen; i++) kinds[bestStart + i]!];
  if (!names.contains(_Kind.energy) &&
      names.where((k) => k != _Kind.sub && k != _Kind.other).length < 2) {
    return const {};
  }

  // The value-only lines after the names; a few header lines may sit between
  // the two blocks. Values come as one or more columns, each a run.
  var i = bestStart + bestLen;
  var skipped = 0;
  while (i < lines.length && !_valueLineRe.hasMatch(lines[i]) && skipped < 10) {
    i++;
    skipped++;
  }
  final first = <double>[];
  final units = <String>[];
  while (i < lines.length && _valueLineRe.hasMatch(lines[i])) {
    final m = _valueLineRe.firstMatch(lines[i])!;
    first.add(_toDouble(m.group(1)!) ?? double.nan);
    units.add((m.group(2) ?? '').toLowerCase());
    i++;
  }
  if (first.isEmpty || first.any((v) => v.isNaN)) return const {};

  // Energy printed as "kJ" then "kcal" uses two values.
  final energyIdx = names.indexOf(_Kind.energy);
  var energyKcal = double.nan;
  final out = <_Kind, double>{};
  final expectedPlain = names.length;
  var values = List<double>.from(first);
  if (energyIdx >= 0 &&
      values.length == expectedPlain + 1 &&
      units.length > energyIdx + 1 &&
      units[energyIdx] == 'kj' &&
      units[energyIdx + 1] == 'kcal') {
    energyKcal = values[energyIdx + 1];
    values = [
      ...values.sublist(0, energyIdx + 1),
      ...values.sublist(energyIdx + 2),
    ];
    units.removeAt(energyIdx + 1);
  } else if (values.length != expectedPlain) {
    return const {};
  } else if (energyIdx >= 0 && units[energyIdx] == 'kj') {
    energyKcal = (values[energyIdx] / kjPerKcal).roundToDouble();
  } else if (energyIdx >= 0) {
    energyKcal = values[energyIdx];
  }
  for (var idx = 0; idx < names.length; idx++) {
    switch (names[idx]) {
      case _Kind.energy:
        if (!energyKcal.isNaN) out[_Kind.energy] = energyKcal;
      case _Kind.protein || _Kind.fat || _Kind.carbs:
        // Only a value in grams (or unitless) is a macro.
        if (units[idx] == '' || units[idx] == 'g' || units[idx] == 'gr') {
          out[names[idx]] = values[idx];
        }
      default:
    }
  }
  return out;
}

bool _overlaps(RegExpMatch a, RegExpMatch b) =>
    a.start < b.end && b.start < a.end;
