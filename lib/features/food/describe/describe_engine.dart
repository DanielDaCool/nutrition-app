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

  /// Worth a second look: no confident food or a guessed weight.
  bool get needsLook =>
      match == null ||
      !match!.isConfident ||
      estimate?.confidence == WeightConfidence.guess;

  /// Nutrition of [grams] of the matched food.
  Macros? get macros => match == null || estimate == null
      ? null
      : macrosForGrams(match!.candidate.per100g, estimate!.grams);
}

/// The whole text, understood.
class ParseResult {
  const ParseResult({
    required this.items,
    this.suggestedMeal,
    this.unrecognized = const [],
  });

  static const empty = ParseResult(items: []);

  final List<ParsedItem> items;

  /// The meal the text mentions ("for breakfast").
  final Meal? suggestedMeal;

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
    return ParseResult(
      items: items,
      suggestedMeal: parsed.suggestedMeal,
      unrecognized: unrecognized,
    );
  }

  ParsedItem _item(String key, ParsedPhrase p) {
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
      estimate: match == null
          ? null
          : gramsFor(match.candidate, p.quantity, p.unit),
    );
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
