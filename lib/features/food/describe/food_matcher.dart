/// Ranks foods for a phrase like "cottage cheese 5%": learned names first,
/// then word overlap (with spelling variants, plurals and typos), agreement
/// on fat percentages, and a small bonus for the user's own, favorite and
/// recently used foods.
///
/// Pure Dart: no Flutter or DB imports.
library;

import 'dart:math' as math;

import '../../../domain/models.dart';
import 'builtin_foods.dart';
import 'food_text.dart';
import 'unit_weights.dart';

/// A food the matcher can pick: a saved food or a built-in one.
class FoodCandidate {
  const FoodCandidate({
    required this.key,
    required this.name,
    this.brand,
    required this.per100g,
    this.servingName,
    this.servingGrams,
    this.aliases = const [],
    this.foodId,
    this.builtinKey,
    this.isOwn = false,
    this.isFavorite = false,
    this.lastUsedAt,
    this.preferred = false,
  });

  /// A built-in food that isn't saved yet.
  factory FoodCandidate.builtin(BuiltinFood f) => FoodCandidate(
    key: builtinCandidateKey(f.key),
    name: f.name,
    per100g: f.per100g,
    servingName: f.servingName,
    servingGrams: f.servingGrams,
    aliases: f.aliases,
    builtinKey: f.key,
    preferred: f.preferred,
  );

  /// Stable identity used by the learned names: `food:<id>` for saved foods,
  /// `builtin:<key>` for built-in ones (saved or not).
  final String key;
  final String name;
  final String? brand;
  final Macros per100g;
  final String? servingName;
  final double? servingGrams;

  /// Other names that should match this food.
  final List<String> aliases;

  /// Row id in Foods, or null for a built-in food that isn't saved yet.
  final int? foodId;

  /// Set for built-in foods (typical values).
  final String? builtinKey;

  /// Created by the user.
  final bool isOwn;
  final bool isFavorite;

  /// When it was last logged, if ever.
  final DateTime? lastUsedAt;

  /// The usual pick among similar built-in foods.
  final bool preferred;

  bool get isBuiltin => builtinKey != null;

  /// What the unit weights need to know about this food.
  FoodWeightInfo get weightInfo => FoodWeightInfo(
    name: name,
    aliases: aliases,
    servingName: servingName,
    servingGrams: servingGrams,
    servingIsTypical: isBuiltin,
  );

  @override
  String toString() => 'FoodCandidate($key "$name")';
}

/// Candidate key of a saved food.
String foodCandidateKey(int foodId) => 'food:$foodId';

/// Candidate key of a built-in food.
String builtinCandidateKey(String builtinKey) => 'builtin:$builtinKey';

/// A ranked candidate for a phrase.
class FoodMatch {
  const FoodMatch(this.candidate, this.score, {this.learned = false});

  final FoodCandidate candidate;

  /// Roughly 0..1.2 for word matches; learned names score 2.
  final double score;

  /// The user picked this food for this phrase before.
  final bool learned;

  /// Good enough to use without asking.
  bool get isConfident => score >= FoodMatcher.confidentScore;

  @override
  String toString() =>
      'FoodMatch(${candidate.name}, ${score.toStringAsFixed(3)})';
}

class _Target {
  _Target(this.words, this.percents);

  final List<String> words;
  final Set<String> percents;
}

class _Indexed {
  _Indexed(this.candidate)
    : targets = [
        _target(candidate.name),
        for (final a in candidate.aliases) _target(a),
      ],
      brand = candidate.brand == null ? const [] : foodTokens(candidate.brand!),
      percents = foodTokens(candidate.name).where(isPercentToken).toSet();

  final FoodCandidate candidate;
  final List<_Target> targets;
  final List<String> brand;

  /// Fat percentages in the food's name ("5%").
  final Set<String> percents;

  static _Target _target(String text) {
    final t = foodTokens(text);
    return _Target(
      [
        for (final w in t)
          if (!isPercentToken(w)) w,
      ],
      {
        for (final w in t)
          if (isPercentToken(w)) w,
      },
    );
  }
}

/// Scores [FoodCandidate]s against phrases. Build once per candidate list.
class FoodMatcher {
  FoodMatcher(Iterable<FoodCandidate> candidates)
    : _index = [for (final c in candidates) _Indexed(c)];

