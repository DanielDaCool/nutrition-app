import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_repository.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('migration_test');
    file = File('${dir.path}/db.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  /// Drops the lifting tables (added in v4), children first.
  Future<void> dropLifting(AppDatabase db) async {
    for (final table in [
      'lift_sets',
      'lift_preset_items',
      'lift_entries',
      'lift_presets',
      'lift_exercises',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
  }

  /// Makes the file look like a v1 install: current schema, then [downgrade]
  /// applied, with user_version set back to 1.
  Future<void> makeV1(Future<void> Function(AppDatabase db) downgrade) async {
    final db = open();
    await db.customSelect('SELECT 1').get(); // opens and creates tables
    await downgrade(db);
    await dropLifting(db);
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  test('v1 install without manual_exercises gets the table', () async {
    await makeV1((db) => db.customStatement('DROP TABLE manual_exercises'));

    final db = open();
    addTearDown(db.close);
    // Before the fix this threw "no such table: manual_exercises", which the
    // Activity card showed as "Couldn't load your activity".
    final days = await loadActivityRange(db, '2026-09-25', '2026-09-25');
    expect(days.single.workouts, isEmpty);

    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Treadmill walk',
      durationMin: 30,
      kcal: 200,
      distanceKm: 2.5,
      inclinePct: 6,
      now: DateTime(2026, 9, 25, 10),
    );
    final w = (await loadActivityRange(
      db,
      '2026-09-25',
      '2026-09-25',
    )).single.workouts.single;
    expect(w.distanceKm, 2.5);
    expect(w.inclinePct, 6);
  });

  test('v1 manual_exercises without distance/incline gets the columns', () async {
    await makeV1((db) async {
      await db.customStatement('DROP TABLE manual_exercises');
      await db.customStatement(
        'CREATE TABLE manual_exercises ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'day_key TEXT NOT NULL, activity_name TEXT NOT NULL, '
        'duration_min REAL NOT NULL, met_value REAL NULL, '
        'kcal REAL NOT NULL, created_at INTEGER NOT NULL)',
      );
      await db.customStatement(
        "INSERT INTO manual_exercises (day_key, activity_name, duration_min, "
        "met_value, kcal, created_at) "
        "VALUES ('2026-09-25', 'Cycling, moderate', 30, 8.0, 320, 1790000000)",
      );
    });

    final db = open();
    addTearDown(db.close);
    final row = await db.select(db.manualExercises).getSingle();
    expect(row.activityName, 'Cycling, moderate');
    expect(row.kcal, 320);
    expect(row.distanceKm, isNull);
    expect(row.inclinePct, isNull);
  });

  test('v3 install gets the lifting tables and keeps its data', () async {
    var db = open();
    await db.customSelect('SELECT 1').get(); // opens and creates tables
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-25',
            weightKg: 90,
            createdAt: DateTime(2026, 9, 25, 8),
          ),
        );
    await dropLifting(db);
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = open();
    addTearDown(db.close);
    expect((await db.select(db.weighIns).getSingle()).weightKg, 90);

    final repo = LiftingRepository(db, () => DateTime(2026, 10, 4, 9));
    final dips = await repo.addExercise(
      name: 'Dips',
      muscleGroup: MuscleGroup.triceps,
      isBodyweight: true,
    );
    final entry = await repo.addEntry('2026-10-04', dips);
    await repo.addSet(entry, reps: 8, weightKg: 20);
    await repo.createPreset('Push day', [dips]);
    final day = await repo.watchDay('2026-10-04').first;
    expect(day.single.sets.single.weightKg, 20);

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'lift_%'",
        )
        .map((r) => r.read<String>('name'))
        .get();
    expect(indexes, containsAll([
      'lift_entries_day_idx',
      'lift_entries_exercise_idx',
      'lift_sets_entry_idx',
    ]));
  });
}
