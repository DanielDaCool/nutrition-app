/// Grams per spoon, cup, slice or piece: what the user taught, the food's
/// own serving, a per-food table for common foods, then generic fallbacks.
/// Every estimate says how it was derived so the UI can explain it.
///
/// Pure Dart: no Flutter or DB imports.
library;

import 'food_text.dart';
import 'meal_text_parser.dart';

/// How much to trust an estimated weight.
enum WeightConfidence {
  /// Said in grams, or from the label or the user's own correction.
  exact,

  /// A typical weight for this food and unit.
  typical,

  /// A generic fallback; worth a look.
  guess,
}

/// Grams for an amount, with a short explanation ("5 tbsp × 20 g").
class GramsEstimate {
  const GramsEstimate({
    required this.grams,
    required this.confidence,
    this.explanation,
  });

  final double grams;
  final WeightConfidence confidence;

  /// How [grams] was worked out; null when the user said grams.
  final String? explanation;

  @override
  String toString() => 'GramsEstimate($grams g, $confidence, $explanation)';
}

/// What [estimateGrams] needs to know about the food.
class FoodWeightInfo {
  const FoodWeightInfo({
    required this.name,
    this.aliases = const [],
    this.servingName,
    this.servingGrams,
    this.servingIsTypical = false,
  });

  final String name;

  /// Other names; used to find the food in the per-food table.
  final List<String> aliases;

  /// The food's serving, e.g. "1 slice (30 g)" or "large egg".
  final String? servingName;
  final double? servingGrams;

  /// True for built-in foods, whose serving is typical rather than from a
  /// label.
  final bool servingIsTypical;
}

/// Weights of common foods, first matching entry wins.
class _FoodUnits {
  const _FoodUnits(this.keywords, this.grams, {this.gramsPerMl = 1});

  /// Any of these (space-separated tokens, all required) selects the entry.
  final List<String> keywords;
  final Map<MeasureUnit, double> grams;

  /// Density used for ml and liters.
  final double gramsPerMl;

  bool matches(Set<String> tokens) =>
      keywords.any((k) => foodTokens(k).every(tokens.contains));
}

const _tbsp = MeasureUnit.tablespoon;
const _tsp = MeasureUnit.teaspoon;
const _cup = MeasureUnit.cup;
const _glass = MeasureUnit.glass;
const _slice = MeasureUnit.slice;
const _piece = MeasureUnit.piece;
const _handful = MeasureUnit.handful;
const _bowl = MeasureUnit.bowl;
const _plate = MeasureUnit.plate;
const _can = MeasureUnit.can;
const _scoop = MeasureUnit.scoop;
const _serving = MeasureUnit.serving;

