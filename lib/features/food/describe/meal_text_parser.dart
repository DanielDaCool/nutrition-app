/// Turns a meal typed in plain words ("2 eggs and a slice of bread with
/// hummus") into item phrases with a quantity, a unit and the food words.
///
/// Pure Dart: no Flutter or DB imports.
library;

/// A unit the user can say. Count words without a unit ("2 eggs") are
/// [piece].
enum MeasureUnit {
  gram,
  kilogram,
  milliliter,
  liter,
  tablespoon,
  teaspoon,
  cup,
  glass,
  slice,
  piece,
  handful,
  bowl,
  plate,
  can,
  scoop,
  serving;

  /// Weight and volume units convert to grams directly; the rest need a
  /// per-food or typical weight.
  bool get isMeasured =>
      this == gram || this == kilogram || this == milliliter || this == liter;

  /// Short label for [quantity] of this unit, e.g. "tbsp", "cups", "g".
  String label(double quantity) {
    final one = quantity > 0 && quantity <= 1;
    return switch (this) {
      gram => 'g',
      kilogram => 'kg',
      milliliter => 'ml',
      liter => 'l',
      tablespoon => 'tbsp',
      teaspoon => 'tsp',
      cup => one ? 'cup' : 'cups',
      glass => one ? 'glass' : 'glasses',
      slice => one ? 'slice' : 'slices',
      piece => one ? 'piece' : 'pieces',
      handful => one ? 'handful' : 'handfuls',
      bowl => one ? 'bowl' : 'bowls',
      plate => one ? 'plate' : 'plates',
      can => one ? 'can' : 'cans',
      scoop => one ? 'scoop' : 'scoops',
      serving => one ? 'serving' : 'servings',
    };
  }
}

/// One item phrase of the text, e.g. "5 spoons of cottage cheese 5%".
class ParsedPhrase {
  const ParsedPhrase({
    required this.original,
    required this.quantity,
    required this.unit,
    required this.foodText,
    required this.quantityGiven,
    this.numberAfterFood = false,
    this.gramsAssumed = false,
  });

  /// The phrase as typed, lowercased and tidied ("200g" -> "200 g"), without
  /// meal words.
  final String original;

  /// How many [unit]s; 1 when nothing was said ("hummus").
  final double quantity;

  /// Null when neither a unit nor a count was said ("some rice").
  final MeasureUnit? unit;

  /// The food words, lowercase, without amounts and filler words, e.g.
  /// "cottage cheese 5%". Empty when the phrase had no food words.
  final String foodText;

  /// False when the amount is a default rather than something the user said.
  final bool quantityGiven;

  /// The amount was a bare number after the food words ("cottage 3"), which
  /// may be a fat % rather than a count.
  final bool numberAfterFood;

  /// [unit] is grams only because a bare number was 20 or more ("25
  /// almonds"); a count may fit better for foods with a piece weight.
  final bool gramsAssumed;

  @override
  String toString() =>
      'ParsedPhrase($quantity ${unit?.name} "$foodText"'
      '${quantityGiven ? '' : ' (default)'})';
}

/// All phrases of a text.
class MealTextParse {
  const MealTextParse({required this.phrases});

  final List<ParsedPhrase> phrases;
}

// ------------------------------------------------------------------- units

