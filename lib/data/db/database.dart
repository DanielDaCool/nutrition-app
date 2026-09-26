// The Drift database class. Table definitions are in tables.dart; generated
// code (database.g.dart) is committed, regenerate with build_runner.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// The app's single SQLite database. Get it via `ref.watch(databaseProvider)`
/// rather than constructing one; foreign keys are enforced on open.
@DriftDatabase(
  tables: [
    Profiles,
    Foods,
    FoodLogEntries,
    SavedMeals,
    SavedMealItems,
    WeighIns,
    DayStatuses,
    DailySteps,
    Workouts,
    ManualExercises,
    TargetHistory,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens on [e]; tests pass an in-memory executor.
  AppDatabase(super.e);

  /// The on-device database file (nutrition.sqlite in app documents).
  AppDatabase.defaults() : super(driftDatabase(name: 'nutrition'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await _addManualExercises(m);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v1 -> v2. Installs updated to the v1 build that first shipped
  /// ManualExercises never got the table (no migration ran), while fresh
  /// installs of that build have it without the distance/incline columns.
  Future<void> _addManualExercises(Migrator m) async {
    final columns = await customSelect(
      "SELECT name FROM pragma_table_info('manual_exercises')",
    ).map((r) => r.read<String>('name')).get();
    if (columns.isEmpty) {
      await m.createTable(manualExercises);
      await m.createIndex(manualExercisesDayIdx);
      return;
    }
    if (!columns.contains('distance_km')) {
      await m.addColumn(manualExercises, manualExercises.distanceKm);
    }
    if (!columns.contains('incline_pct')) {
      await m.addColumn(manualExercises, manualExercises.inclinePct);
    }
  }
}