/// Typical grams per unit. More specific entries come first ("egg white"
/// before "egg", "olive oil" before "olive").
const List<_FoodUnits> _table = [
  _FoodUnits(['egg white'], {_piece: 33, _tbsp: 15, _cup: 243}),
  _FoodUnits(
    ['scrambled egg', 'omelette'],
    {_serving: 120, _plate: 150, _piece: 60},
  ),
  _FoodUnits(['egg'], {_piece: 50}),
  _FoodUnits(['cottage'], {_tbsp: 20, _tsp: 7, _cup: 225}),
  _FoodUnits(
    ['white cheese', 'gvina levana', 'quark'],
    {_tbsp: 20, _tsp: 7, _cup: 230},
  ),
  _FoodUnits(['labaneh'], {_tbsp: 20, _tsp: 7}),
  _FoodUnits(['cream cheese'], {_tbsp: 15, _tsp: 5}),
  _FoodUnits(['hummus'], {_tbsp: 15, _tsp: 5, _cup: 240, _bowl: 200}),
  _FoodUnits(['tahini'], {_tbsp: 15, _tsp: 5}),
  _FoodUnits(['peanut butter', 'almond butter'], {_tbsp: 16, _tsp: 5}),
  _FoodUnits(['oil'], {_tbsp: 14, _tsp: 4.5}, gramsPerMl: 0.92),
  _FoodUnits(['butter'], {_tbsp: 14, _tsp: 5, _slice: 10}),
  _FoodUnits(['honey'], {_tbsp: 21, _tsp: 7}, gramsPerMl: 1.4),
  _FoodUnits(['sugar'], {_tbsp: 12, _tsp: 4}),
  _FoodUnits(['jam'], {_tbsp: 20, _tsp: 7}),
  _FoodUnits(['mayonnaise'], {_tbsp: 14, _tsp: 5}),
  _FoodUnits(['ice cream'], {_scoop: 66, _cup: 132, _bowl: 130}),
  _FoodUnits(['yogurt'], {_tbsp: 15, _tsp: 5, _cup: 245, _bowl: 245}),
  _FoodUnits(['milk'], {_tbsp: 15, _tsp: 5, _cup: 245, _glass: 245}),
  _FoodUnits(['rice cake'], {_piece: 9}),
  _FoodUnits(
    ['rice'],
    {_cup: 160, _tbsp: 12, _bowl: 250, _plate: 300, _serving: 160},
  ),
  _FoodUnits(
    ['pasta', 'spaghetti', 'penne', 'noodle', 'macaroni'],
    {_cup: 140, _bowl: 250, _plate: 300, _serving: 180},
  ),
  _FoodUnits(['quinoa'], {_cup: 185, _bowl: 250, _serving: 150}),
  _FoodUnits(['couscous'], {_cup: 157, _bowl: 250, _serving: 150}),
  _FoodUnits(['bulgur'], {_cup: 182, _bowl: 250, _serving: 150}),
  _FoodUnits(['oatmeal', 'porridge'], {_cup: 234, _bowl: 250}),
  _FoodUnits(['oat'], {_cup: 80, _tbsp: 10, _bowl: 50, _serving: 40}),
  _FoodUnits(['granola'], {_cup: 110, _tbsp: 12, _bowl: 60, _serving: 45}),
  _FoodUnits(['cornflake', 'cereal'], {_cup: 30, _bowl: 40, _serving: 30}),
  _FoodUnits(['lentil'], {_cup: 198, _bowl: 250, _tbsp: 12}),
  _FoodUnits(['chickpea'], {_cup: 164, _tbsp: 10, _handful: 40}),
  _FoodUnits(['bean'], {_cup: 172, _tbsp: 11}),
  _FoodUnits(
    ['almond', 'walnut', 'cashew', 'peanut', 'pistachio', 'nut'],
    {_handful: 30, _cup: 140, _tbsp: 9, _piece: 1.3},
  ),
  _FoodUnits(['seed'], {_handful: 30, _tbsp: 9, _tsp: 3}),
  _FoodUnits(['chocolate'], {_piece: 5, _slice: 5}),
  _FoodUnits(['whey', 'protein powder'], {_scoop: 30, _tbsp: 8}),
  _FoodUnits(
    ['coffee', 'latte', 'cappuccino', 'hafuch'],
    {_cup: 240, _glass: 240},
  ),
  _FoodUnits(['tea'], {_cup: 240, _glass: 240}),
  _FoodUnits(['juice'], {_glass: 240, _cup: 240}),
  _FoodUnits(['cola', 'soda'], {_can: 330, _glass: 240, _cup: 240}),
  _FoodUnits(['tuna'], {_can: 110}),
  _FoodUnits(['shakshuka'], {_plate: 300, _bowl: 300, _serving: 250}),
  _FoodUnits(['salad'], {_bowl: 200, _plate: 250, _cup: 100, _serving: 150}),
  _FoodUnits(['soup'], {_bowl: 350, _cup: 245, _plate: 350}),
  _FoodUnits(['schnitzel'], {_piece: 130}),
  _FoodUnits(['falafel'], {_piece: 17, _handful: 50}),
  _FoodUnits(['olive'], {_piece: 4, _handful: 30}),
  _FoodUnits(['pizza'], {_slice: 107, _piece: 107}),
  _FoodUnits(['bread roll', 'roll', 'bun'], {_piece: 60}),
  _FoodUnits(['challah'], {_slice: 40, _piece: 40}),
  _FoodUnits(['bread', 'toast'], {_slice: 30, _piece: 30}),
  _FoodUnits(['pita'], {_piece: 90}),
  _FoodUnits(['bagel'], {_piece: 100}),
  _FoodUnits(['tortilla', 'wrap'], {_piece: 45}),
  _FoodUnits(['croissant'], {_piece: 60}),
  _FoodUnits(['cookie', 'biscuit'], {_piece: 15}),
  _FoodUnits(['pancake'], {_piece: 40}),
  _FoodUnits(['protein bar'], {_piece: 60}),
  _FoodUnits(['pretzel'], {_handful: 30}),
  _FoodUnits(['chip', 'crisp', 'bamba'], {_handful: 20}),
  _FoodUnits(['cheese'], {_slice: 20, _piece: 20, _tbsp: 10, _cup: 113}),
  _FoodUnits(['banana'], {_piece: 120}),
  _FoodUnits(['apple'], {_piece: 180, _slice: 15}),
  _FoodUnits(['clementine', 'mandarin', 'tangerine'], {_piece: 75}),
  _FoodUnits(['orange'], {_piece: 150}),
  _FoodUnits(['cherry tomato'], {_piece: 17, _handful: 80}),
  _FoodUnits(['tomato'], {_piece: 120, _slice: 20}),
  _FoodUnits(['cucumber'], {_piece: 150, _slice: 8}),
  _FoodUnits(['date'], {_piece: 8}),
  _FoodUnits(['avocado'], {_piece: 150, _slice: 15, _tbsp: 15}),
  _FoodUnits(['carrot'], {_piece: 60}),
  _FoodUnits(['pepper'], {_piece: 120}),
  _FoodUnits(['onion'], {_piece: 110}),
  _FoodUnits(['potato'], {_piece: 150}),
  _FoodUnits(['strawberry'], {_piece: 12, _cup: 150, _handful: 60}),
  _FoodUnits(['blueberry'], {_cup: 148, _handful: 50}),
  _FoodUnits(['grape'], {_piece: 5, _cup: 150, _handful: 50}),
  _FoodUnits(['pear'], {_piece: 180}),
  _FoodUnits(['peach'], {_piece: 150}),
  _FoodUnits(['mango'], {_piece: 200, _cup: 165}),
  _FoodUnits(['watermelon'], {_slice: 280, _cup: 152}),
  _FoodUnits(['kiwi'], {_piece: 70}),
  _FoodUnits(['pomegranate'], {_piece: 250, _cup: 174}),
  _FoodUnits(['lettuce'], {_cup: 40, _handful: 20}),
  _FoodUnits(['broccoli'], {_cup: 90}),
  _FoodUnits(['cauliflower'], {_cup: 100}),
  _FoodUnits(['spinach'], {_cup: 30, _handful: 25}),
  _FoodUnits(['mushroom'], {_cup: 70, _piece: 18}),
  _FoodUnits(['zucchini'], {_piece: 200}),
  _FoodUnits(['pickle'], {_piece: 35}),
  _FoodUnits(['chicken breast'], {_piece: 170, _serving: 150}),
  _FoodUnits(['chicken thigh'], {_piece: 90}),
  _FoodUnits(['steak'], {_piece: 200, _serving: 150}),
  _FoodUnits(['burger', 'patty'], {_piece: 110}),
  _FoodUnits(['sausage', 'hot dog'], {_piece: 50}),
  _FoodUnits(['salmon'], {_piece: 150, _serving: 150}),
  _FoodUnits(['tofu'], {_cup: 250, _slice: 40}),
];

