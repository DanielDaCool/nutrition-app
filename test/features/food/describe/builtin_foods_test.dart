import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/describe/builtin_foods.dart';
import 'package:nutrition_app/features/food/nutrition_math.dart';

void main() {
  test('there are about a hundred foods with unique keys', () {
    expect(builtinFoods.length, greaterThanOrEqualTo(100));
    final keys = {for (final f in builtinFoods) f.key};
    expect(keys.length, builtinFoods.length);
    expect(builtinByKey('cottage_5')!.name, 'Cottage cheese 5%');
    expect(builtinByKey('nope'), isNull);
  });

  for (final f in builtinFoods) {
    test('${f.key}: kcal agree with 4P + 4C + 9F', () {
      final implied = kcalFromMacros(f.proteinG, f.fatG, f.carbsG);
      final diff = (f.kcal - implied).abs();
      // ~10 %: fibre and rounding explain the rest; tiny foods get 10 kcal.
      expect(
        diff <= 0.10 * f.kcal || diff <= 10,
        isTrue,
        reason: '${f.name}: ${f.kcal} kcal vs ${implied.round()} implied',
      );
      expect(f.proteinG + f.fatG + f.carbsG, lessThanOrEqualTo(100.5));
      for (final v in [f.kcal, f.proteinG, f.fatG, f.carbsG]) {
        expect(v, greaterThanOrEqualTo(0));
      }
      if (f.servingGrams != null) {
        expect(f.servingGrams, greaterThan(0));
        expect(f.servingName, isNotNull);
      }
      expect(f.aliases, isNotEmpty);
    });
  }
}
