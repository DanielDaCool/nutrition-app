// Dashboard state: the selected range, the date window it maps to, and
// read-only streams over target history and data extent.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/day_key.dart';
import '../lifting/lift_progress_logic.dart';
import '../weight/table_watch.dart';
import 'dashboard_logic.dart';

/// Dashboard range choices; [days] is null for "All".
enum DashboardRange {
  weeks4('4 weeks', 28),
  weeks12('12 weeks', 84),
  all('All', null);

  const DashboardRange(this.label, this.days);
  final String label;
  final int? days;
}

/// Selected dashboard range (defaults to 4 weeks).
final dashboardRangeProvider =
    NotifierProvider<DashboardRangeNotifier, DashboardRange>(
      DashboardRangeNotifier.new,
    );

/// Holds the selected [DashboardRange].
class DashboardRangeNotifier extends Notifier<DashboardRange> {
  @override
  DashboardRange build() => DashboardRange.weeks4;

  void set(DashboardRange range) => state = range;
}

/// Id of the exercise picked on the "Lifting progress" chart. Null (or an id
/// that is no longer among the logged exercises) means the first logged one.
final dashboardLiftExerciseIdProvider =
    NotifierProvider<DashboardLiftExerciseIdNotifier, int?>(
      DashboardLiftExerciseIdNotifier.new,
    );

/// Holds the picked exercise id of the lifting chart.
class DashboardLiftExerciseIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// Shows exercise [exerciseId], with the default metric for it again.
  void set(int exerciseId) {
    if (exerciseId == state) return;
    state = exerciseId;
    ref.read(dashboardLiftMetricProvider.notifier).set(null);
  }
}

/// Metric picked on the "Lifting progress" chart; null means the default
/// rule ([defaultLiftMetric]) decides.
final dashboardLiftMetricProvider =
    NotifierProvider<DashboardLiftMetricNotifier, LiftMetric?>(
      DashboardLiftMetricNotifier.new,
    );

/// Holds the picked [LiftMetric] of the lifting chart.
class DashboardLiftMetricNotifier extends Notifier<LiftMetric?> {
  @override
  LiftMetric? build() => null;

  void set(LiftMetric? metric) => state = metric;
}

/// All accepted targets, oldest effectiveFrom first (read-only; A writes).
final targetHistoryProvider = StreamProvider<List<TargetPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.targetHistory)
    ..orderBy([
      (t) => OrderingTerm.asc(t.effectiveFrom),
      (t) => OrderingTerm.asc(t.id),
    ]);
  return watchTables(db, [db.targetHistory], () async {
    final rows = await query.get();
    return [
      for (final r in rows)
        TargetPoint(
          effectiveFrom: r.effectiveFrom,
          kcal: r.kcal,
          maintenanceKcal: r.maintenanceKcal,
        ),
    ];
  });
});

/// Earliest day with any food log, weigh-in, steps, workout or target.
final earliestDataDayProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  final tables = <TableInfo>[
    db.foodLogEntries,
    db.weighIns,
    db.dailySteps,
    db.workouts,
    db.targetHistory,
  ];
  return watchTables(db, tables, () async {
    final row = await db
        .customSelect(
          'SELECT MIN(d) AS d FROM ('
          'SELECT MIN(day_key) AS d FROM food_log_entries '
          'UNION ALL SELECT MIN(day_key) FROM weigh_ins '
          'UNION ALL SELECT MIN(day_key) FROM daily_steps '
          'UNION ALL SELECT MIN(day_key) FROM workouts '
          'UNION ALL SELECT MIN(effective_from) FROM target_history)',
          readsFrom: tables.toSet(),
        )
        .getSingle();
    return row.readNullable<String>('d');
  });
});

/// Earliest day with a tracked lifting set. Kept apart from
/// [earliestDataDayProvider], which other screens use for food logging.
final earliestLiftDayProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  final tables = <TableInfo>[db.liftEntries, db.liftSets];
  return watchTables(db, tables, () async {
    final row = await db
        .customSelect(
          'SELECT MIN(e.day_key) AS d FROM lift_entries e '
          'JOIN lift_sets s ON s.entry_id = e.id',
          readsFrom: tables.toSet(),
        )
        .getSingle();
    return row.readNullable<String>('d');
  });
});

/// The dashboard's (from, to) day keys, inclusive; `to` is today.
///
/// "All" starts at the earliest data day (including the first tracked
/// lifting day while the lifting feature is on) but always spans at least
/// 28 days.
/// "Today" is read when the range changes, not on a timer.
final dashboardWindowProvider = StreamProvider<(String from, String to)>((
  ref,
) async* {
  final range = ref.watch(dashboardRangeProvider);
  final today = dayKeyOf(ref.read(clockProvider)());
  final minFrom = addDays(today, -27);
  final days = range.days;
  if (days != null) {
    yield (addDays(today, -(days - 1)), today);
    return;
  }
  var earliest = await ref.watch(earliestDataDayProvider.future);
  if (ref.watch(featureEnabledProvider(AppFeature.lifting))) {
    final lift = await ref.watch(earliestLiftDayProvider.future);
    if (lift != null && (earliest == null || lift.compareTo(earliest) < 0)) {
      earliest = lift;
    }
  }
  final from = earliest != null && earliest.compareTo(minFrom) < 0
      ? earliest
      : minFrom;
  yield (from, today);
});
