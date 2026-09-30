import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/describe/meal_text_parser.dart';

typedef _P = (double quantity, MeasureUnit? unit, String food);

const _tbsp = MeasureUnit.tablespoon;
const _tsp = MeasureUnit.teaspoon;
const _g = MeasureUnit.gram;
const _pc = MeasureUnit.piece;
const _cup = MeasureUnit.cup;

void main() {
  // text -> expected phrases (quantity, unit, food words)
  final cases = <String, List<_P>>{
    '5 spoons of cottage cheese 5%': [(5, _tbsp, 'cottage cheese 5%')],
    '2 eggs and a slice of bread with hummus': [
      (2, _pc, 'eggs'),
      (1, MeasureUnit.slice, 'bread'),
      (1, null, 'hummus'),
    ],
    'chicken breast 200g, 1 cup rice': [
      (200, _g, 'chicken breast'),
      (1, _cup, 'rice'),
    ],
    'rice 1 cup': [(1, _cup, 'rice')],
    'chicken breast 200 g': [(200, _g, 'chicken breast')],
    '200gr chicken': [(200, _g, 'chicken')],
    '0.5kg yogurt': [(0.5, MeasureUnit.kilogram, 'yogurt')],
    '250ml milk 3%': [(250, MeasureUnit.milliliter, 'milk 3%')],
    '1/2 avocado': [(0.5, _pc, 'avocado')],
    '1 1/2 cups of milk': [(1.5, _cup, 'milk')],
    '½ avocado': [(0.5, _pc, 'avocado')],
    '1½ pita': [(1.5, _pc, 'pita')],
    '¾ cup oats': [(0.75, _cup, 'oats')],
    'half an avocado': [(0.5, _pc, 'avocado')],
    'half a pita': [(0.5, _pc, 'pita')],
    'a couple of eggs': [(2, _pc, 'eggs')],
    'a few dates': [(3, _pc, 'dates')],
    'a quarter of a pizza': [(0.25, _pc, 'pizza')],
    'one and a half cups oats': [(1.5, _cup, 'oats')],
    'three slices of bread': [(3, MeasureUnit.slice, 'bread')],
    'a banana': [(1, _pc, 'banana')],
    'an apple': [(1, _pc, 'apple')],
    'egg x2': [(2, _pc, 'egg')],
    '2x eggs': [(2, _pc, 'eggs')],
    '1,5 cups rice': [(1.5, _cup, 'rice')],
    '1.5 cups rice': [(1.5, _cup, 'rice')],
    'eggs 2': [(2, _pc, 'eggs')],
    'rice 150': [(150, _g, 'rice')],
    'cottage 5 %': [(1, null, 'cottage 5%')],
    'cottage 5 percent': [(1, null, 'cottage 5%')],
    'some rice': [(1, null, 'rice')],
    'i had 2 eggs': [(2, _pc, 'eggs')],
    'about 200g chicken': [(200, _g, 'chicken')],
    'a bit of tahini': [(1, null, 'tahini')],
    'a cup of coffee': [(1, _cup, 'coffee')],
    'glass of milk': [(1, MeasureUnit.glass, 'milk')],
    '2 big spoons of hummus + 3 small spoons honey': [
      (2, _tbsp, 'hummus'),
      (3, _tsp, 'honey'),
    ],
    '1 tsp sugar; 2 tbsp oil & a handful of almonds': [
      (1, _tsp, 'sugar'),
      (2, _tbsp, 'oil'),
      (1, MeasureUnit.handful, 'almonds'),
    ],
    'coffee plus cookie\n2 dates': [
      (1, null, 'coffee'),
      (1, null, 'cookie'),
      (2, _pc, 'dates'),
    ],
    'a scoop of whey, a can of tuna': [
      (1, MeasureUnit.scoop, 'whey'),
      (1, MeasureUnit.can, 'tuna'),
    ],
    '2 pcs schnitzel. bowl of salad': [
      (2, _pc, 'schnitzel'),
      (1, MeasureUnit.bowl, 'salad'),
    ],
    'A Plate Of Pasta': [(1, MeasureUnit.plate, 'pasta')],
    'one serving of granola': [(1, MeasureUnit.serving, 'granola')],
    'tahini 2 spoons': [(2, _tbsp, 'tahini')],
    // Several foods with no comma or "and" between them.
    '2 bananas 1 apple': [(2, _pc, 'bananas'), (1, _pc, 'apple')],
    'eggs 3 toast 2': [(3, _pc, 'eggs'), (2, _pc, 'toast')],
    '2 eggs 1 slice bread 1 tbsp hummus': [
      (2, _pc, 'eggs'),
      (1, MeasureUnit.slice, 'bread'),
      (1, _tbsp, 'hummus'),
    ],
    'rice 1 cup chicken 200g': [(1, _cup, 'rice'), (200, _g, 'chicken')],
    '3 eggs 200g cottage 5% 1/2 avocado': [
      (3, _pc, 'eggs'),
      (200, _g, 'cottage 5%'),
      (0.5, _pc, 'avocado'),
    ],
    'cottage cheese 5% 2 eggs': [
      (1, null, 'cottage cheese 5%'),
      (2, _pc, 'eggs'),
    ],
    '2 eggs, bread 2 pita 1': [
      (2, _pc, 'eggs'),
      (2, _pc, 'bread'),
      (1, _pc, 'pita'),
    ],
    // A trailing number with no food after it stays with its food.
    '1 cup milk 3': [(1, _cup, 'milk 3')],
    'chicken breast 2 pieces': [(2, _pc, 'chicken breast')],
  };

  for (final MapEntry(key: text, value: expected) in cases.entries) {
    test('parses "${text.replaceAll('\n', r'\n')}"', () {
      final phrases = parseMealText(text).phrases;
      expect([
        for (final p in phrases) (p.quantity, p.unit, p.foodText),
      ], expected);
    });
  }

  test('amounts that were not said are marked as defaults', () {
    final p = parseMealText('hummus and 2 eggs').phrases;
    expect(p[0].quantityGiven, isFalse);
    expect(p[1].quantityGiven, isTrue);
  });

  test('meal words are dropped, not read as food', () {
    final cases = {
      '2 eggs for breakfast': 'breakfast',
      'at lunch i had rice': 'lunch',
      'pasta for dinner': 'dinner',
      'supper: soup': 'supper',
      'apple as a snack': 'snack',
    };
    cases.forEach((text, word) {
      final r = parseMealText(text);
      expect(r.phrases, isNotEmpty, reason: text);
      for (final p in r.phrases) {
        expect(p.foodText, isNot(contains(word)), reason: text);
      }
    });
  });

  test('keeps named foods with "with" together', () {
    final r = parseMealText(
      'coffee with milk and a cookie',
      keepTogether: ['coffee with milk'],
    );
    expect(
      [for (final p in r.phrases) p.foodText],
      ['coffee with milk', 'cookie'],
    );
  });

  test('junk and filler-only text', () {
    expect(parseMealText('').phrases, isEmpty);
    expect(parseMealText(' , and ; with ').phrases, isEmpty);
    expect(parseMealText('i had').phrases, isEmpty);
    final junk = parseMealText('asdkjh').phrases.single;
    expect(junk.foodText, 'asdkjh');
    expect(junk.quantityGiven, isFalse);
    final noFood = parseMealText('200g').phrases.single;
    expect(noFood.foodText, isEmpty);
    expect(noFood.unit, MeasureUnit.gram);
  });

  test('singularize', () {
    const words = {
      'eggs': 'egg',
      'tomatoes': 'tomato',
      'slices': 'slice',
      'berries': 'berry',
      'glasses': 'glass',
      'peaches': 'peach',
      'hummus': 'hummus',
      'couscous': 'couscous',
      'oats': 'oat',
      'egg': 'egg',
    };
    words.forEach((plural, single) => expect(singularize(plural), single));
  });
}
