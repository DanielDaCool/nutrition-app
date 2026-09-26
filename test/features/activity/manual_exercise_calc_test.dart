import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/activity/manual_exercise_calc.dart';

void main() {
  group('estimateExerciseKcal', () {
    test('MET x weight x hours', () {
      // 8 MET, 80 kg, 30 min = 8 * 80 * 0.5 = 320 kcal.
      expect(
        estimateExerciseKcal(met: 8.0, weightKg: 80, durationMin: 30),
        closeTo(320, 0.001),
      );
    });

    test('scales linearly with duration', () {
      final oneHour = estimateExerciseKcal(
        met: 6.0,
        weightKg: 70,
        durationMin: 60,
      );
      final twoHours = estimateExerciseKcal(
        met: 6.0,
        weightKg: 70,
        durationMin: 120,
      );
      expect(twoHours, closeTo(oneHour * 2, 0.001));
    });

    test('zero duration burns nothing', () {
      expect(
        estimateExerciseKcal(met: 8.0, weightKg: 80, durationMin: 0),
        0,
      );
    });
  });

  group('commonExerciseTypes', () {
    test('every entry but Other has a positive MET', () {
      for (final t in commonExerciseTypes) {
        if (t.label == 'Other') {
          expect(t.met, isNull);
        } else {
          expect(t.met, isNotNull);
          expect(t.met, greaterThan(0));
        }
      }
    });
  });
}
