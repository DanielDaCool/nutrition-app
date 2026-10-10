import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/activity_repository.dart';

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

  /// Makes the file look like a v1 install: current schema, then [downgrade]
  /// applied, with user_version set back to 1.
  Future<void> makeV1(Future<void> Function(AppDatabase db) downgrade) async {
    final db = open();
    await db.customSelect('SELECT 1').get(); // opens and creates tables
    await downgrade(db);
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  /// Makes the file look like a v2 install: current schema, then [downgrade]
  /// applied, with user_version set back to 2.
  Future<void> makeV2(Future<void> Function(AppDatabase db) downgrade) async {
    final db = open();
    await db.customSelect('SELECT 1').get(); // opens and creates tables
    await downgrade(db);
    await db.customStatement('PRAGMA user_version = 2');
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

  test('v2 install without goal_direction gets the column, defaulting to lose', () async {
    await makeV2(
      (db) => db.customStatement('ALTER TABLE profiles DROP COLUMN goal_direction'),
    );

    final db = open();
    addTearDown(db.close);
    // Before the fix this would throw "no such column: goal_direction" as
    // soon as anything touched the profiles table.
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: const Value(1),
            sex: 0,
            birthDate: DateTime(1996, 9, 25),
            heightCm: 180,
            activityLevel: 2,
            goalWeightKg: 75,
            updatedAt: DateTime(2026, 9, 25),
          ),
        );
    final inserted = await db.select(db.profiles).getSingle();
    expect(inserted.goalDirection, 0); // lose, the documented default
  });

  test('bumping schemaVersion needs a migration step and an import upgrade', () {
    // This number changed? A schema change needs all of:
    //  1. A migration step in AppDatabase.migration (lib/data/db/database.dart)
    //     — existing installs get it applied to their on-device file.
    //  2. A matching step in _upgrade (lib/features/settings/data_import.dart)
    //     — the same transform, so a backup made before this change still
    //     imports (it never goes through the migrator).
    //  3. A test exercising the upgrade from every earlier schema version
    //     (here, and in test/features/settings/data_import_test.dart).
    // Bump this assertion once all three are done, so the diff doesn't slip
    // through unnoticed.
    final db = open();
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
  });
}