const Map<String, MeasureUnit> _unitWords = {
  'g': MeasureUnit.gram,
  'gr': MeasureUnit.gram,
  'grs': MeasureUnit.gram,
  'gm': MeasureUnit.gram,
  'gram': MeasureUnit.gram,
  'grams': MeasureUnit.gram,
  'gramme': MeasureUnit.gram,
  'grammes': MeasureUnit.gram,
  'kg': MeasureUnit.kilogram,
  'kgs': MeasureUnit.kilogram,
  'kilo': MeasureUnit.kilogram,
  'kilos': MeasureUnit.kilogram,
  'kilogram': MeasureUnit.kilogram,
  'kilograms': MeasureUnit.kilogram,
  'ml': MeasureUnit.milliliter,
  'mls': MeasureUnit.milliliter,
  'milliliter': MeasureUnit.milliliter,
  'milliliters': MeasureUnit.milliliter,
  'millilitre': MeasureUnit.milliliter,
  'millilitres': MeasureUnit.milliliter,
  'l': MeasureUnit.liter,
  'ltr': MeasureUnit.liter,
  'liter': MeasureUnit.liter,
  'liters': MeasureUnit.liter,
  'litre': MeasureUnit.liter,
  'litres': MeasureUnit.liter,
  'tbsp': MeasureUnit.tablespoon,
  'tbsps': MeasureUnit.tablespoon,
  'tbs': MeasureUnit.tablespoon,
  'tablespoon': MeasureUnit.tablespoon,
  'tablespoons': MeasureUnit.tablespoon,
  'tablespoonful': MeasureUnit.tablespoon,
  'spoon': MeasureUnit.tablespoon,
  'spoons': MeasureUnit.tablespoon,
  'spoonful': MeasureUnit.tablespoon,
  'spoonfuls': MeasureUnit.tablespoon,
  'tsp': MeasureUnit.teaspoon,
  'tsps': MeasureUnit.teaspoon,
  'teaspoon': MeasureUnit.teaspoon,
  'teaspoons': MeasureUnit.teaspoon,
  'teaspoonful': MeasureUnit.teaspoon,
  'cup': MeasureUnit.cup,
  'cups': MeasureUnit.cup,
  'mug': MeasureUnit.cup,
  'mugs': MeasureUnit.cup,
  'glass': MeasureUnit.glass,
  'glasses': MeasureUnit.glass,
  'slice': MeasureUnit.slice,
  'slices': MeasureUnit.slice,
  'piece': MeasureUnit.piece,
  'pieces': MeasureUnit.piece,
  'pc': MeasureUnit.piece,
  'pcs': MeasureUnit.piece,
  'handful': MeasureUnit.handful,
  'handfuls': MeasureUnit.handful,
  'bowl': MeasureUnit.bowl,
  'bowls': MeasureUnit.bowl,
  'plate': MeasureUnit.plate,
  'plates': MeasureUnit.plate,
  'can': MeasureUnit.can,
  'cans': MeasureUnit.can,
  'tin': MeasureUnit.can,
  'tins': MeasureUnit.can,
  'scoop': MeasureUnit.scoop,
  'scoops': MeasureUnit.scoop,
  'serving': MeasureUnit.serving,
  'servings': MeasureUnit.serving,
  'portion': MeasureUnit.serving,
  'portions': MeasureUnit.serving,
};

/// Two-word units: "big spoon", "small spoon", "table spoon".
const Map<String, MeasureUnit> _twoWordUnits = {
  'big spoon': MeasureUnit.tablespoon,
  'big spoons': MeasureUnit.tablespoon,
  'large spoon': MeasureUnit.tablespoon,
  'large spoons': MeasureUnit.tablespoon,
  'table spoon': MeasureUnit.tablespoon,
  'table spoons': MeasureUnit.tablespoon,
  'soup spoon': MeasureUnit.tablespoon,
  'soup spoons': MeasureUnit.tablespoon,
  'small spoon': MeasureUnit.teaspoon,
  'small spoons': MeasureUnit.teaspoon,
  'little spoon': MeasureUnit.teaspoon,
  'little spoons': MeasureUnit.teaspoon,
  'tea spoon': MeasureUnit.teaspoon,
  'tea spoons': MeasureUnit.teaspoon,
  'coffee spoon': MeasureUnit.teaspoon,
  'coffee spoons': MeasureUnit.teaspoon,
};

/// The unit named by [word] alone, if it is one.
MeasureUnit? unitFromWord(String word) => _unitWords[word.toLowerCase()];

// -------------------------------------------------------------- quantities

const Map<String, double> _numberWords = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'dozen': 12,
  'half': 0.5,
  'quarter': 0.25,
  'couple': 2,
  'few': 3,
};

final _number = RegExp(r'^\d+(?:[.,]\d+)?$');
final _fraction = RegExp(r'^(\d+)/(\d+)$');

/// The value of a number token ("2", "1.5", "1,5", "1/2", "two"), or null.
double? _numberValue(String token) {
  if (_number.hasMatch(token)) {
    return double.tryParse(token.replaceAll(',', '.'));
  }
  final f = _fraction.firstMatch(token);
  if (f != null) {
    final d = int.parse(f.group(2)!);
    return d == 0 ? null : int.parse(f.group(1)!) / d;
  }
  return _numberWords[token];
}