  /// At or above: used without a "check this" hint.
  static const confidentScore = 0.8;

  /// Below: the phrase counts as not understood.
  static const acceptScore = 0.45;

  /// Lowest score still offered as an alternative.
  static const listScore = 0.3;

  final List<_Indexed> _index;

  /// All candidates, in the order given.
  Iterable<FoodCandidate> get candidates => _index.map((i) => i.candidate);

  /// Best matches for [phrase], best first. [learnedKey] is the food the user
  /// picked for this phrase before; it goes first.
  List<FoodMatch> rank(String phrase, {String? learnedKey, int limit = 8}) {
    final tokens = foodTokens(phrase);
    final words = [
      for (final t in tokens)
        if (!isPercentToken(t)) t,
    ];
    final percents = {
      for (final t in tokens)
        if (isPercentToken(t)) t,
    };
    final out = <FoodMatch>[];
    for (final c in _index) {
      if (learnedKey != null && c.candidate.key == learnedKey) {
        out.add(FoodMatch(c.candidate, 2, learned: true));
        continue;
      }
      final s = _score(words, percents, c);
      if (s >= listScore) out.add(FoodMatch(c.candidate, s));
    }
    out.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.candidate.name.length.compareTo(b.candidate.name.length);
    });
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  static double _score(List<String> words, Set<String> percents, _Indexed c) {
    if (words.isEmpty) return 0;
    var best = 0.0;
    for (var i = 0; i < c.targets.length; i++) {
      final t = c.targets[i];
      // The brand counts toward what was said, not against the name.
      final s = _overlap(words, t.words, i == 0 ? c.brand : const []);
      if (s > best) best = s;
    }
    if (best == 0) return 0;

    final cand = c.candidate;
    if (percents.isNotEmpty) {
      if (c.percents.any(percents.contains)) {
        best += 0.15;
      } else if (c.percents.isNotEmpty) {
        best -= 0.3;
      } else {
        best -= 0.05;
      }
    } else if (c.percents.isNotEmpty) {
      best -= 0.01;
    }
    if (cand.preferred) best += 0.03;
    if (cand.isFavorite) best += 0.06;
    if (cand.isOwn) best += 0.05;
    if (cand.lastUsedAt != null) best += 0.04;
    return best;
  }

  /// 0..1: how much of what was said is in [target] (recall, weighted 3/4)
  /// and how much of [target] was said (precision, 1/4).
  static double _overlap(
    List<String> said,
    List<String> target,
    List<String> brand,
  ) {
    if (target.isEmpty) return 0;
    var matched = 0.0;
    var targetHits = 0.0;
    for (final w in said) {
      var m = 0.0;
      var inTarget = false;
      for (final t in target) {
        final v = _wordMatch(w, t);
        if (v > m) {
          m = v;
          inTarget = true;
        }
      }
      for (final b in brand) {
        final v = _wordMatch(w, b);
        if (v > m) {
          m = v;
          inTarget = false;
        }
      }
      matched += m;
      if (inTarget) targetHits += m;
    }
    if (matched == 0) return 0;
    final recall = matched / said.length;
    final precision = math.min(1.0, targetHits / target.length);
    return 0.75 * recall + 0.25 * precision;
  }

  /// 1 for the same word, 0.8 for a prefix being typed ("cott") or a small
  /// typo ("cotage"), else 0.
  static double _wordMatch(String said, String word) {
    if (said == word) return 1;
    if (said.length >= 3 && word.startsWith(said)) return 0.8;
    if (said.length >= 5 && word.length >= 4) {
      final maxEdits = said.length >= 8 ? 2 : 1;
      if ((said.length - word.length).abs() <= maxEdits &&
          _editDistance(said, word, maxEdits) <= maxEdits) {
        return 0.8;
      }
    }
    return 0;
  }

  /// Levenshtein distance, giving up once it exceeds [limit].
  static int _editDistance(String a, String b, int limit) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
        rowMin = math.min(rowMin, cur[j]);
      }
      if (rowMin > limit) return limit + 1;
      prev = cur;
    }
    return prev[b.length];
  }
}