/// Used when nothing more specific is known.
const Map<MeasureUnit, double> _generic = {
  _tbsp: 15,
  _tsp: 5,
  _cup: 200,
  _glass: 240,
  _slice: 25,
  _handful: 30,
  _bowl: 300,
  _plate: 350,
  _scoop: 30,
  _can: 160,
  _piece: 100,
  _serving: 100,
};

/// Grams assumed when nothing at all is known about the portion.
const double defaultPortionGrams = 100;

_FoodUnits? _entryFor(FoodWeightInfo food) {
  final tokens = {
    ...foodTokens(food.name),
    for (final a in food.aliases) ...foodTokens(a),
  };
  for (final e in _table) {
    if (e.matches(tokens)) return e;
  }
  return null;
}

/// Typical grams per [unit] for [food] from the per-food table, or null.
double? typicalGramsPerUnit(FoodWeightInfo food, MeasureUnit unit) =>
    _entryFor(food)?.grams[unit];

/// The units worth offering for [food] in an amount editor: grams, units the
/// table knows for it, a serving when it has one, and the common ones.
List<MeasureUnit> sensibleUnits(FoodWeightInfo food, {MeasureUnit? current}) {
  final known = _entryFor(food)?.grams.keys ?? const <MeasureUnit>[];
  final set = <MeasureUnit>{
    MeasureUnit.gram,
    ?current,
    if (food.servingGrams != null) MeasureUnit.serving,
    ...known,
    MeasureUnit.tablespoon,
    MeasureUnit.teaspoon,
    MeasureUnit.cup,
    MeasureUnit.piece,
  };
  return [
    for (final u in MeasureUnit.values)
      if (set.contains(u)) u,
  ];
}

/// Whether [unit] names the food's serving: always for "serving", for
/// "piece" when the food has a serving, or when the serving's name says the
/// unit ("1 slice (30 g)", "cup").
bool _servingFits(FoodWeightInfo food, MeasureUnit? unit) {
  if (food.servingGrams == null || food.servingGrams! <= 0) return false;
  if (unit == null || unit == MeasureUnit.serving) return true;
  if (unit == MeasureUnit.piece) return true;
  final name = food.servingName;
  if (name == null) return false;
  return name
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .any((w) => unitFromWord(w) == unit);
}