/// Words dropped from the food text.
const _fillers = {
  'of',
  'some',
  'about',
  'around',
  'approx',
  'approximately',
  'roughly',
  'like',
  'my',
  'the',
  'a',
  'an',
  'i',
  'had',
  'have',
  'ate',
  'eaten',
  'eat',
  'drank',
  'drink',
  'just',
  'also',
  'then',
  'maybe',
  'another',
  'more',
  'extra',
  'little',
  'bit',
  'lot',
  'today',
  '~',
};

// ------------------------------------------------------------- meal words

final _mealWords = RegExp(
  r'\b(?:(?:for|at|as|during|in|on|with)\s+)?(?:(?:my|a|the|our)\s+)?'
  r'(breakfast|brunch|lunch|dinner|supper|snacks?)\b',
);

// ---------------------------------------------------------------- parsing

/// Splits on newlines, ';', '+', '&', '.', ' and ', ' with ', ' plus ' and
/// commas that aren't decimal commas ("1,5").
final _separators = RegExp(
  r'\n|;|\+|&|\.(?=\s|$)|(?<!\d),|,(?!\d)|\band\b|\bwith\b|\bplus\b',
);

/// Parses [text] into phrases. Food names in [keepTogether] (lowercase, e.g.
/// "coffee with milk") are not split at their "and"/"with".
MealTextParse parseMealText(
  String text, {
  Iterable<String> keepTogether = const [],
}) {
  var t = _normalize(text);

  // The meal comes from where the user tapped, so "for breakfast" is just
  // dropped rather than read as a food.
  t = t.replaceAll(_mealWords, ' , ');

  // Protect "coffee with milk" and similar names from the separators.
  for (final name in keepTogether) {
    if (!name.contains(' and ') && !name.contains(' with ')) continue;
    final pattern = RegExp('\\b${RegExp.escape(name)}\\b');
    // '_' is a word character, so the "with" separator can't match inside.
    t = t.replaceAllMapped(pattern, (m) => m.group(0)!.replaceAll(' ', '_'));
  }

  final phrases = <ParsedPhrase>[];
  for (final part in t.split(_separators)) {
    for (final run in _splitRuns(part)) {
      final p = parsePhrase(run.replaceAll('_', ' '));
      if (p != null) phrases.add(p);
    }
  }
  return MealTextParse(phrases: phrases);
}

/// Splits a part with several foods and no separator between them: "2
/// bananas 1 apple" before the "1", "eggs 3 toast 2" before "toast". Written
/// amount-first, a number right after a food word starts the next item;
/// written food-first (the part starts with a food and ends with an
/// amount), a food word right after an amount does. A piece left without
/// food words ("1 cup milk 3") stays with the one before.
List<String> _splitRuns(String part) {
  final raw = [
    for (final t in part.trim().split(RegExp(r'\s+')))
      if (t.isNotEmpty) t,
  ];
  if (raw.length < 3) return [part];
  final tokens = [for (final r in raw) r.replaceAll(_tokenEdge, '')];
  bool isNum(int i) => _isDigits(tokens[i]) || _fraction.hasMatch(tokens[i]);
  bool isFood(int i) {
    final t = tokens[i];
    return t.isNotEmpty &&
        _numberValue(t) == null &&
        !_fillers.contains(t) &&
        t != 'x' &&
        !_unitWords.containsKey(t) &&
        _readUnit(tokens, i) == null;
  }

  var lastNum = -1;
  for (var i = tokens.length - 1; i > 0; i--) {
    if (isNum(i)) {
      lastNum = i;
      break;
    }
  }
  final foodFirst =
      isFood(0) &&
      lastNum > 0 &&
      _readAmount(tokens, lastNum)?.end == tokens.length;

  final starts = <int>[0];
  var segHasFood = false;
  var afterAmount = false;
  for (var i = 0; i < tokens.length; i++) {
    if (isNum(i)) {
      if (!foodFirst && i > 0 && segHasFood && isFood(i - 1)) {
        starts.add(i);
        segHasFood = false;
      }
      if (foodFirst && segHasFood) {
        final end = _readAmount(tokens, i)?.end ?? i + 1;
        afterAmount = true;
        i = end - 1;
      }
      continue;
    }
    if (!isFood(i)) continue;
    if (foodFirst && afterAmount) {
      starts.add(i);
      afterAmount = false;
    }
    segHasFood = true;
  }
  if (starts.length == 1) return [part];

  final runs = <List<String>>[];
  for (var s = 0; s < starts.length; s++) {
    final end = s + 1 < starts.length ? starts[s + 1] : tokens.length;
    final hasFood = [for (var i = starts[s]; i < end; i++) isFood(i)]
        .any((f) => f);
    final words = raw.sublist(starts[s], end);
    if (!hasFood && runs.isNotEmpty) {
      runs.last.addAll(words);
    } else {
      runs.add(words);
    }
  }
  return [for (final r in runs) r.join(' ')];
}

