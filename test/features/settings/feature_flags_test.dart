import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/settings/feature_flags.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> put(String key, String value) => db
      .into(db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion.insert(key: key, value: value),
      );

  group('repository', () {
    test('a fresh database has no flags', () async {
      expect(await loadFeatureFlags(db), isEmpty);
    });

    test('save then load round-trips off and on', () async {
      await saveFeatureFlag(db, AppFeature.recipes, false);
      expect(await loadFeatureFlags(db), {AppFeature.recipes: false});

      await saveFeatureFlag(db, AppFeature.activity, true);
      await saveFeatureFlag(db, AppFeature.recipes, true);
      expect(await loadFeatureFlags(db), {
        AppFeature.recipes: true,
        AppFeature.activity: true,
      });

      final row = await (db.select(
        db.keyValues,
      )..where((t) => t.key.equals('feature.recipes'))).getSingle();
      expect(row.value, '1');
    });

    test(
      'unknown feature keys, odd values and other keys are ignored',
      () async {
        await put('feature.somethingFromANewerBuild', '0');
        await put('feature.recipes', 'maybe');
        await put('hc.stepGoal', '0');
        await put('feature.barcodeScan', '0');
        expect(await loadFeatureFlags(db), {AppFeature.barcodeScan: false});
      },
    );
  });

  group('providers', () {
    ProviderContainer container({
      bool isWeb = false,
      Map<AppFeature, bool>? initial,
    }) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          isWebProvider.overrideWithValue(isWeb),
          if (initial != null)
            initialFeatureFlagsProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('every feature is on by default', () {
      final c = container();
      for (final f in AppFeature.values) {
        expect(c.read(featureEnabledProvider(f)), isTrue, reason: f.name);
      }
    });

    test('setEnabled flips the feature and persists it', () async {
      final c = container();
      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(AppFeature.recipes, false);
      expect(c.read(featureEnabledProvider(AppFeature.recipes)), isFalse);
      expect(c.read(featureEnabledProvider(AppFeature.activity)), isTrue);
      expect(await loadFeatureFlags(db), {AppFeature.recipes: false});

      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(AppFeature.recipes, true);
      expect(c.read(featureEnabledProvider(AppFeature.recipes)), isTrue);
      expect(await loadFeatureFlags(db), {AppFeature.recipes: true});
    });

    test('an Android-only feature is off on web even when its flag is on', () {
      final c = container(isWeb: true, initial: {AppFeature.activity: true});
      expect(c.read(featureEnabledProvider(AppFeature.activity)), isFalse);
      expect(c.read(featureEnabledProvider(AppFeature.recipes)), isTrue);
    });

    test('the initial flags override is honored', () {
      final c = container(
        initial: {AppFeature.yesterdayPrompt: false, AppFeature.recipes: true},
      );
      expect(
        c.read(featureEnabledProvider(AppFeature.yesterdayPrompt)),
        isFalse,
      );
      expect(c.read(featureEnabledProvider(AppFeature.recipes)), isTrue);
      expect(c.read(featureEnabledProvider(AppFeature.barcodeScan)), isTrue);
    });

    test('a failed save restores the previous choice and rethrows', () async {
      // Without its table every write fails.
      await db.customStatement('DROP TABLE ${db.keyValues.actualTableName}');
      final c = container(initial: {AppFeature.barcodeScan: false});
      final flags = c.read(featureFlagsProvider.notifier);

      await expectLater(
        flags.setEnabled(AppFeature.recipes, false),
        throwsA(anything),
      );
      expect(c.read(featureFlagsProvider), {AppFeature.barcodeScan: false});
      expect(c.read(featureEnabledProvider(AppFeature.recipes)), isTrue);

      await expectLater(
        flags.setEnabled(AppFeature.barcodeScan, true),
        throwsA(anything),
      );
      expect(c.read(featureFlagsProvider), {AppFeature.barcodeScan: false});
    });
  });
}
