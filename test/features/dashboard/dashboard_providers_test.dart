import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/dashboard/dashboard_providers.dart';
import 'package:nutrition_app/features/lifting/lift_progress_logic.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';

import '../../helpers/test_db.dart';
import '../weight/provider_wait.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 20)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> addTarget(String from, double kcal, double maintenance) => db
      .into(db.targetHistory)
      .insert(
        TargetHistoryCompanion.insert(
          effectiveFrom: from,
          kcal: kcal,
          proteinG: 150,
          fatG: 70,
          carbsG: 200,
          maintenanceKcal: maintenance,
          method: 0,
          createdAt: DateTime(2026, 9, 25),
        ),
      );

  test('fixed ranges end today', () async {
    expect(await waitFor(container, dashboardWindowProvider, (_) => true), (
      '2026-08-29',
      '2026-09-25',
    ));
    container.read(dashboardRangeProvider.notifier).set(DashboardRange.weeks12);
    expect(
      await waitFor(
        container,
        dashboardWindowProvider,
        (w) => w.$1 != '2026-08-29',
      ),
      ('2026-07-04', '2026-09-25'),
    );
  });

  test('"all" starts at the earliest data, at least 4 weeks back', () async {
    container.read(dashboardRangeProvider.notifier).set(DashboardRange.all);
    expect(await waitFor(container, dashboardWindowProvider, (_) => true), (
      '2026-08-29',
      '2026-09-25',
    ));

    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-03-02',
            weightKg: 90,
            createdAt: DateTime(2026, 3, 2),
          ),
        );
    await addTarget('2026-02-15', 2200, 2700);
    expect(
      await waitFor(
        container,
        dashboardWindowProvider,
        (w) => w.$1 == '2026-02-15',
      ),
      ('2026-02-15', '2026-09-25'),
    );
  });

  test('"all" reaches back to the first lifting day', () async {
    container.read(dashboardRangeProvider.notifier).set(DashboardRange.all);
    final lifting = LiftingRepository(db, () => DateTime(2026, 9, 25));
    final bench = await lifting.addExercise(
      name: 'Bench press',
      muscleGroup: MuscleGroup.chest,
      isBodyweight: false,
    );
    final entry = await lifting.addEntry('2026-01-10', bench);
    await lifting.addSet(entry, reps: 5, weightKg: 60);
    expect(
      await waitFor(
        container,
        dashboardWindowProvider,
        (w) => w.$1 == '2026-01-10',
      ),
      ('2026-01-10', '2026-09-25'),
    );
    // Lifting days don't count as food-logging history (the "Was yesterday
    // complete?" prompt on Today reads this).
    expect(
      await waitFor(container, earliestDataDayProvider, (_) => true),
      isNull,
    );
  });

  test('"all" ignores lifting days while the lifting feature is off', () async {
    final off = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 20)),
        featureEnabledProvider.overrideWith(
          (ref, f) => f != AppFeature.lifting,
        ),
      ],
    );
    addTearDown(off.dispose);
    off.read(dashboardRangeProvider.notifier).set(DashboardRange.all);
    final lifting = LiftingRepository(db, () => DateTime(2026, 9, 25));
    final bench = await lifting.addExercise(
      name: 'Bench press',
      muscleGroup: MuscleGroup.chest,
      isBodyweight: false,
    );
    final entry = await lifting.addEntry('2026-01-10', bench);
    await lifting.addSet(entry, reps: 5, weightKg: 60);
    expect(await waitFor(off, dashboardWindowProvider, (_) => true), (
      '2026-08-29',
      '2026-09-25',
    ));
  });

  test('lifting chart selection: picking an exercise resets the metric', () {
    expect(container.read(dashboardLiftExerciseIdProvider), isNull);
    expect(container.read(dashboardLiftMetricProvider), isNull);

    container.read(dashboardLiftExerciseIdProvider.notifier).set(3);
    container
        .read(dashboardLiftMetricProvider.notifier)
        .set(LiftMetric.bestReps);
    expect(container.read(dashboardLiftExerciseIdProvider), 3);
    expect(container.read(dashboardLiftMetricProvider), LiftMetric.bestReps);

    // The same exercise again keeps the picked metric.
    container.read(dashboardLiftExerciseIdProvider.notifier).set(3);
    expect(container.read(dashboardLiftMetricProvider), LiftMetric.bestReps);

    // Another exercise goes back to the default rule.
    container.read(dashboardLiftExerciseIdProvider.notifier).set(4);
    expect(container.read(dashboardLiftExerciseIdProvider), 4);
    expect(container.read(dashboardLiftMetricProvider), isNull);
  });

  test('targetHistoryProvider is ordered and updates live', () async {
    expect(
      await waitFor(container, targetHistoryProvider, (_) => true),
      isEmpty,
    );
    await addTarget('2026-09-14', 2000, 2500);
    await addTarget('2026-09-01', 2100, 2600);
    final list = await waitFor(
      container,
      targetHistoryProvider,
      (l) => l.length == 2,
    );
    expect(list.map((t) => t.effectiveFrom), ['2026-09-01', '2026-09-14']);
    expect(list.last.maintenanceKcal, 2500);
  });
}
