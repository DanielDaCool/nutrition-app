import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/settings/data_export.dart';
import 'package:nutrition_app/features/settings/data_import.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 10, 6, 9);

/// One row in every table, with foreign keys between them.
Future<void> seedEverything(AppDatabase db) async {
  await db
      .into(db.profiles)
      .insert(
        ProfilesCompanion.insert(
          sex: 0,
          birthDate: DateTime(1996, 9, 25),
          heightCm: 180,
          activityLevel: 2,
          goalWeightKg: 80,
          goalDirection: const Value(1),
          updatedAt: now,
        ),
      );
  final foodId = await db
      .into(db.foods)
      .insert(
        FoodsCompanion.insert(
          source: 'custom',
          name: 'Granola',
          kcalPer100g: 380,
          proteinPer100g: 9,
          fatPer100g: 12,
          carbsPer100g: 60,
          servingName: const Value('1 bowl'),
          servingGrams: const Value(60),
          createdAt: now,
        ),
      );
  await db
      .into(db.foodLogEntries)
      .insert(
        FoodLogEntriesCompanion.insert(
          dayKey: '2026-10-06',
          meal: 0,
          foodId: foodId,
          grams: 100,
          kcal: 380,
          proteinG: 9,
          fatG: 12,
          carbsG: 60,
          createdAt: now,
        ),
      );
  final mealId = await db
      .into(db.savedMeals)
      .insert(SavedMealsCompanion.insert(name: 'Breakfast', createdAt: now));
  await db
      .into(db.savedMealItems)
      .insert(
        SavedMealItemsCompanion.insert(
          savedMealId: mealId,
          foodId: foodId,
          grams: 60,
        ),
      );
  await db
      .into(db.weighIns)
      .insert(
        WeighInsCompanion.insert(
          dayKey: '2026-10-06',
          weightKg: 81.4,
          createdAt: now,
        ),
      );
  await db
      .into(db.dayStatuses)
      .insert(
        DayStatusesCompanion.insert(
          dayKey: '2026-10-05',
          fullyLogged: const Value(true),
        ),
      );
  await db
      .into(db.dailySteps)
      .insert(
        DailyStepsCompanion.insert(
          dayKey: '2026-10-05',
          steps: 9000,
          syncedAt: now,
        ),
      );
  await db
      .into(db.workouts)
      .insert(
        WorkoutsCompanion.insert(
          id: 'hc-1',
          dayKey: '2026-10-05',
          title: 'Legs',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          syncedAt: now,
        ),
      );
  await db
      .into(db.manualExercises)
      .insert(
        ManualExercisesCompanion.insert(
          dayKey: '2026-10-05',
          activityName: 'Walk',
          durationMin: 30,
          kcal: 150,
          distanceKm: const Value(3),
          createdAt: now,
        ),
      );
  await db
      .into(db.targetHistory)
      .insert(
        TargetHistoryCompanion.insert(
          effectiveFrom: '2026-10-01',
          kcal: 2200,
          proteinG: 160,
          fatG: 70,
          carbsG: 230,
          maintenanceKcal: 2600,
          method: 0,
          createdAt: now,
        ),
      );
  await db
      .into(db.keyValues)
      .insert(KeyValuesCompanion.insert(key: 'hc.stepGoal', value: '8000'));
}

/// An export as the file text a user would pick.
Future<String> exportText(AppDatabase db) async =>
    jsonEncode(await exportAllTables(db, now: now));

