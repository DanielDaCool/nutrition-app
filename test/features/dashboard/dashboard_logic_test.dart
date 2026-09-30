import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/dashboard/dashboard_logic.dart';

DayIntake day(String key, double kcal, {bool logged = true}) => DayIntake(
  dayKey: key,
  total: Macros(kcal: kcal, proteinG: 0, fatG: 0, carbsG: 0),
  byMeal: const {},
  fullyLogged: logged,
);

DayActivity act(String key, int? steps, {int workouts = 0}) => DayActivity(
  dayKey: key,
  steps: steps,
  workouts: [
    for (var i = 0; i < workouts; i++)
      WorkoutSummary(
        id: '$key-$i',
        title: 'Lift',
        start: DateTime(2026, 9, 1, 18),
        end: DateTime(2026, 9, 1, 19),
      ),
  ],
);

void main() {
  test('weekStartOf returns the Monday', () {
    expect(weekStartOf('2026-09-21'), '2026-09-21'); // Monday
    expect(weekStartOf('2026-09-25'), '2026-09-21'); // Friday
    expect(weekStartOf('2026-09-27'), '2026-09-21'); // Sunday
    expect(weekStartOf('2026-09-28'), '2026-09-28');
  });

  test('targetOn picks the newest effectiveFrom on or before the day', () {
    const targets = [
      TargetPoint(
        effectiveFrom: '2026-09-01',
        kcal: 2200,
        maintenanceKcal: 2700,
      ),
      TargetPoint(
        effectiveFrom: '2026-09-15',
        kcal: 2100,
        maintenanceKcal: 2600,
      ),
    ];
    expect(targetOn(targets, '2026-08-31'), isNull);
    expect(targetOn(targets, '2026-09-14')!.kcal, 2200);
    expect(targetOn(targets, '2026-09-15')!.kcal, 2100);
  });

  test('weeklyIntake averages fully logged days only, with week target', () {
    const targets = [
      TargetPoint(
        effectiveFrom: '2026-09-16',
        kcal: 2000,
        maintenanceKcal: 2500,
      ),
      TargetPoint(
        effectiveFrom: '2026-09-21',
        kcal: 1900,
        maintenanceKcal: 2450,
      ),
    ];
    final weeks = weeklyIntake([
      day('2026-09-14', 2100),
      day('2026-09-15', 1900),
      day('2026-09-16', 5000, logged: false),
      day('2026-09-21', 1800),
      day('2026-09-22', 0, logged: false),
      day('2026-09-28', 0, logged: false),
    ], targets);
    expect(weeks.map((w) => w.weekStart), [
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
    ]);
    expect(weeks[0].avgKcal, 2000);
    expect(weeks[0].loggedDays, 2);
    // No target at week start: the one set during the week counts.
    expect(weeks[0].targetKcal, 2000);
    expect(weeks[1].avgKcal, 1800);
    expect(weeks[1].targetKcal, 1900);
    expect(weeks[2].avgKcal, isNull);
    expect(weeks[2].loggedDays, 0);
  });

  test('stepsWithAverage uses a trailing 7-day window over known days', () {
    final days = [
      for (var i = 1; i <= 9; i++) act('2026-09-0$i', i == 3 ? null : i * 1000),
    ];
    final out = stepsWithAverage(days);
    expect(out[0].avg7, 1000);
    expect(out[2].steps, isNull);
    expect(out[2].avg7, 1500); // (1000 + 2000) / 2
    // Day 9 window = days 3..9, day 3 has no data: (4..9) * 1000 / 6.
    expect(out[8].avg7, closeTo((4 + 5 + 6 + 7 + 8 + 9) * 1000 / 6, 1e-9));
    expect(hasAnySteps(days), isTrue);
    expect(hasAnySteps([act('2026-09-01', null)]), isFalse);
  });

  test('stepsWithAverage with `from` uses lead-in days for a real trailing '
      'average, then trims the result to `from` onward', () {
    // 6 days of lead-in (2026-08-27..09-01, 500 steps each) plus the visible
    // range (2026-09-02..09-04, 2000 steps each).
    final days = [
      for (var i = 27; i <= 31; i++) act('2026-08-$i', 500),
      act('2026-09-01', 500),
      act('2026-09-02', 2000),
      act('2026-09-03', 2000),
      act('2026-09-04', 2000),
    ];
    final out = stepsWithAverage(days, from: '2026-09-02');
    // Only the visible range comes back...
    expect(out.map((d) => d.dayKey), [
      '2026-09-02',
      '2026-09-03',
      '2026-09-04',
    ]);
    // ...but the first point's average is a real trailing 7-day window
    // (6 lead-in days at 500 + itself at 2000), not just itself.
    expect(out[0].avg7, closeTo((6 * 500 + 2000) / 7, 1e-9));
    // Without `from`, nothing is trimmed (existing callers keep working).
    expect(stepsWithAverage(days).length, days.length);
  });

  test('workoutsPerWeek counts per Monday week', () {
    final weeks = workoutsPerWeek([
      act('2026-09-20', null, workouts: 1), // week of 14th
      act('2026-09-21', null, workouts: 2),
      act('2026-09-23', null, workouts: 1),
      act('2026-09-28', null),
    ]);
    expect(weeks.map((w) => (w.weekStart, w.count)), [
      ('2026-09-14', 1),
      ('2026-09-21', 3),
      ('2026-09-28', 0),
    ]);
  });

  test('maintenanceSeries is a step series clipped to the range', () {
    const targets = [
      TargetPoint(effectiveFrom: '2026-08-01', kcal: 0, maintenanceKcal: 2700),
      TargetPoint(effectiveFrom: '2026-09-10', kcal: 0, maintenanceKcal: 2600),
      TargetPoint(effectiveFrom: '2026-09-17', kcal: 0, maintenanceKcal: 2550),
    ];
    final s = maintenanceSeries(targets, '2026-09-01', '2026-09-25');
    expect(s.map((p) => (p.dayKey, p.kcal)), [
      ('2026-09-01', 2700),
      ('2026-09-10', 2600),
      ('2026-09-17', 2550),
      ('2026-09-25', 2550),
    ]);
    expect(maintenanceSeries(const [], '2026-09-01', '2026-09-25'), isEmpty);
    expect(maintenanceSeries(targets, '2026-07-01', '2026-07-31'), isEmpty);
  });

  group('headlines', () {
    test('weightHeadline shows the latest trend and its change', () {
      const points = [
        TrendPoint(dayKey: '2026-09-01', trendKg: 84.3),
        TrendPoint(dayKey: '2026-09-02', trendKg: 83.8),
        TrendPoint(dayKey: '2026-09-03', trendKg: 83.14),
      ];
      expect(weightHeadline(points), 'Trend 83.1 kg · −1.2 kg');
      expect(weightHeadline(points.sublist(0, 1)), 'Trend 84.3 kg');
      expect(weightHeadline(const []), isNull);
    });

    test('stepsHeadline averages days with data, rounded to 100', () {
      expect(
        stepsHeadline([
          act('2026-09-01', 8000),
          act('2026-09-02', null),
          act('2026-09-03', 8760),
        ]),
        'Avg 8,400/day',
      );
      expect(stepsHeadline([act('2026-09-01', null)]), isNull);
    });

    test('intakeHeadline uses fully logged days and their targets', () {
      const targets = [
        TargetPoint(
          effectiveFrom: '2026-09-01',
          kcal: 2200,
          maintenanceKcal: 0,
        ),
        TargetPoint(
          effectiveFrom: '2026-09-03',
          kcal: 2400,
          maintenanceKcal: 0,
        ),
      ];
      final days = [
        day('2026-09-01', 2100),
        day('2026-09-02', 9999, logged: false),
        day('2026-09-03', 2200),
      ];
      expect(intakeHeadline(days, targets), 'Avg 2,150 of 2,300 kcal');
      expect(intakeHeadline(days, const []), 'Avg 2,150 kcal');
      expect(
        intakeHeadline([day('2026-09-01', 2000, logged: false)], targets),
        isNull,
      );
    });

    test(
      'intakeHeadline averages intake and target over the same day-set, '
      'excluding fully-logged days that predate any target',
      () {
        const targets = [
          TargetPoint(
            effectiveFrom: '2026-09-03',
            kcal: 2000,
            maintenanceKcal: 0,
          ),
        ];
        final days = [
          // Logged before targets existed: has no matching target row.
          day('2026-09-01', 3000),
          day('2026-09-02', 3000),
          // Logged once a target was in effect.
          day('2026-09-03', 2200),
          day('2026-09-04', 1800),
        ];
        // Both averages are over 09-03/09-04 only: the pre-target days would
        // otherwise drag the intake average away from a target average that
        // never included them.
        expect(intakeHeadline(days, targets), 'Avg 2,000 of 2,000 kcal');
      },
    );

    test('workoutsHeadline counts workouts and the weekly rate', () {
      final days = [
        for (var i = 0; i < 28; i++)
          act(addDays('2026-09-01', i), null, workouts: i % 3 == 0 ? 1 : 0),
      ];
      expect(workoutsHeadline(days), '10 workouts · 2.5/week');
      expect(
        workoutsHeadline([act('2026-09-01', null, workouts: 1)]),
        '1 workout · 7.0/week',
      );
      expect(workoutsHeadline([act('2026-09-01', 5000)]), isNull);
    });

    test('maintenanceHeadline shows the latest estimate', () {
      expect(
        maintenanceHeadline(const [
          MaintenancePoint(dayKey: '2026-09-01', kcal: 2600),
          MaintenancePoint(dayKey: '2026-09-25', kcal: 2553),
        ]),
        'Now 2,550 kcal/day',
      );
      expect(maintenanceHeadline(const []), isNull);
    });
  });
}
