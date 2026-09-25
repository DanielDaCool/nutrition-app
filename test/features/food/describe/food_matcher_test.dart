import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/describe/builtin_foods.dart';
import 'package:nutrition_app/features/food/describe/describe_engine.dart';
import 'package:nutrition_app/features/food/describe/describe_memory.dart';
import 'package:nutrition_app/features/food/describe/food_matcher.dart';
import 'package:nutrition_app/features/food/describe/meal_text_parser.dart';
import 'package:nutrition_app/features/food/describe/unit_weights.dart';

const _m = Macros(kcal: 100, proteinG: 10, fatG: 2, carbsG: 10);

final _builtins = [for (final b in builtinFoods) FoodCandidate.builtin(b)];

FoodCandidate _own(
  int id,
  String name, {
  String? brand,
  bool own = true,
  bool favorite = false,
  DateTime? lastUsed,
}) => FoodCandidate(
  key: foodCandidateKey(id),
  name: name,
  brand: brand,
  per100g: _m,
  foodId: id,
  isOwn: own,
  isFavorite: favorite,
  lastUsedAt: lastUsed,
);

String? _top(FoodMatcher m, String phrase, {String? learned}) {
  final r = m.rank(phrase, learnedKey: learned);
  return r.isEmpty ? null : r.first.candidate.name;
}

void main() {
  final builtins = FoodMatcher(_builtins);

  test('5% prefers the 5% cottage, 3% the 3% one', () {
    expect(_top(builtins, 'cottage cheese 5%'), 'Cottage cheese 5%');
    expect(_top(builtins, 'cottage 3%'), 'Cottage cheese 3%');
    final r = builtins.rank('cottage 3%');
    final five = r.firstWhere((m) => m.candidate.name.contains('5%'));
    expect(five.score, lessThan(r.first.score - 0.3));
    // Plain "cottage" means 5%.
    expect(_top(builtins, 'cottage'), 'Cottage cheese 5%');
  });

  test('synonyms, spelling variants, plurals and typos', () {
    expect(_top(builtins, 'humus'), 'Hummus (spread)');
    expect(_top(builtins, 'houmous'), 'Hummus (spread)');
    expect(_top(builtins, 'pitta'), 'Pita');
    expect(_top(builtins, 'greek yoghurt'), 'Greek yogurt 0%');
    expect(_top(builtins, 'eggs'), 'Egg');
    expect(_top(builtins, 'tomatoes'), 'Tomato');
    expect(_top(builtins, 'strawberries'), 'Strawberries');
    expect(_top(builtins, 'chicken'), 'Chicken breast, cooked');
    expect(_top(builtins, 'rice'), 'White rice, cooked');
    expect(_top(builtins, 'cotage chese'), 'Cottage cheese 5%');
    // Half-typed words still find something.
    expect(_top(builtins, 'cott'), 'Cottage cheese 5%');
  });

  test('junk matches nothing', () {
    expect(builtins.rank('asdfgh'), isEmpty);
    expect(builtins.rank(''), isEmpty);
  });

  test('learned alias beats a better word score', () {
    final m = FoodMatcher(_builtins);
    final learned = builtinCandidateKey('cottage_3');
    final r = m.rank('cottage cheese 5%', learnedKey: learned);
    expect(r.first.candidate.key, learned);
    expect(r.first.learned, isTrue);
    expect(r.first.isConfident, isTrue);
  });

  test("the user's own food beats a built-in one with the same name", () {
    final mine = _own(1, 'Egg');
    final m = FoodMatcher([..._builtins, mine]);
    expect(m.rank('egg').first.candidate.key, mine.key);
  });

  test('favorites and recent foods get a small bonus', () {
    final a = _own(1, 'Oat bar', own: false);
    final b = _own(2, 'Oat bar', own: false, favorite: true);
    final c = _own(3, 'Oat bar', own: false, lastUsed: DateTime(2026));
    final r = FoodMatcher([a, c, b]).rank('oat bar');
    expect([for (final x in r) x.candidate.foodId], [2, 3, 1]);
  });

  test('brand words count', () {
    final tnuva = _own(7, 'Cottage cheese 5%', brand: 'Tnuva', own: false);
    final m = FoodMatcher([..._builtins, tnuva]);
    expect(m.rank('tnuva cottage 5%').first.candidate.key, 'food:7');
  });

  group('DescribeEngine', () {
    test('the example sentence', () {
      final e = DescribeEngine(_builtins, DescribeMemory.empty);
      final r = e.parse('5 spoons of cottage cheese 5% and 2 eggs for lunch');
      expect(r.suggestedMeal, Meal.lunch);
      expect(r.items, hasLength(2));
      final cottage = r.items[0];
      expect(cottage.match!.candidate.name, 'Cottage cheese 5%');
      expect(cottage.grams, 100);
      expect(cottage.gramsExplanation, '5 tbsp × 20 g');
      expect(cottage.macros!.kcal, closeTo(95, 1e-9));
      expect(cottage.needsLook, isFalse);
      final eggs = r.items[1];
      expect(eggs.match!.candidate.name, 'Egg');
      expect(eggs.grams, 100);
    });

    test('item keys stay stable while typing more', () {
      final e = DescribeEngine(_builtins, DescribeMemory.empty);
      final a = e.parse('2 eggs and ban');
      final b = e.parse('2 eggs and banana, coffee');
      expect(a.items.first.key, b.items.first.key);
      expect(b.items.map((i) => i.key).toSet(), hasLength(3));
      // The same phrase twice gets two keys.
      final twice = e.parse('egg, egg');
      expect(twice.items[0].key, isNot(twice.items[1].key));
    });

    test('unknown words and amounts without food', () {
      final e = DescribeEngine(_builtins, DescribeMemory.empty);
      final r = e.parse('qwzx and 200g');
      expect(r.items.single.match, isNull);
      expect(r.items.single.needsLook, isTrue);
      expect(r.items.single.macros, isNull);
      expect(r.unrecognized, ['200 g']);
    });

    test('keeps "coffee with milk" as one item', () {
      final e = DescribeEngine(_builtins, DescribeMemory.empty);
      final r = e.parse('coffee with milk');
      expect(r.items.single.match!.candidate.name, 'Coffee with milk (latte)');
    });

    test('uses memory for names and spoon sizes', () {
      final cottage3 = builtinCandidateKey('cottage_3');
      final memory = DescribeMemory.fromKeyValues({
        DescribeMemory.aliasEntry('cottage', cottage3)!.key: cottage3,
        DescribeMemory.gramsEntry(cottage3, MeasureUnit.tablespoon, 22)!.key:
            '22',
      });
      final e = DescribeEngine(_builtins, memory);
      final item = e.parse('5 spoons of cottage').items.single;
      expect(item.match!.candidate.key, cottage3);
      expect(item.grams, 110);
      expect(item.estimate!.confidence, WeightConfidence.exact);
      expect(item.gramsExplanation, '5 × your usual tbsp (22 g)');
    });

    test('search for the picker ranks all foods', () {
      final e = DescribeEngine(_builtins, DescribeMemory.empty);
      expect(e.search('bread').first.candidate.name, 'White bread');
      expect(e.search('bread').length, greaterThan(2));
    });
  });
}
