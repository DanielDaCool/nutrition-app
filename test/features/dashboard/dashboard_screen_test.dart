import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/dashboard/dashboard_logic.dart';
import 'package:nutrition_app/features/dashboard/dashboard_screen.dart';
import 'package:nutrition_app/features/food/food_providers.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<Override> extra = const [],
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          ...extra,
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D5B),
              brightness: brightness,
            ),
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> addProfileAndWeighIn() async {
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            sex: 0,
            birthDate: DateTime(1990),
            heightCm: 180,
            activityLevel: 1,
            goalWeightKg: 78,
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-25',
            weightKg: 82,
            createdAt: DateTime(2026, 9, 25),
          ),
        );
  }

  testWidgets('empty database shows one setup card, not empty charts', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Add your first weigh-in'), findsOneWidget);
    expect(find.textContaining('No fully logged days'), findsNothing);
    expect(find.textContaining('No step data'), findsNothing);
    expect(find.textContaining('No workouts in this range'), findsNothing);
    expect(find.textContaining('No maintenance estimate yet'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // The weigh-in step opens the dialog and saves.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('weighInKgField')), '82.4');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await db.select(db.weighIns).get()).single.weightKg, 82.4);
    expect(find.text('Add your first weigh-in'), findsOneWidget); // done ✓
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
    await unmount(tester);
  });

  testWidgets('after setup, empty sections explain and offer a fix', (
    tester,
  ) async {
    await addProfileAndWeighIn();
    await pumpDashboard(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Finish setup'), findsNothing);
    expect(
      find.text('Your trend appears after a few weigh-ins'),
      findsOneWidget,
    );
    expect(find.text('Add weigh-in'), findsOneWidget);
    expect(find.textContaining('No fully logged days'), findsOneWidget);
    expect(find.textContaining('No step data'), findsOneWidget);
    expect(find.byKey(const Key('connectHealthConnect')), findsOneWidget);
    expect(find.textContaining('No workouts in this range'), findsOneWidget);
    expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);

    for (final label in ['12 weeks', 'All', '4 weeks']) {
      await tester.tap(find.text(label));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    }
    await unmount(tester);
  });

  testWidgets(
    'connected but no step data shows an empty state, not the connect CTA',
    (tester) async {
      // Bug: Health Connect is already connected, but there's just no step
      // data in range yet (e.g. a fresh emulator) — the steps card used to
      // show "Connect Health Connect" regardless of connection status.
      await addProfileAndWeighIn();
      await pumpDashboard(
        tester,
        extra: [
          healthStatusProvider.overrideWith(
            () => _FixedHealthStatus(
              const HealthConnectStatus(HealthStatusKind.ok),
            ),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('No step data'), findsOneWidget);
      expect(find.byKey(const Key('connectHealthConnect')), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('renders charts with data in light and dark', (tester) async {
    for (var i = 0; i < 40; i++) {
      final day = addDays('2026-09-25', -i);
      if (i % 2 == 0) {
        await db
            .into(db.weighIns)
            .insert(
              WeighInsCompanion.insert(
                dayKey: day,
                weightKg: 85 + i * 0.05,
                createdAt: DateTime(2026, 9, 25),
              ),
            );
      }
    }
    for (final (from, m) in [('2026-08-20', 2600.0), ('2026-09-14', 2550.0)]) {
      await db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: from,
              kcal: m - 500,
              proteinG: 150,
              fatG: 70,
              carbsG: 200,
              maintenanceKcal: m,
              method: 1,
              createdAt: DateTime(2026, 9, 25),
            ),
          );
    }
    List<String> daysOf((String, String) r) => [
      for (var d = r.$1; d.compareTo(r.$2) <= 0; d = addDays(d, 1)) d,
    ];
    final extra = [
      intakeRangeProvider.overrideWith(
        (ref, r) => Stream.value([
          for (final d in daysOf(r))
            DayIntake(
              dayKey: d,
              total: const Macros(kcal: 2050, proteinG: 0, fatG: 0, carbsG: 0),
              byMeal: const {},
              fullyLogged: startOfDay(d).day.isEven,
            ),
        ]),
      ),
      activityRangeProvider.overrideWith(
        (ref, r) => Stream.value([
          for (final d in daysOf(r))
            DayActivity(
              dayKey: d,
              steps: d.endsWith('0') ? null : 8000 + startOfDay(d).day * 100,
              workouts: [
                if (d.endsWith('3'))
                  WorkoutSummary(
                    id: d,
                    title: 'Strength',
                    start: DateTime(2026, 9, 1, 18),
                    end: DateTime(2026, 9, 1, 19),
                  ),
              ],
            ),
        ]),
      ),
    ];

    for (final brightness in Brightness.values) {
      await pumpDashboard(tester, extra: extra, brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('No weigh-ins in this range yet'), findsNothing);
      expect(find.textContaining('No step data'), findsNothing);
      expect(find.textContaining('No workouts in this range'), findsNothing);
      expect(find.textContaining('No maintenance estimate'), findsNothing);
      expect(find.text('kcal/day'), findsNWidgets(2));
      expect(find.text('steps'), findsOneWidget);
      // Headline numbers on each card.
      expect(find.textContaining(RegExp(r'^Trend \d+\.\d kg · ')), findsOne);
      expect(find.textContaining(RegExp(r'^Avg [\d,]+/day$')), findsOne);
      expect(
        find.textContaining(RegExp(r'^Avg 2,050 of [\d,]+ kcal$')),
        findsOne,
      );
      expect(find.textContaining(RegExp(r'^\d+ workouts · ')), findsOne);
      expect(find.text('Now 2,550 kcal/day'), findsOneWidget);

      await tester.tap(find.text('All'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    }
  });

  testWidgets(
    'workouts chart fetches full Monday-aligned weeks, not a partial '
    'first/last week',
    (tester) async {
      await addProfileAndWeighIn();
      final requestedWindows = <(String, String)>[];
      final extra = [
        activityRangeProvider.overrideWith((ref, r) {
          requestedWindows.add(r);
          return Stream.value(const []);
        }),
      ];
      await pumpDashboard(tester, extra: extra);
      expect(tester.takeException(), isNull);

      // The dashboard window itself: today - 27 .. today (not Monday-
      // aligned in general).
      const today = '2026-09-25';
      final plainWindow = (addDays(today, -27), today);
      expect(requestedWindows, contains(plainWindow));

      // The workouts chart fetches from the Monday on/before that `from`,
      // so every bucketed week (including the first) is a full 7 days.
      final chartWindow = (weekStartOf(plainWindow.$1), today);
      expect(chartWindow.$1, isNot(plainWindow.$1)); // the range isn't
      // already Monday-aligned, so this genuinely exercises the fix.
      expect(requestedWindows, contains(chartWindow));

      await unmount(tester);
    },
  );

  testWidgets(
    'steps chart fetches 6 lead-in days for a real trailing 7-day average',
    (tester) async {
      await addProfileAndWeighIn();
      final requestedWindows = <(String, String)>[];
      final extra = [
        activityRangeProvider.overrideWith((ref, r) {
          requestedWindows.add(r);
          return Stream.value(const []);
        }),
      ];
      await pumpDashboard(tester, extra: extra);
      expect(tester.takeException(), isNull);

      const today = '2026-09-25';
      final plainWindow = (addDays(today, -27), today);
      expect(requestedWindows, contains(plainWindow));

      final avgWindow = (addDays(plainWindow.$1, -6), today);
      expect(requestedWindows, contains(avgWindow));

      await unmount(tester);
    },
  );

  testWidgets('web leaves out the steps and workouts charts', (tester) async {
    await addProfileAndWeighIn();
    await pumpDashboard(tester, extra: [isWebProvider.overrideWithValue(true)]);
    expect(tester.takeException(), isNull);
    expect(find.text('Steps per day'), findsNothing);
    expect(find.text('Workouts per week'), findsNothing);
    expect(find.byKey(const Key('connectHealthConnect')), findsNothing);
    expect(find.textContaining('No fully logged days'), findsOneWidget);
    expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the steps and workouts charts are left out when switched off', (
    tester,
  ) async {
    await addProfileAndWeighIn();
    await pumpDashboard(tester);
    expect(find.text('Steps per day'), findsOneWidget);
    expect(find.text('Workouts per week'), findsOneWidget);
    await unmount(tester);

    await pumpDashboard(
      tester,
      extra: [
        featureEnabledProvider.overrideWith(
          (ref, f) => f != AppFeature.activity,
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Steps per day'), findsNothing);
    expect(find.text('Workouts per week'), findsNothing);
    // The other sections stay.
    expect(find.textContaining('No fully logged days'), findsOneWidget);
    expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);
    await unmount(tester);
  });

  group('lifting progress', () {
    late LiftingRepository lifting;
    setUp(
      () => lifting = LiftingRepository(db, () => DateTime(2026, 9, 25, 12)),
    );

    Future<int> addExercise(String name, {bool isBodyweight = false}) =>
        lifting.addExercise(
          name: name,
          muscleGroup: MuscleGroup.chest,
          isBodyweight: isBodyweight,
        );

    /// Tracks `(weightKg, reps)` sets of [exerciseId] on [dayKey].
    Future<void> track(
      String dayKey,
      int exerciseId,
      List<(double, int)> sets,
    ) async {
      final entryId = await lifting.addEntry(dayKey, exerciseId);
      for (final (weightKg, reps) in sets) {
        await lifting.addSet(entryId, reps: reps, weightKg: weightKg);
      }
    }

    Future<void> seedBenchAndDips() async {
      final bench = await addExercise('Bench press');
      final dips = await addExercise('Dips', isBodyweight: true);
      await track('2026-09-10', bench, [(60, 7), (60, 4)]);
      await track('2026-09-17', bench, [(62.5, 6)]);
      await track('2026-09-24', bench, [(65, 5), (65, 5), (60, 8), (60, 7)]);
      await track('2026-09-12', dips, [(0, 8), (0, 6)]);
      await track('2026-09-19', dips, [(0, 10)]);
    }

    Future<void> pumpFrames(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    LineChartData chartData(WidgetTester tester) => tester
        .widget<LineChart>(find.byKey(const Key('liftProgressChart')))
        .data;

    testWidgets('shows the first exercise with its trend and all sets', (
      tester,
    ) async {
      await addProfileAndWeighIn();
      await seedBenchAndDips();
      await pumpDashboard(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Lifting progress'), findsOneWidget);
      expect(find.text('60 kg → 65 kg (+5 kg)'), findsOneWidget);
      expect(find.text('Bench press'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.textContaining('No lifting tracked yet'), findsNothing);

      // A dot per trained day; x = days since the window start (29 Aug).
      final data = chartData(tester);
      final bar = data.lineBarsData.single;
      expect(bar.spots, const [FlSpot(12, 60), FlSpot(19, 62.5), FlSpot(26, 65)]);
      expect(data.minY, lessThan(60));
      expect(data.minY, greaterThan(0));
      expect(data.maxY, greaterThan(65));
      expect(data.maxX, 27);

      // The tooltip lists every set of the day, wrapped.
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(bar, 0, bar.spots[0]),
        LineBarSpot(bar, 0, bar.spots[2]),
      ]);
      expect(items[0]!.text, '10 Sep\n60 kg × 7 · 60 kg × 4');
      expect(
        items[1]!.text,
        '24 Sep\n65 kg × 5 · 65 kg × 5\n60 kg × 8 · 60 kg × 7',
      );

      // Switching the metric.
      await tester.tap(find.byKey(const Key('liftMetric_bestReps')));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('7 → 8 reps (+1)'), findsOneWidget);
      expect(find.text('reps'), findsOneWidget);
      expect(chartData(tester).lineBarsData.single.spots.map((s) => s.y), [
        7,
        6,
        8,
      ]);
      await unmount(tester);
    });

    testWidgets('switching exercise changes the headline', (tester) async {
      await addProfileAndWeighIn();
      await seedBenchAndDips();
      await pumpDashboard(tester);
      expect(find.text('60 kg → 65 kg (+5 kg)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('liftExerciseDropdown')));
      await pumpFrames(tester);
      await tester.tap(find.text('Dips').last);
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      // Bodyweight without extra weight defaults to reps.
      expect(find.text('8 → 10 reps (+2)'), findsOneWidget);
      expect(find.text('60 kg → 65 kg (+5 kg)'), findsNothing);
      final data = chartData(tester);
      final bar = data.lineBarsData.single;
      expect(bar.spots, const [FlSpot(14, 8), FlSpot(21, 10)]);
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(bar, 0, bar.spots[0]),
      ]);
      expect(items.single!.text, '12 Sep\nBW × 8 · BW × 6');
      await unmount(tester);
    });

    testWidgets('a single trained day still draws its point', (tester) async {
      await addProfileAndWeighIn();
      final bench = await addExercise('Bench press');
      await track('2026-09-20', bench, [(60, 5)]);
      await pumpDashboard(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('60 kg'), findsOneWidget);
      final data = chartData(tester);
      expect(data.lineBarsData.single.spots, const [FlSpot(22, 60)]);
      expect(data.lineBarsData.single.dotData.show, isTrue);
      expect(data.maxY, greaterThan(data.minY));
      await unmount(tester);
    });

    testWidgets('no sets in the range keeps the selector', (tester) async {
      await addProfileAndWeighIn();
      final bench = await addExercise('Bench press');
      await track('2026-05-01', bench, [(50, 5)]);
      await pumpDashboard(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('No sets for this exercise in this range.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('liftExerciseDropdown')), findsOneWidget);
      expect(find.byKey(const Key('liftProgressChart')), findsNothing);

      // "All" reaches back to the first lifting day.
      await tester.tap(find.text('All'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('50 kg'), findsOneWidget);
      expect(find.byKey(const Key('liftProgressChart')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('explains itself when nothing is tracked', (tester) async {
      await addProfileAndWeighIn();
      // A planned exercise without sets doesn't count as tracked.
      final bench = await addExercise('Bench press');
      await lifting.addEntry('2026-09-25', bench);
      await pumpDashboard(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Lifting progress'), findsOneWidget);
      expect(
        find.text(
          'No lifting tracked yet.\n'
          'Track sets on the Lifting tab to see your progress.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('liftExerciseDropdown')), findsNothing);
      await unmount(tester);
    });

    testWidgets('is left out during setup when nothing is tracked', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Finish setup'), findsOneWidget);
      expect(find.text('Lifting progress'), findsNothing);
      await unmount(tester);
    });

    testWidgets('is left out when lifting is switched off', (tester) async {
      await addProfileAndWeighIn();
      await seedBenchAndDips();
      await pumpDashboard(tester);
      expect(find.text('Lifting progress'), findsOneWidget);
      await unmount(tester);

      await pumpDashboard(
        tester,
        extra: [
          featureEnabledProvider.overrideWith(
            (ref, f) => f != AppFeature.lifting,
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Lifting progress'), findsNothing);
      expect(find.byKey(const Key('liftExerciseDropdown')), findsNothing);
      expect(find.byKey(const Key('liftProgressChart')), findsNothing);
      expect(find.textContaining('No lifting tracked yet'), findsNothing);
      // The other sections stay.
      expect(find.text('Steps per day'), findsOneWidget);
      expect(find.text('Workouts per week'), findsOneWidget);
      expect(find.textContaining('No fully logged days'), findsOneWidget);
      expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);
      await unmount(tester);
    });
  });
}

/// Always reports a fixed [HealthConnectStatus], for testing status-driven UI.
class _FixedHealthStatus extends HealthStatusController {
  _FixedHealthStatus(this._status);
  final HealthConnectStatus _status;

  @override
  HealthConnectStatus build() => _status;
}
