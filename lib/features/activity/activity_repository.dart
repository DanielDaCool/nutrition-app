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
  final manualRows =
      await (db.select(db.manualExercises)
            ..where((t) => t.dayKey.isBetweenValues(from, to))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
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
        kcal: w.kcal,
      ),
    );
  }
  for (final m in manualRows) {
    // Anchored to the exercise's own dayKey (with createdAt's time-of-day
    // carried over) rather than to createdAt outright: a workout logged
    // today for an earlier day must show among that day's workouts, at a
    // plausible time for that day - not at today's clock time.
    final day = startOfDay(m.dayKey);
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      m.createdAt.hour,
      m.createdAt.minute,
      m.createdAt.second,
    );
    (workoutsByDay[m.dayKey] ??= []).add(
      WorkoutSummary(
        id: 'manual-${m.id}',
        title: m.activityName,
        start: start,
        end: start.add(Duration(seconds: (m.durationMin * 60).round())),
        kcal: m.kcal,
        isManual: true,
        distanceKm: m.distanceKm,
        inclinePct: m.inclinePct,
      ),
    );
  }
  for (final entries in workoutsByDay.values) {
    entries.sort((a, b) => a.start.compareTo(b.start));
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
            TableUpdateQuery.onAllTables([
              db.dailySteps,
              db.workouts,
              db.manualExercises,
            ]),
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

/// Adds a manually logged aerobic exercise (this feature's only writer of
/// ManualExercises).
Future<void> addManualExercise(
  AppDatabase db, {
  required String dayKey,
  required String activityName,
  required double durationMin,
  required double kcal,
  double? metValue,
  double? distanceKm,
  double? inclinePct,
  required DateTime now,
}) {
  return db
      .into(db.manualExercises)
      .insert(
        ManualExercisesCompanion.insert(
          dayKey: dayKey,
          activityName: activityName,
          durationMin: durationMin,
          kcal: kcal,
          metValue: Value(metValue),
          distanceKm: Value(distanceKm),
          inclinePct: Value(inclinePct),
          createdAt: now,
        ),
      );
}

/// Removes a manually logged exercise by its row id (see
/// [WorkoutSummary.id], stripped of the `manual-` prefix).
Future<void> deleteManualExercise(AppDatabase db, int id) {
  return (db.delete(db.manualExercises)..where((t) => t.id.equals(id))).go();
}
