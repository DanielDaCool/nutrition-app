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

  // Text read with an OCR engine from rendered labels (rows merged).
  group('OCR-style layouts', () {
    test('US label, label and number on separate lines', () {
      final s = parseNutritionLabel('''
Nutrition Facts
Serving size 2/3 cup (55g)
Calories
230
Total Fat
8g
Saturated Fat
1g
Total Carbohydrate
37g
Dietary Fiber
4g
Total Sugars
12g
Protein
3g''');
      expect(s.basis, ScannedBasis.perServing);
      expect([s.kcal, s.fatG, s.carbsG, s.proteinG], [230, 8, 37, 3]);
      expect(s.servingGrams, 55);
    });

    test('EU two-column table, kJ and kcal on different lines', () {
      final s = parseNutritionLabel('''
Nutrition information
Typical values per 100 g per 30 g servin
Energy 1580 kj 474 kJ
378 kcal 113 kcal
Fat 12 g 3.6 g
of whichsaturates 2.1 g 0.6 g
Carbohydrate 58 g 17 g
of which sugars 6.5 g 1.9 g
Protein 9.4 g 2.8 g''');
      expect(s.basis, ScannedBasis.per100g);
      expect([s.kcal, s.fatG, s.carbsG, s.proteinG], [378, 12, 58, 9.4]);
      expect(s.servingGrams, 30);
    });

    test('two-column table split into one column per line reads nothing', () {
      // Which number belongs to which column can't be told: better empty
      // than the serving column's numbers shown as per 100 g.
      final s = parseNutritionLabel('''
Typical values
per 100 g
per 30 g servin
Energy
1580 kj
474 kJ
378 kcal
113 kcal
12 g
Fat
3.6 g
Protein
2.8 g''');
      expect(s.fatG, isNull);
      expect(s.proteinG, isNull);
      expect(s.kcal, isNull);
    });

    test('single column, per 100 g misread, leaves the basis unknown', () {
      final s = parseNutritionLabel('''
Average values per 1o0 g
Energy
1850kJ/442kcal
Fat
20.5 g
Protein
7,5 g''');
      expect(s.basis, isNull);
      expect([s.kcal, s.fatG, s.proteinG], [442, 20.5, 7.5]);
    });

    test('a serving-size line on a per-100 g label is not a second column', () {
      final s = parseNutritionLabel('''
Nutrition per 100 g
Serving size 30 g
Energy 400 kcal
Fat 10 g
Carbohydrate 60 g
Protein 8 g''');
      expect(s.basis, ScannedBasis.per100g);
      expect([s.kcal, s.fatG, s.carbsG, s.proteinG], [400, 10, 60, 8]);
      expect(s.servingGrams, 30);
    });

    test('bilingual label with garbled Hebrew still reads the English', () {
      final s = parseNutritionLabel('''
Per100 g/na100-7
Energy/wanxy 250 kcal
Protein/7n 6 g
Carbohydrate /nin'nno 40 g
Fat/Dniy 8 g''');
      expect([s.kcal, s.proteinG, s.carbsG, s.fatG], [250, 6, 40, 8]);
    });
  });

  // Text as ML Kit's Latin recognizer returned it for real label photos
  // (Open Food Facts nutrition-table images, read on an Android emulator).
  group('real ML Kit output', () {
    test(
      'names in one block, per-100 g and per-slice values in two blocks',
      () {
        final s = parseNutritionLabel('''
R
Typical Values
Energy
Fat
-of which saturates
Carbohydrate
-of which sugars
Fibre
Protein
Salt
Typical Values
Magnesium
Iron
NUTRITIONAL INFORMATION
Zinc
Per 100g
1475 kJ
349 kcal
0.9g
0.2g
68g
2.6g
14g
11g
0.93g
Per 100g
96.2mg
2.8mg
2.1mg
Per Slice (10.5g)
155kJ
37 kcal
0.1g
0.02g
''');
        expect(s.basis, ScannedBasis.per100g);
        expect([s.kcal, s.fatG, s.carbsG, s.proteinG], [349, 0.9, 68, 11]);
      },
    );

    test('a reference-intake footnote is not the energy', () {
      final s = parseNutritionLabel('''
Hranilna vrednost
Energijska vrednost/
Maščobe/Grăsimi
RI (reference intake) =
osebo (8400 kJ/2000 kcal
o/100g
244 KJ/
58 kcal
2,0 g
''');
      expect(s.kcal, isNot(2000));
    });

    test(
      'numbers before the name on a line belong to the previous nutrient',
      () {
        final s = parseNutritionLabel('''
Nutrition Facts Serv Sze:1 Tbsp (21g)
Servings about 32, Amount Per Serving:
Calories 60, Total Fat 0g (0% DV), Sodium
Omg (0% DV Total Carb i7g(6% DV), Sugars
17g (34% DV), Protein Dg
''');
        expect(s.basis, ScannedBasis.perServing);
        expect(s.servingGrams, 21);
        expect(s.kcal, 60);
        expect(s.proteinG, isNull);
      },
    );

    test('a misread leading zero and a "per 100 g" header are not values', () {
      expect(parseNutritionLabel('Energy 21 24J/S08kcal').kcal, isNull);
      final s = parseNutritionLabel('''
Valores energéticos y nutricionales
Valor energético: 2143kI514 kcal
Grasas:
medios por 100 g
Proteínas:
''');
      expect(s.kcal, 514);
      expect(s.fatG, isNull);
    });

    test('typos in nutrient names still match, similar words do not', () {
      final s = parseNutritionLabel(
        'Enerqy 400 kcal\nFat 12 g\nNutrition Facts 5 g',
      );
      expect(s.kcal, 400);
      expect(s.fatG, 12);
    });
  });
}