String _fmt(double v) {
  final r = double.parse(v.toStringAsFixed(1));
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

/// "5 × " for 5, nothing for 1.
String _times(double q) => q == 1 ? '' : '${_fmt(q)} × ';

/// Grams in [quantity] [unit] of [food]. [learnedGramsPerUnit] is what the
/// user taught for this food and unit, if anything; it wins. A null [unit]
/// means no amount was said ("hummus").
GramsEstimate estimateGrams({
  required double quantity,
  required MeasureUnit? unit,
  required FoodWeightInfo food,
  double? learnedGramsPerUnit,
}) {
  final q = quantity;
  switch (unit) {
    case MeasureUnit.gram:
      return GramsEstimate(grams: q, confidence: WeightConfidence.exact);
    case MeasureUnit.kilogram:
      return GramsEstimate(
        grams: q * 1000,
        confidence: WeightConfidence.exact,
        explanation: '${_fmt(q)} kg = ${_fmt(q * 1000)} g',
      );
    case MeasureUnit.milliliter || MeasureUnit.liter:
      final ml = unit == MeasureUnit.liter ? q * 1000 : q;
      final density = _entryFor(food)?.gramsPerMl ?? 1;
      final grams = ml * density;
      return GramsEstimate(
        grams: grams,
        confidence: density == 1
            ? WeightConfidence.exact
            : WeightConfidence.typical,
        explanation: density == 1
            ? '${_fmt(ml)} ml ≈ ${_fmt(grams)} g'
            : '${_fmt(ml)} ml × ${density.toStringAsFixed(2)} g/ml',
      );
    default:
      break;
  }

  final unitName = unit?.label(1) ?? 'portion';
  if (learnedGramsPerUnit != null && learnedGramsPerUnit > 0) {
    return GramsEstimate(
      grams: q * learnedGramsPerUnit,
      confidence: WeightConfidence.exact,
      explanation:
          '${_times(q)}your usual $unitName (${_fmt(learnedGramsPerUnit)} g)',
    );
  }

  if (_servingFits(food, unit)) {
    final g = food.servingGrams!;
    if (food.servingIsTypical) {
      final name = food.servingName ?? 'serving';
      if (unit != null && unitFromWord(name) == unit) {
        // "2 slices × 30 g" reads better than "2 × slice (30 g)".
        return _perUnit(q, unit, g, WeightConfidence.typical);
      }
      return GramsEstimate(
        grams: q * g,
        confidence: WeightConfidence.typical,
        explanation: q == 1
            ? '1 $name ≈ ${_fmt(g)} g'
            : '${_fmt(q)} × $name (${_fmt(g)} g)',
      );
    }
    return GramsEstimate(
      grams: q * g,
      confidence: WeightConfidence.exact,
      explanation: '${_times(q)}serving on the label (${_fmt(g)} g)',
    );
  }

  final entry = _entryFor(food);
  final u = unit ?? MeasureUnit.serving;
  var typical = entry?.grams[u];
  var shownUnit = u;
  if (typical == null && u == MeasureUnit.serving) {
    // "banana" with no amount (or "1 serving"): one piece.
    typical = entry?.grams[MeasureUnit.piece];
    shownUnit = MeasureUnit.piece;
  }
  if (typical != null) {
    return _perUnit(q, shownUnit, typical, WeightConfidence.typical);
  }

  if (unit == null) {
    return const GramsEstimate(
      grams: defaultPortionGrams,
      confidence: WeightConfidence.guess,
      explanation: 'No amount given, guessed 100 g',
    );
  }
  return _perUnit(q, unit, _generic[unit]!, WeightConfidence.guess);
}

/// "5 tbsp × 20 g" / "1 cup ≈ 160 g"; guesses say so.
GramsEstimate _perUnit(
  double q,
  MeasureUnit unit,
  double gramsPerUnit,
  WeightConfidence confidence,
) {
  final guess = confidence == WeightConfidence.guess;
  final g = '${guess ? '~' : ''}${_fmt(gramsPerUnit)} g';
  final text = q == 1
      ? '1 ${unit.label(1)} ≈ $g'
      : '${_fmt(q)} ${unit.label(q)} × $g';
  return GramsEstimate(
    grams: q * gramsPerUnit,
    confidence: confidence,
    explanation: guess ? '$text (rough guess)' : text,
  );
}