/// Lowercases and rewrites the forms the tokenizer doesn't handle: unicode
/// fractions, "5 %", "and a half", "200g", "x2".
String _normalize(String text) {
  var t = text.toLowerCase().replaceAll('\u00d7', 'x');
  const vulgar = {
    '\u00bd': '1/2',
    '\u00bc': '1/4',
    '\u00be': '3/4',
    '\u2153': '1/3',
    '\u2154': '2/3',
  };
  vulgar.forEach((k, v) {
    // "1 and a half" as a vulgar fraction -> "1 1/2"
    t = t.replaceAllMapped(RegExp('(\\d)?$k'), (m) {
      return m.group(1) == null ? ' $v ' : '${m.group(1)} $v ';
    });
  });
  t = t
      .replaceAll(RegExp(r'[!?"()\[\]{}:]'), ' ')
      .replaceAllMapped(RegExp(r'(\d)\s*(?:%|percent\b)'), (m) => '${m[1]}% ')
      .replaceAllMapped(
        RegExp(
          r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)'
          r'\s+and\s+a\s+half\b',
        ),
        (m) => '${m[1]} 1/2',
      )
      .replaceAllMapped(RegExp(r'\ban?\s+half\b'), (_) => 'half')
      .replaceAllMapped(RegExp(r'\bhalf\s+an?\b'), (_) => 'half')
      .replaceAllMapped(
        RegExp(r'\b(?:a\s+)?(?:little\s+)?bit\s+of\b'),
        (_) => ' ',
      )
      .replaceAllMapped(RegExp(r'\ba\s+(?:little|lot\s+of)\b'), (_) => ' ')
      .replaceAllMapped(RegExp(r'\ba\s+(couple|few|dozen|quarter)\b'), (m) {
        return m[1]!;
      })
      // "200g" -> "200 g", "2x" -> "2 x"; keeps "5%" and "1.5" whole.
      .replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'(?<![a-z])x(?=\d)'), (_) => 'x ');
  return t;
}

final _tokenEdge = RegExp(r"^[.'\-/]+|[.'\-/]+$");

/// Parses one phrase ("5 spoons of cottage cheese 5%"). Returns null when it
/// holds neither food words nor an amount (e.g. "and", "i had").
ParsedPhrase? parsePhrase(String phrase) {
  final original = phrase.trim().replaceAll(RegExp(r'\s+'), ' ');
  final tokens = [
    for (final raw in _normalize(phrase).split(RegExp(r'\s+')))
      if (raw.replaceAll(_tokenEdge, '') case final t when t.isNotEmpty) t,
  ];
  // "i had 2 eggs", "about 200g chicken": skip leading filler words ("a" and
  // "an" are amounts).
  while (tokens.isNotEmpty &&
      _fillers.contains(tokens.first) &&
      tokens.first != 'a' &&
      tokens.first != 'an') {
    tokens.removeAt(0);
  }
  if (tokens.isEmpty) return null;

  double? quantity;
  MeasureUnit? unit;

  // "x2" / "2x" anywhere: a count.
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] != 'x') continue;
    final after = i + 1 < tokens.length ? _numberValue(tokens[i + 1]) : null;
    final before = i > 0 ? _numberValue(tokens[i - 1]) : null;
    if (after != null && _isDigits(tokens[i + 1])) {
      quantity = after;
      tokens.removeRange(i, i + 2);
      break;
    }
    if (before != null && _isDigits(tokens[i - 1])) {
      quantity = before;
      tokens.removeRange(i - 1, i + 1);
      break;
    }
  }

  // Amount at the start: "5 spoons of", "a cup of", "half an", "1 1/2 cups".
  if (quantity == null) {
    final lead = _readAmount(tokens, 0);
    if (lead != null) {
      quantity = lead.quantity;
      unit = lead.unit;
      tokens.removeRange(0, lead.end);
    }
  } else {
    final u = _readUnit(tokens, 0);
    if (u != null) {
      unit = u.$1;
      tokens.removeRange(0, u.$2);
    }
  }

  // Amount after the food: "rice 1 cup", "chicken breast 200g", "eggs 2".
  var numberAfterFood = false;
  if (quantity == null && unit == null) {
    for (var i = 1; i < tokens.length; i++) {
      if (!_isDigits(tokens[i]) && !_fraction.hasMatch(tokens[i])) continue;
      final a = _readAmount(tokens, i);
      if (a == null) continue;
      if (a.unit != null || a.end == tokens.length) {
        quantity = a.quantity;
        unit = a.unit;
        numberAfterFood = a.unit == null;
        tokens.removeRange(i, a.end);
        break;
      }
    }
  }

  final food = [
    for (final t in tokens)
      if (!_fillers.contains(t)) t,
  ].join(' ');

  if (food.isEmpty && quantity == null && unit == null) return null;

  final given = quantity != null;
  var gramsAssumed = false;
  if (quantity != null && unit == null) {
    // "rice 150" means grams; "2 eggs" means pieces.
    gramsAssumed = quantity >= 20;
    unit = gramsAssumed ? MeasureUnit.gram : MeasureUnit.piece;
  }
  return ParsedPhrase(
    original: original,
    quantity: quantity ?? 1,
    unit: unit,
    foodText: food,
    quantityGiven: given,
    numberAfterFood: numberAfterFood,
    gramsAssumed: gramsAssumed,
  );
}

