// Dashboard state: the selected range, the date window it maps to, and
// read-only streams over target history and data extent.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
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

/// The dashboard's (from, to) day keys, inclusive; `to` is today.
///
/// "All" starts at the earliest data day but always spans at least 28 days.
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
  final earliest = await ref.watch(earliestDataDayProvider.future);
  final from = earliest != null && earliest.compareTo(minFrom) < 0
      ? earliest
      : minFrom;
  yield (from, today);
});
