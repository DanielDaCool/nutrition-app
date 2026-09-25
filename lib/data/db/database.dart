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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
