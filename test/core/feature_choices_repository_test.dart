import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/core/feature_choices_repository.dart';
import 'package:nutrition_app/data/db/database.dart';

import '../helpers/test_db.dart';

Future<String?> storedValue(AppDatabase db) async {
  final rows = await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(disabledFeaturesKey))).get();
  return rows.isEmpty ? null : rows.single.value;
}

void main() {
  test('the key is prefixed by the app owner', () {
    expect(disabledFeaturesKey, 'app.disabledFeatures');
  });

  test('nothing is switched off by default', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    expect(await watchDisabledFeatureKeys(db).first, isEmpty);
    expect(await storedValue(db), isNull);
  });

  test('switching off then on again, live through the stream', () async {
    final db = openTestDatabase();
    addTearDown(db.close);

    final off = watchDisabledFeatureKeys(db)
        .firstWhere((keys) => keys.contains('dashboard'));
    await setFeatureEnabled(db, AppFeature.dashboard, false);
    expect(await off, {'dashboard'});

    final on = watchDisabledFeatureKeys(db).firstWhere((keys) => keys.isEmpty);
    await setFeatureEnabled(db, AppFeature.dashboard, true);
    expect(await on, isEmpty);
  });

  test('keys are stored sorted and comma-separated', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await setFeatureEnabled(db, AppFeature.recipes, false);
    await setFeatureEnabled(db, AppFeature.dashboard, false);
    expect(await storedValue(db), 'dashboard,recipes');
    expect(await watchDisabledFeatureKeys(db).first, {'dashboard', 'recipes'});
  });

  test('unknown keys are preserved when a known feature changes', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await db
        .into(db.keyValues)
        .insert(
          KeyValuesCompanion.insert(
            key: disabledFeaturesKey,
            value: 'futureThing,dashboard',
          ),
        );
    await setFeatureEnabled(db, AppFeature.dashboard, true);
    expect(await storedValue(db), 'futureThing');
    expect(await watchDisabledFeatureKeys(db).first, {'futureThing'});

    await setFeatureEnabled(db, AppFeature.recipes, false);
    expect(await storedValue(db), 'futureThing,recipes');
  });

  test('switching the last feature back on deletes the row', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await setFeatureEnabled(db, AppFeature.walkReminders, false);
    expect(await storedValue(db), 'walkReminders');

    await setFeatureEnabled(db, AppFeature.walkReminders, true);
    expect(await storedValue(db), isNull);
    final rows = await db.select(db.keyValues).get();
    expect(rows, isEmpty);
  });

  test('switching off twice stores the key once', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await setFeatureEnabled(db, AppFeature.dashboard, false);
    await setFeatureEnabled(db, AppFeature.dashboard, false);
    expect(await storedValue(db), 'dashboard');
  });
}
