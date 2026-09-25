import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/describe/food_text.dart';
import 'package:nutrition_app/features/food/describe/meal_text_parser.dart';
import 'package:nutrition_app/features/food/describe/unit_weights.dart';

const _cottage = FoodWeightInfo(name: 'Cottage cheese 5%');
const _egg = FoodWeightInfo(
  name: 'Egg',
  servingName: 'large egg',
  servingGrams: 50,
  servingIsTypical: true,
);
const _labelBread = FoodWeightInfo(
  name: 'Angel bread',
  servingName: '1 slice (32 g)',
  servingGrams: 32,
);
const _mystery = FoodWeightInfo(name: 'Mystery stew');

GramsEstimate _est(
  double q,
  MeasureUnit? unit,
  FoodWeightInfo food, {
  double? learned,
}) => estimateGrams(
  quantity: q,
  unit: unit,
  food: food,
  learnedGramsPerUnit: learned,
);

void main() {
  test('grams and kilograms are exact', () {
    final g = _est(200, MeasureUnit.gram, _mystery);
    expect(g.grams, 200);
    expect(g.confidence, WeightConfidence.exact);
    expect(g.explanation, isNull);
    final kg = _est(0.5, MeasureUnit.kilogram, _mystery);
    expect(kg.grams, 500);
    expect(kg.explanation, '0.5 kg = 500 g');
  });

  test('ml is 1:1 except oil and honey', () {
    expect(_est(250, MeasureUnit.milliliter, _mystery).grams, 250);
    expect(_est(1, MeasureUnit.liter, _mystery).grams, 1000);
    final oil = _est(
      15,
      MeasureUnit.milliliter,
      const FoodWeightInfo(name: 'Olive oil'),
    );
    expect(oil.grams, closeTo(13.8, 1e-9));
    expect(oil.explanation, '15 ml × 0.92 g/ml');
    final honey = _est(
      10,
      MeasureUnit.milliliter,
      const FoodWeightInfo(name: 'Honey'),
    );
    expect(honey.grams, closeTo(14, 1e-9));
  });

  test('per-food table: 5 tbsp cottage = 100 g', () {
    final e = _est(5, MeasureUnit.tablespoon, _cottage);
    expect(e.grams, 100);
    expect(e.confidence, WeightConfidence.typical);
    expect(e.explanation, '5 tbsp × 20 g');
    expect(
      _est(
        1,
        MeasureUnit.cup,
        const FoodWeightInfo(name: 'Rice, cooked'),
      ).explanation,
      '1 cup ≈ 160 g',
    );
    expect(
      _est(2, MeasureUnit.slice, const FoodWeightInfo(name: 'Bread')).grams,
      60,
    );
    // Specific entries win over general ones.
    expect(
      _est(1, MeasureUnit.piece, const FoodWeightInfo(name: 'Egg white')).grams,
      33,
    );
    expect(
      _est(
        1,
        MeasureUnit.tablespoon,
        const FoodWeightInfo(name: 'Olive oil'),
      ).grams,
      14,
    );
  });

  test('aliases find the table entry', () {
    const food = FoodWeightInfo(name: 'Tnuva 5', aliases: ['cottage']);
    expect(_est(3, MeasureUnit.tablespoon, food).grams, 60);
  });

  test('built-in serving is typical and named', () {
    final e = _est(2, MeasureUnit.piece, _egg);
    expect(e.grams, 100);
    expect(e.confidence, WeightConfidence.typical);
    expect(e.explanation, '2 × large egg (50 g)');
    expect(_est(1, MeasureUnit.piece, _egg).explanation, '1 large egg ≈ 50 g');
  });

  test('label serving is exact and fits a matching unit word', () {
    final e = _est(2, MeasureUnit.slice, _labelBread);
    expect(e.grams, 64);
    expect(e.confidence, WeightConfidence.exact);
    expect(e.explanation, '2 × serving on the label (32 g)');
    // A cup isn't this food's serving: table/generic instead.
    expect(_est(1, MeasureUnit.cup, _labelBread).grams, isNot(32));
  });

  test('learned grams beat everything else', () {
    final e = _est(5, MeasureUnit.tablespoon, _cottage, learned: 22);
    expect(e.grams, 110);
    expect(e.confidence, WeightConfidence.exact);
    expect(e.explanation, '5 × your usual tbsp (22 g)');
    expect(
      _est(1, null, _cottage, learned: 40).explanation,
      'your usual portion (40 g)',
    );
  });

  test('no amount: serving, then one piece, then 100 g guess', () {
    expect(_est(1, null, _egg).grams, 50);
    final banana = _est(1, null, const FoodWeightInfo(name: 'Banana'));
    expect(banana.grams, 120);
    expect(banana.explanation, '1 piece ≈ 120 g');
    expect(
      _est(1, MeasureUnit.serving, const FoodWeightInfo(name: 'Banana')).grams,
      120,
    );
    final rice = _est(1, null, const FoodWeightInfo(name: 'Rice'));
    expect(rice.explanation, '1 serving ≈ 160 g');
    final unknown = _est(1, null, _mystery);
    expect(unknown.grams, 100);
    expect(unknown.confidence, WeightConfidence.guess);
  });

  test('generic fallbacks are guesses', () {
    final e = _est(2, MeasureUnit.tablespoon, _mystery);
    expect(e.grams, 30);
    expect(e.confidence, WeightConfidence.guess);
    expect(e.explanation, '2 tbsp × ~15 g (rough guess)');
    expect(_est(1, MeasureUnit.cup, _mystery).grams, 200);
    expect(_est(1, MeasureUnit.glass, _mystery).grams, 240);
    expect(_est(1, MeasureUnit.piece, _mystery).grams, 100);
  });

  test('sensible units include grams, serving and table units', () {
    final units = sensibleUnits(_egg);
    expect(units.first, MeasureUnit.gram);
    expect(units, contains(MeasureUnit.serving));
    expect(units, contains(MeasureUnit.piece));
    expect(
      sensibleUnits(
        const FoodWeightInfo(name: 'Whey protein'),
        current: MeasureUnit.handful,
      ),
      containsAll([MeasureUnit.scoop, MeasureUnit.handful]),
    );
  });

  test('food tokens normalize spelling, plurals and percentages', () {
    expect(foodTokens('Cottage Cheese, 5%'), ['cottage', 'cheese', '5%']);
    expect(foodTokens('Houmous'), ['hummus']);
    expect(foodTokens('pitta'), ['pita']);
    expect(foodTokens('Greek yoghurt'), ['greek', 'yogurt']);
    expect(foodTokens('tomatoes and eggs'), ['tomato', 'egg']);
    expect(foodTokens('wholewheat bread'), ['whole', 'wheat', 'bread']);
  });
}
