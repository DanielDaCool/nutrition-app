import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

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