bool _isDigits(String t) => _number.hasMatch(t);

typedef _Amount = ({double quantity, MeasureUnit? unit, int end});

/// Reads "[number] [fraction] [x] [unit] [of]" starting at [start]. A bare
/// unit ("cup of coffee") counts as 1. Returns null when there's no amount.
_Amount? _readAmount(List<String> tokens, int start) {
  var i = start;
  double? q;
  if (i < tokens.length && (tokens[i] == 'a' || tokens[i] == 'an')) {
    // "a banana", "a cup of"; "a" alone isn't an amount.
    if (i + 1 < tokens.length) {
      q = 1;
      i++;
      final n = _numberValue(tokens[i]);
      if (n != null && !_isDigits(tokens[i])) {
        // "a couple of", "a dozen"
        q = n;
        i++;
      }
    }
  } else if (i < tokens.length) {
    final n = _numberValue(tokens[i]);
    if (n != null) {
      q = n;
      i++;
      // mixed fraction "1 1/2"
      if (i < tokens.length && _fraction.hasMatch(tokens[i])) {
        q += _numberValue(tokens[i])!;
        i++;
      }
      if (i < tokens.length && tokens[i] == 'x') i++;
    }
  }
  final u = _readUnit(tokens, i);
  if (u != null) {
    i = u.$2;
    q ??= 1;
  }
  if (q == null) return null;
  if (i < tokens.length && tokens[i] == 'of') i++;
  return (quantity: q, unit: u?.$1, end: i);
}

/// The unit at [i] (one or two words) and the index after it.
(MeasureUnit, int)? _readUnit(List<String> tokens, int i) {
  if (i >= tokens.length) return null;
  if (i + 1 < tokens.length) {
    final two = _twoWordUnits['${tokens[i]} ${tokens[i + 1]}'];
    if (two != null) return (two, i + 2);
  }
  final one = _unitWords[tokens[i]];
  return one == null ? null : (one, i + 1);
}

// ------------------------------------------------------------ normalizing

const _pluralExceptions = {
  'hummus',
  'houmous',
  'humus',
  'couscous',
  'asparagus',
  'bus',
  'glass',
  'grass',
  'swiss',
  'cheese',
  'bissli',
  'series',
  'species',
  'molasses',
};

/// Singular form of a lowercase word, good enough for matching food names
/// (eggs -> egg, tomatoes -> tomato, berries -> berry, slices -> slice).
String singularize(String word) {
  final w = word;
  if (w.length <= 3 || _pluralExceptions.contains(w)) return w;
  if (w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.endsWith('oes')) return w.substring(0, w.length - 2);
  if (RegExp(r'(?:ss|x|ch|sh)es$').hasMatch(w)) {
    return w.substring(0, w.length - 2);
  }
  if (w.endsWith('ss') || w.endsWith('us') || w.endsWith('is')) return w;
  if (w.endsWith('s')) return w.substring(0, w.length - 1);
  return w;
}
