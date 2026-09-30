import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/nutrition_math.dart';

void main() {
  const per100 = Macros(kcal: 200, proteinG: 10, fatG: 5, carbsG: 30);

  test('macrosForGrams scales per-100 g values', () {
    final m = macrosForGrams(per100, 150);
    expect(m.kcal, closeTo(300, 1e-9));
    expect(m.proteinG, closeTo(15, 1e-9));
    expect(m.fatG, closeTo(7.5, 1e-9));
    expect(m.carbsG, closeTo(45, 1e-9));
  });

  test('per100gFromServing converts label values', () {
    const perServing = Macros(kcal: 120, proteinG: 6, fatG: 3, carbsG: 15);
    final m = per100gFromServing(perServing, 60);
    expect(m.kcal, closeTo(200, 1e-9));
    expect(m.proteinG, closeTo(10, 1e-9));
    expect(() => per100gFromServing(perServing, 0), throwsArgumentError);
  });

  test('rescaleSnapshot keeps the snapshot ratio', () {
    const snap = Macros(kcal: 90, proteinG: 3, fatG: 1, carbsG: 12);
    final m = rescaleSnapshot(snap, 30, 45);
    expect(m.kcal, closeTo(135, 1e-9));
    expect(m.carbsG, closeTo(18, 1e-9));
  });

  group('labelWarning', () {
    test('null for a consistent label', () {
      // 4*10 + 9*5 + 4*30 = 205
      expect(labelWarning(per100), isNull);
    });

    test('warns when kcal is far from the macros', () {
      const bad = Macros(kcal: 50, proteinG: 10, fatG: 5, carbsG: 30);
      expect(labelWarning(bad), contains("don't match"));
    });

    test('warns when macros exceed 100 g', () {
      const bad = Macros(kcal: 800, proteinG: 50, fatG: 40, carbsG: 30);
      expect(labelWarning(bad), contains('more than 100 g'));
    });

    test('small gaps (fibre, rounding) are fine', () {
      const ok = Macros(kcal: 250, proteinG: 8, fatG: 2, carbsG: 45);
      expect(labelWarning(ok), isNull); // implied 230
    });
  });

  group('resolveKcal', () {
    test('uses the kcal field when it agrees with kJ', () {
      expect(resolveKcal(kcalField: 282, kjField: 1180), 282);
    });
    test('falls back to kJ when kcal is missing', () {
      expect(resolveKcal(kcalField: null, kjField: 1046), closeTo(250, 1));
    });
    test('falls back to kcal when kJ is missing', () {
      expect(resolveKcal(kcalField: 500, kjField: null), 500);
    });
    test('null when both are missing', () {
      expect(resolveKcal(kcalField: null, kjField: null), isNull);
    });
    test('small rounding gaps between the two fields are kept as the '
        'kcal field', () {
      // 1180 kJ / 4.184 = 282.02; a label rounded to 280 kcal is fine.
      expect(resolveKcal(kcalField: 280, kjField: 1180), 280);
    });
    test('corrects a kcal field that actually holds the kJ number', () {
      // A contributor typed the kJ figure (2092) into the kcal box; the kJ
      // field itself is right, so 2092 kJ / 4.184 = 500 kcal is trusted.
      expect(resolveKcal(kcalField: 2092, kjField: 2092), closeTo(500, 1e-6));
    });
  });

  test('parseAmount accepts comma decimals and rejects junk', () {
    expect(parseAmount('12,5'), 12.5);
    expect(parseAmount(' 30 '), 30);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
  });

  group('parseServingGrams', () {
    test('uses serving_quantity with unit g', () {
      expect(parseServingGrams(servingQuantity: '50', unit: 'g'), 50);
    });
    test('reads grams from free text', () {
      expect(parseServingGrams(servingSize: '1 slice (30 g)'), 30);
      expect(parseServingGrams(servingSize: '2 פרוסות (60 גרם)'), 60);
      expect(parseServingGrams(servingSize: '25g'), 25);
    });
    test('ignores ml, kg and unknown units', () {
      expect(
        parseServingGrams(
          servingSize: '150 ml',
          servingQuantity: 150,
          unit: 'ml',
        ),
        isNull,
      );
      expect(parseServingGrams(servingSize: '250ml'), isNull);
      expect(parseServingGrams(servingSize: '1 kg'), isNull);
      expect(parseServingGrams(servingSize: '1 cup'), isNull);
      expect(parseServingGrams(servingQuantity: 40), isNull);
    });
    test('Hebrew words starting with ג are not grams', () {
      expect(parseServingGrams(servingSize: '1 גביע'), isNull);
      expect(parseServingGrams(servingSize: '2 גלילים'), isNull);
      expect(parseServingGrams(servingSize: '1גביע'), isNull);
      // The unit still needs the text to say grams.
      expect(
        parseServingGrams(servingSize: '1 גביע', servingQuantity: 1),
        isNull,
      );
      // Grams in Hebrew still work, spelled out or abbreviated.
      expect(parseServingGrams(servingSize: '1 גביע (200 גרם)'), 200);
      expect(parseServingGrams(servingSize: '1 גביע (150 ג)'), 150);
      expect(parseServingGrams(servingSize: '30ג'), 30);
      expect(parseServingGrams(servingSize: '2 גלילים (40 ג\')'), 40);
    });
  });

  test('evenServings: whole or half servings only', () {
    expect(evenServings(300, 150), 2);
    expect(evenServings(75, 150), 0.5);
    expect(evenServings(130, 150), isNull);
    expect(evenServings(100, null), isNull);
    expect(evenServings(100, 0), isNull);
  });
}