Future<Object?> tablesOf(AppDatabase db) async =>
    (await exportAllTables(db, now: now))['tables'];

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = openTestDatabase();
    target = openTestDatabase();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('knows how to restore every table', () {
    expect(importableTables.toSet(), {
      for (final t in source.allTables) t.actualTableName,
    });
  });

  test('round trip restores every table exactly', () async {
    await seedEverything(source);
    final export = parseExport(
      await exportText(source),
      currentSchemaVersion: target.schemaVersion,
    );
    expect(export.rowCount('weigh_ins'), 1);
    expect(export.rowCount('food_log_entries'), 1);
    expect(export.exportedAt, now);

    await restoreExport(target, export);
    expect(await tablesOf(target), await tablesOf(source));
  });

  test('replaces what was on the device', () async {
    await seedEverything(source);
    await target
        .into(target.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-01-01',
            weightKg: 99,
            createdAt: now,
          ),
        );
    await restoreExport(
      target,
      parseExport(
        await exportText(source),
        currentSchemaVersion: target.schemaVersion,
      ),
    );
    final days = await target.select(target.weighIns).get();
    expect(days.map((w) => w.dayKey), ['2026-10-06']);
  });

  test('new rows after a restore get fresh ids', () async {
    await seedEverything(source);
    await restoreExport(
      target,
      parseExport(
        await exportText(source),
        currentSchemaVersion: target.schemaVersion,
      ),
    );
    final id = await target
        .into(target.foods)
        .insert(
          FoodsCompanion.insert(
            source: 'custom',
            name: 'Apple',
            kcalPer100g: 52,
            proteinPer100g: 0.3,
            fatPer100g: 0.2,
            carbsPer100g: 14,
            createdAt: now,
          ),
        );
    expect(id, greaterThan(1));
  });

  test('a v2 backup gets the goalDirection default (lose)', () async {
    await seedEverything(source);
    final data = jsonDecode(await exportText(source)) as Map<String, dynamic>;
    data['schemaVersion'] = 2;
    final profiles = (data['tables'] as Map)['profiles'] as List;
    (profiles.single as Map).remove('goalDirection');

    await restoreExport(
      target,
      parseExport(jsonEncode(data), currentSchemaVersion: target.schemaVersion),
    );
    final profile = await target.select(target.profiles).getSingle();
    expect(profile.goalDirection, 0);
  });

  test('a v1 backup without the manual exercises table imports', () async {
    await seedEverything(source);
    final data = jsonDecode(await exportText(source)) as Map<String, dynamic>;
    data['schemaVersion'] = 1;
    (data['tables'] as Map).remove('manual_exercises');

    await restoreExport(
      target,
      parseExport(jsonEncode(data), currentSchemaVersion: target.schemaVersion),
    );
    expect(await target.select(target.manualExercises).get(), isEmpty);
    expect(await target.select(target.weighIns).get(), hasLength(1));
  });

  group('rejects', () {
    Matcher message(String text) => isA<ImportException>().having(
      (e) => e.message,
      'message',
      contains(text),
    );

    ParsedExport parse(String text) =>
        parseExport(text, currentSchemaVersion: target.schemaVersion);

    test('a file that is not JSON', () {
      expect(() => parse('hello'), throwsA(message("isn't a Nutrition")));
    });

    test('JSON from something else', () {
      expect(
        () => parse(jsonEncode({'app': 'other', 'tables': {}})),
        throwsA(message("isn't a Nutrition")),
      );
    });

    test('a backup from a newer app version', () async {
      final data = jsonDecode(await exportText(source)) as Map<String, dynamic>;
      data['schemaVersion'] = target.schemaVersion + 1;
      expect(() => parse(jsonEncode(data)), throwsA(message('newer version')));
    });

    test('a row with a missing field, before touching the database', () async {
      await seedEverything(source);
      final data = jsonDecode(await exportText(source)) as Map<String, dynamic>;
      final weighIns = (data['tables'] as Map)['weigh_ins'] as List;
      (weighIns.single as Map).remove('weightKg');
      expect(() => parse(jsonEncode(data)), throwsA(message('damaged')));
    });
  });

  test('a failed restore leaves the device data unchanged', () async {
    await seedEverything(source);
    final data = jsonDecode(await exportText(source)) as Map<String, dynamic>;
    // A log entry pointing at a food that isn't in the file: only the
    // foreign key check at commit catches it.
    final entries = (data['tables'] as Map)['food_log_entries'] as List;
    (entries.single as Map)['foodId'] = 999;
    final export = parseExport(
      jsonEncode(data),
      currentSchemaVersion: target.schemaVersion,
    );

    await target
        .into(target.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-01-01',
            weightKg: 99,
            createdAt: now,
          ),
        );
    await expectLater(restoreExport(target, export), throwsA(anything));
    final days = await target.select(target.weighIns).get();
    expect(days.map((w) => w.dayKey), ['2026-01-01']);
  });
}
