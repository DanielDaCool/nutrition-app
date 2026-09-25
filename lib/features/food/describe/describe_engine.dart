/// Puts the parser, matcher, unit weights and memory together: text in,
/// items with a food, grams and nutrition out.
///
/// Pure Dart: no Flutter or DB imports.
library;

import '../../../domain/models.dart';
import '../nutrition_math.dart';
import 'describe_memory.dart';
import 'food_matcher.dart';
import 'food_text.dart';
import 'meal_text_parser.dart';
import 'unit_weights.dart';

/// One understood (or not understood) item of the text.
class ParsedItem {
  const ParsedItem({
    required this.key,
    required this.phrase,
    required this.matches,
    this.match,
    this.estimate,
  });

  /// Stable while the phrase's text stays the same, so edits to this item
  /// survive re-parsing as the user keeps typing.
  final String key;
  final ParsedPhrase phrase;

  /// Ranked foods for the phrase, best first (may be empty).
  final List<FoodMatch> matches;

  /// The food used, or null when nothing fit well enough.
  final FoodMatch? match;

  /// Grams for [match]; null when there is no match.
  final GramsEstimate? estimate;

  String get originalText => phrase.original;
  double get quantity => phrase.quantity;
  MeasureUnit? get unit => phrase.unit;
  String get foodPhrase => phrase.foodText;
  double? get grams => estimate?.grams;
  String? get gramsExplanation => estimate?.explanation;

  /// Worth a second look: no confident food, a guessed weight, or an amount
  /// big enough that it's probably misread ("10 bamba" as ten bags).
  bool get needsLook =>
      match == null ||
      !match!.isConfident ||
      estimate?.confidence == WeightConfidence.guess ||
      (macros?.kcal ?? 0) > suspiciousKcal;

  /// One item above this many kcal gets a "check this" hint.
  static const suspiciousKcal = 1000.0;

  /// Nutrition of [grams] of the matched food.
  Macros? get macros => match == null || estimate == null
      ? null
      : macrosForGrams(match!.candidate.per100g, estimate!.grams);
}

/// The whole text, understood.
class ParseResult {
  const ParseResult({required this.items, this.unrecognized = const []});

  static const empty = ParseResult(items: []);

  final List<ParsedItem> items;

  /// Parts with an amount but no food words, e.g. "200g".
  final List<String> unrecognized;
}

/// Parses meal descriptions against a fixed set of foods and memory.
class DescribeEngine {
  DescribeEngine(List<FoodCandidate> candidates, this.memory)
    : matcher = FoodMatcher(candidates),
      _keepTogether = {
        for (final c in candidates)
          for (final n in [c.name, ...c.aliases])
            if (n.contains(' with ') || n.contains(' and ')) n.toLowerCase(),
      };

  final FoodMatcher matcher;
  final DescribeMemory memory;
  final Set<String> _keepTogether;

  /// Understands [text].
  ParseResult parse(String text) {
    final parsed = parseMealText(text, keepTogether: _keepTogether);
    final items = <ParsedItem>[];
    final unrecognized = <String>[];
    final seen = <String, int>{};
    for (final p in parsed.phrases) {
      if (p.foodText.isEmpty) {
        unrecognized.add(p.original);
        continue;
      }
      final base = normalizePhrase(p.original);
      final n = seen[base] = (seen[base] ?? 0) + 1;
      items.add(_item('$base#$n', p));
    }
    return ParseResult(items: items, unrecognized: unrecognized);
  }

  ParsedItem _item(String key, ParsedPhrase p) {
    final percent = _asPercent(p);
    if (percent != null) return _item(key, percent);

    final matches = matcher.rank(
      p.foodText,
      learnedKey: memory.foodFor(p.foodText),
    );
    final top = matches.isEmpty ? null : matches.first;
    final match = top != null && top.score >= FoodMatcher.acceptScore
        ? top
        : null;
    return ParsedItem(
      key: key,
      phrase: p,
      matches: matches,
      match: match,
      estimate: match == null ? null : _estimate(match.candidate, p),
    );
  }

  /// "cottage 3" / "milk 1": a bare number after the food is its fat % when
  /// a food with that % exists, e.g. "Cottage cheese 3%".
  ParsedPhrase? _asPercent(ParsedPhrase p) {
    if (!p.numberAfterFood || p.foodText.contains('%')) return null;
    final n = p.quantity;
    if (n <= 0 || n > 40) return null;
    final pct = '${n == n.roundToDouble() ? n.round() : n}%';
    final text = '${p.foodText} $pct';
    final ranked = matcher.rank(text, learnedKey: memory.foodFor(text));
    if (ranked.isEmpty || !ranked.first.isConfident) return null;
    if (!ranked.first.candidate.name.toLowerCase().contains(pct)) return null;
    return ParsedPhrase(
      original: p.original,
      quantity: 1,
      unit: null,
      foodText: text,
      quantityGiven: false,
    );
  }

  /// Grams for [p]; "25 almonds" counts pieces when the food has a known
  /// piece weight, otherwise a bare number of 20+ stays grams.
  GramsEstimate _estimate(FoodCandidate food, ParsedPhrase p) {
    if (p.gramsAssumed && !p.numberAfterFood && _looksPlural(p.foodText)) {
      final pieces = gramsFor(food, p.quantity, MeasureUnit.piece);
      if (pieces.confidence != WeightConfidence.guess) return pieces;
    }
    return gramsFor(food, p.quantity, p.unit);
  }

  static bool _looksPlural(String foodText) {
    final last = foodText.split(' ').last;
    return last.length > 3 &&
        last.endsWith('s') &&
        !last.endsWith('ss') &&
        !last.endsWith('us') &&
        singularize(last) != last;
  }

  /// Grams for [quantity] [unit] of [food], using what the user taught.
  GramsEstimate gramsFor(
    FoodCandidate food,
    double quantity,
    MeasureUnit? unit,
  ) => estimateGrams(
    quantity: quantity,
    unit: unit,
    food: food.weightInfo,
    learnedGramsPerUnit: memory.gramsPerUnit(food.key, unit),
  );

  /// Foods for a typed search in the food picker, best first.
  List<FoodMatch> search(String query, {int limit = 20}) =>
      matcher.rank(query, learnedKey: memory.foodFor(query), limit: limit);
}
