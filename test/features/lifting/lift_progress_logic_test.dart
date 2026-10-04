import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/lift_progress_logic.dart';

var _nextId = 1;

/// A session on [dayKey] from `(weightKg, reps)` pairs.
LiftSession session(String dayKey, List<(double, int)> sets) => LiftSession(
  dayKey: dayKey,
  sets: [
    for (final (weightKg, reps) in sets)
      LiftSet(id: _nextId++, reps: reps, weightKg: weightKg),
  ],
);

LiftExercise exercise(int id, String name) => LiftExercise(
  id: id,
  name: name,
  muscleGroup: MuscleGroup.chest,
  isBodyweight: false,
);

void main() {
  final bench = [
    session('2026-09-01', [(60, 7), (60, 4)]),
    session('2026-09-08', [(60, 8), (62.5, 5), (55, 10)]),
    session('2026-09-15', [(65, 6)]),
  ];

  group('liftProgressPoints', () {
    test('top weight is the heaviest set of each day', () {
      final points = liftProgressPoints(bench, LiftMetric.topWeight);
      expect(points.map((p) => p.dayKey), [
        '2026-09-01',
        '2026-09-08',
        '2026-09-15',
      ]);
      expect(points.map((p) => p.value), [60, 62.5, 65]);
      expect(points[1].session, same(bench[1]));
    });

    test('best reps is the most reps in a single set of each day', () {
      final points = liftProgressPoints(bench, LiftMetric.bestReps);
      expect(points.map((p) => p.value), [7, 10, 6]);
    });

    test('no sessions give no points; a session without sets is skipped', () {
      expect(liftProgressPoints(const [], LiftMetric.topWeight), isEmpty);
      final points = liftProgressPoints([
        const LiftSession(dayKey: '2026-09-01', sets: []),
        session('2026-09-02', [(40, 5)]),
      ], LiftMetric.bestReps);
      expect(points.single.dayKey, '2026-09-02');
    });
  });

  group('defaultLiftMetric', () {
    test('weighted exercise: top weight', () {
      expect(defaultLiftMetric(bench), LiftMetric.topWeight);
    });

    test('bodyweight without extra weight: best reps', () {
      final dips = [
        session('2026-09-01', [(0, 8), (0, 6)]),
        session('2026-09-08', [(0, 10)]),
      ];
      expect(defaultLiftMetric(dips), LiftMetric.bestReps);
    });

    test('bodyweight with extra weight on any set: top weight', () {
      final dips = [
        session('2026-09-01', [(0, 8), (0, 6)]),
        session('2026-09-08', [(0, 10), (20, 5)]),
      ];
      expect(defaultLiftMetric(dips), LiftMetric.topWeight);
    });

    test('no sessions: top weight', () {
      expect(defaultLiftMetric(const []), LiftMetric.topWeight);
    });
  });

  group('liftProgressHeadline', () {
    String? headline(
      List<LiftSession> sessions,
      LiftMetric metric, {
      bool isBodyweight = false,
    }) => liftProgressHeadline(
      liftProgressPoints(sessions, metric),
      metric,
      isBodyweight: isBodyweight,
    );

    test('no points: null', () {
      expect(headline(const [], LiftMetric.topWeight), isNull);
      expect(headline(const [], LiftMetric.bestReps), isNull);
    });

    test('single point: just the value', () {
      expect(headline([bench.first], LiftMetric.topWeight), '60 kg');
      expect(headline([bench.first], LiftMetric.bestReps), '7 reps');
    });

    test('first vs. last point, increasing', () {
      expect(headline(bench, LiftMetric.topWeight), '60 kg → 65 kg (+5 kg)');
      expect(
        headline(bench.sublist(0, 2), LiftMetric.topWeight),
        '60 kg → 62.5 kg (+2.5 kg)',
      );
      expect(
        headline(bench.sublist(0, 2), LiftMetric.bestReps),
        '7 → 10 reps (+3)',
      );
    });

    test('decreasing trend', () {
      final weaker = bench.reversed.toList();
      expect(headline(weaker, LiftMetric.topWeight), '65 kg → 60 kg (-5 kg)');
      expect(headline(bench, LiftMetric.bestReps), '7 → 6 reps (-1)');
    });

    test('unchanged', () {
      final same = [bench.first, bench.first];
      expect(
        headline(same, LiftMetric.topWeight),
        '60 kg → 60 kg (no change)',
      );
      expect(headline(same, LiftMetric.bestReps), '7 → 7 reps (no change)');
    });

    test('bodyweight exercises show the extra weight as "BW + x kg"', () {
      final dips = [
        session('2026-09-01', [(0, 8)]),
        session('2026-09-08', [(20, 5)]),
      ];
      expect(
        headline(dips, LiftMetric.topWeight, isBodyweight: true),
        'BW → BW + 20 kg (+20 kg)',
      );
      expect(
        headline([dips.last], LiftMetric.topWeight, isBodyweight: true),
        'BW + 20 kg',
      );
      expect(
        headline(dips, LiftMetric.bestReps, isBodyweight: true),
        '8 → 5 reps (-3)',
      );
    });
  });

  group('resolveLiftExercise', () {
    final exercises = [exercise(3, 'Bench press'), exercise(1, 'Squat')];

    test('picks the selected one, else the first', () {
      expect(resolveLiftExercise(exercises, 1)!.name, 'Squat');
      expect(resolveLiftExercise(exercises, null)!.name, 'Bench press');
      expect(resolveLiftExercise(exercises, 99)!.name, 'Bench press');
    });

    test('null without exercises', () {
      expect(resolveLiftExercise(const [], 1), isNull);
    });
  });

  group('liftProgressAxis', () {
    test('weights get room around the values and do not start at 0', () {
      final axis = liftProgressAxis([60, 62.5, 65], LiftMetric.topWeight);
      expect(axis, (min: 57.5, max: 67.5, interval: 2.5));
    });

    test('a single weight still gets a visible range', () {
      final axis = liftProgressAxis([60], LiftMetric.topWeight);
      expect(axis, (min: 57.5, max: 62.5, interval: 2.5));
    });

    test('a wide weight range uses bigger steps', () {
      final axis = liftProgressAxis([40, 100], LiftMetric.topWeight);
      expect(axis, (min: 20.0, max: 120.0, interval: 20.0));
    });

    test('never below zero', () {
      expect(liftProgressAxis([0], LiftMetric.topWeight).min, 0);
      expect(liftProgressAxis([0, 1], LiftMetric.bestReps).min, 0);
    });

    test('reps use whole-number steps', () {
      expect(liftProgressAxis([8, 10], LiftMetric.bestReps), (
        min: 7.0,
        max: 11.0,
        interval: 1.0,
      ));
      expect(liftProgressAxis([8], LiftMetric.bestReps), (
        min: 7.0,
        max: 9.0,
        interval: 1.0,
      ));
      expect(liftProgressAxis([5, 20], LiftMetric.bestReps), (
        min: 0.0,
        max: 25.0,
        interval: 5.0,
      ));
    });
  });

  group('wrapLiftSets', () {
    test('short text stays on one line', () {
      expect(wrapLiftSets('60 kg × 7 · 60 kg × 4'), '60 kg × 7 · 60 kg × 4');
    });

    test('long text breaks between sets only', () {
      expect(
        wrapLiftSets('60 kg × 7 · 60 kg × 4 · 60 kg × 4 · 55 kg × 9'),
        '60 kg × 7 · 60 kg × 4\n60 kg × 4 · 55 kg × 9',
      );
      expect(
        wrapLiftSets('BW + 20 kg × 6 · BW + 20 kg × 5', maxChars: 20),
        'BW + 20 kg × 6\nBW + 20 kg × 5',
      );
    });
  });
}
