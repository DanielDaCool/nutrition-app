import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/label_parser.dart';

void main() {
  test('English per-100g label', () {
    final s = parseNutritionLabel('''
Nutrition Facts
Typical values per 100g
Energy 1850 kJ / 442 kcal
Fat 20.5 g
of which saturates 8 g
Carbohydrate 55 g
of which sugars 12 g
Fibre 3 g
Protein 7,5 g
Salt 1.1 g
''');
    expect(s.basis, ScannedBasis.per100g);
    expect(s.kcal, 442);
    expect(s.fatG, 20.5);
    expect(s.carbsG, 55);
    expect(s.proteinG, 7.5);
    expect(s.missing, isEmpty);
  });

  test('per-serving label with serving size', () {
    final s = parseNutritionLabel('''
Nutrition Facts
Serving size 30 g
Calories 120
Total Fat 4.5g
Total Carbohydrate 17g
Protein 3g
''');
    expect(s.basis, ScannedBasis.perServing);
    expect(s.servingGrams, 30);
    expect(s.fatG, 4.5);
    expect(s.carbsG, 17);
    expect(s.proteinG, 3);
    expect(s.kcal, 120);
  });

  test('two columns: takes the per-100g one', () {
    final s = parseNutritionLabel('''
Nutrition        Per 100 g      Per serving (30 g)
Energy    1500 kJ 360 kcal     450 kJ 108 kcal
Fat       10 g                 3 g
Carbohydrate 60 g              18 g
Protein   8 g                  2.4 g
''');
    expect(s.basis, ScannedBasis.per100g);
    expect(s.kcal, 360);
    expect(s.fatG, 10);
    expect(s.carbsG, 60);
    expect(s.proteinG, 8);
    expect(s.servingGrams, 30);
  });

  test('two columns with per-serving first: still per 100 g', () {
    final s = parseNutritionLabel('''
Per serving (40 g)   Per 100 g
Energy 200 kcal   500 kcal
Protein 4 g   10 g
Fat 8 g   20 g
Carbohydrate 24 g   60 g
''');
    expect(s.basis, ScannedBasis.per100g);
    expect(s.kcal, 500);
    expect(s.proteinG, 10);
    expect(s.fatG, 20);
    expect(s.carbsG, 60);
  });

  test('kJ only is converted to kcal', () {
    final s = parseNutritionLabel('Energy 1000 kJ\nProtein 1 g');
    expect(s.kcal, closeTo(239, 0.5));
  });

  test('Hebrew keywords and per-100g header', () {
    final s = parseNutritionLabel('''
ערכים תזונתיים ל-100 גרם
קלוריות 250 קק"ל
חלבונים 6 גרם
פחמימות 40 גרם
מתוכם סוכרים 10 גרם
שומנים 8 גרם
''');
    expect(s.basis, ScannedBasis.per100g);
    expect(s.kcal, 250);
    expect(s.proteinG, 6);
    expect(s.carbsG, 40);
    expect(s.fatG, 8);
  });

  test('value on the next line, and never from another nutrient', () {
    final s = parseNutritionLabel('''
Energy
250 kcal
Protein
Fat 9 g
''');
    expect(s.kcal, 250);
    expect(s.fatG, 9);
    expect(s.proteinG, isNull);
    expect(s.missing, ['protein', 'carbohydrates']);
  });

  test('trace amounts count as zero; junk gives an empty scan', () {
    expect(parseNutritionLabel('Fat <0.5 g').fatG, 0);
    expect(parseNutritionLabel('hello world').isEmpty, isTrue);
    expect(parseNutritionLabel('').isEmpty, isTrue);
  });
}
