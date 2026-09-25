import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/day_key.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';

/// Reads the local copy of Health Connect data.

/// One [DayActivity] per calendar day in [from, to] inclusive, oldest first.
/// Days without step data have `steps == null`.
Future<List<DayActivity>> loadActivityRange(
  AppDatabase db,
  String from,
  String to,
) async {
  if (from.compareTo(to) > 0) return const [];
  final stepRows = await (db.select(
    db.dailySteps,
  )..where((t) => t.dayKey.isBetweenValues(from, to))).get();
  final workoutRows =
      await (db.select(db.workouts)
            ..where((t) => t.dayKey.isBetweenValues(from, to))
            ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
          .get();

  final stepsByDay = {for (final r in stepRows) r.dayKey: r.steps};
  final workoutsByDay = <String, List<WorkoutSummary>>{};
  for (final w in workoutRows) {
    (workoutsByDay[w.dayKey] ??= []).add(
      WorkoutSummary(
        id: w.id,
        title: w.title,
        start: w.startTime,
        end: w.endTime,
        sourceApp: w.sourceApp,
      ),
    );
  }

  final days = <DayActivity>[];
  final count = daysBetween(from, to);
  for (var i = 0; i <= count; i++) {
    final d = addDays(from, i);
    days.add(
      DayActivity(
        dayKey: d,
        steps: stepsByDay[d],
        workouts: List.unmodifiable(workoutsByDay[d] ?? const []),
      ),
    );
  }
  return days;
}

/// [loadActivityRange], re-emitted whenever DailySteps or Workouts change.
///
/// Built on `tableUpdates` rather than drift's query `.watch()`: a watched
/// query schedules a zero-length timer when its last listener leaves, which
/// trips Flutter's "timer still pending" check in widget tests that dispose
/// the tree without pumping again.
Stream<List<DayActivity>> watchActivityRange(
  AppDatabase db,
  String from,
  String to,
) {
  late final StreamController<List<DayActivity>> controller;
  StreamSubscription<Set<TableUpdate>>? updates;
  var generation = 0;

  Future<void> reload() async {
    final mine = ++generation;
    try {
      final days = await loadActivityRange(db, from, to);
      if (mine == generation && !controller.isClosed) controller.add(days);
    } catch (e, st) {
      if (mine == generation && !controller.isClosed) {
        controller.addError(e, st);
      }
    }
  }

  controller = StreamController<List<DayActivity>>(
    onListen: () {
      // Subscribe before the first read so no change can slip in between.
      updates = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([db.dailySteps, db.workouts]),
          )
          .listen((_) => reload());
      reload();
    },
    onCancel: () async {
      await updates?.cancel();
      updates = null;
    },
  );
  return controller.stream;
}
