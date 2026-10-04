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
    LiftExercises,
    LiftEntries,
    LiftSets,
    LiftPresets,
    LiftPresetItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens on [e]; tests pass an in-memory executor.
  AppDatabase(super.e);

  /// The on-device database file (nutrition.sqlite in app documents). On web
  /// drift runs sqlite3.wasm in drift_worker.js (both from the drift 2.35.0
  /// release, in web/) and stores the database in the browser. The URIs are
  /// relative so they resolve against `<base href>` when served from a subpath.
  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'nutrition',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await _addManualExercises(m);
      if (from < 3) await _addGoalDirection(m);
      if (from < 4) await _addLifting(m);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v3 -> v4. Adds the weight-lifting tables and their indexes.
  Future<void> _addLifting(Migrator m) async {
    await m.createTable(liftExercises);
    await m.createTable(liftEntries);
    await m.createTable(liftSets);
    await m.createTable(liftPresets);
    await m.createTable(liftPresetItems);
    await m.createIndex(liftEntriesDayIdx);
    await m.createIndex(liftEntriesExerciseIdx);
    await m.createIndex(liftSetsEntryIdx);
  }

  /// v2 -> v3. Adds Profiles.goalDirection (defaults to 0 = lose, so existing
  /// profiles keep losing toward their goal weight unchanged).
  Future<void> _addGoalDirection(Migrator m) async {
    final columns = await customSelect(
      "SELECT name FROM pragma_table_info('profiles')",
    ).map((r) => r.read<String>('name')).get();
    if (!columns.contains('goal_direction')) {
      await m.addColumn(profiles, profiles.goalDirection);
    }
  }

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
