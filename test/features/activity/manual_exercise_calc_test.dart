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

    test('zero duration burns nothing', () {
      expect(estimateExerciseKcal(met: 8.0, weightKg: 80, durationMin: 0), 0);
    });
  });

  group('estimateGaitKcal', () {
    test('flat walk at 5 km/h matches the ACSM walking equation', () {
      // S = 83.33 m/min; VO2 = 3.5 + 8.333 = 11.833 ml/kg/min.
      // 80 kg, 60 min: 11.833 * 80 / 1000 * 5 * 60 = 284 kcal.
      expect(
        estimateGaitKcal(
          gait: Gait.walk,
          speedKmh: 5,
          inclinePct: 0,
          weightKg: 80,
          durationMin: 60,
        ),
        closeTo(284, 0.5),
      );
    });

    test('incline raises a walk a lot', () {
      // 10%: VO2 = 11.833 + 1.8 * 83.33 * 0.1 = 26.833 -> 644 kcal/h.
      expect(
        estimateGaitKcal(
          gait: Gait.walk,
          speedKmh: 5,
          inclinePct: 10,
          weightKg: 80,
          durationMin: 60,
        ),
        closeTo(644, 0.5),
      );
    });

    test('flat run at 10 km/h matches the ACSM running equation', () {
      // S = 166.67 m/min; VO2 = 3.5 + 33.33 = 36.83 -> 80 kg, 30 min: 442.
      expect(
        estimateGaitKcal(
          gait: Gait.run,
          speedKmh: 10,
          inclinePct: 0,
          weightKg: 80,
          durationMin: 30,
        ),
        closeTo(442, 0.5),
      );
    });
  });

  test('speed and distance convert through the duration', () {
    expect(speedFromDistance(2.5, 30), closeTo(5, 1e-9));
    expect(distanceFromSpeed(5.5, 30), closeTo(2.75, 1e-9));
  });

  test('every type is either MET-based, a walk/run, or Other', () {
    for (final t in commonExerciseTypes) {
      if (t.isOther) {
        expect(t.label, 'Other');
      } else if (t.gait == null) {
        expect(t.met, greaterThan(0));
      } else {
        expect(t.met, isNull);
      }
    }
    expect(commonExerciseTypes.where((t) => t.isOther), hasLength(1));
  });
}
