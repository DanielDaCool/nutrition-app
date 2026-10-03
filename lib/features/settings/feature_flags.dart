// OWNER: engine agent (A).
// Feature flags: which AppFeatures the user switched off on this device.
// Stored in KeyValues under `feature.<storageKey>` ('1' on, '0' off).

import 'package:drift/drift.dart' show StringExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../data/db/database.dart';

const _prefix = 'feature.';

/// Loads the stored on/off choices. A feature the user never touched is not
/// in the map (it counts as on); keys of features this build doesn't know
/// are ignored.
Future<Map<AppFeature, bool>> loadFeatureFlags(AppDatabase db) async {
  final rows = await (db.select(
    db.keyValues,
  )..where((t) => t.key.like('$_prefix%'))).get();
  final byKey = {
    for (final f in AppFeature.values) '$_prefix${f.storageKey}': f,
  };
  final flags = <AppFeature, bool>{};
  for (final row in rows) {
    final feature = byKey[row.key];
    if (feature == null) continue;
    if (row.value == '1') flags[feature] = true;
    if (row.value == '0') flags[feature] = false;
  }
  return flags;
}

/// Persists whether [feature] is switched on.
Future<void> saveFeatureFlag(
  AppDatabase db,
  AppFeature feature,
  bool enabled,
) => db
    .into(db.keyValues)
    .insertOnConflictUpdate(
      KeyValuesCompanion.insert(
        key: '$_prefix${feature.storageKey}',
        value: enabled ? '1' : '0',
      ),
    );

/// The flags as stored when the app started. Overridden in main() with the
/// values loaded before `runApp`, so nothing the user switched off flashes
/// on screen at startup. Not overridden (tests): everything is on.
final initialFeatureFlagsProvider = Provider<Map<AppFeature, bool>>(
  (ref) => const {},
);

/// The user's on/off choices; a feature missing from the map follows its
/// [AppFeature.defaultEnabled].
final featureFlagsProvider =
    NotifierProvider<FeatureFlags, Map<AppFeature, bool>>(FeatureFlags.new);

/// Holds the feature flags and saves changes to the database.
class FeatureFlags extends Notifier<Map<AppFeature, bool>> {
  @override
  Map<AppFeature, bool> build() => ref.read(initialFeatureFlagsProvider);

  /// Switches [feature] on or off. The state changes at once; if saving
  /// fails the previous choice is restored and the error is rethrown.
  Future<void> setEnabled(AppFeature feature, bool enabled) async {
    final db = ref.read(databaseProvider);
    final previous = state[feature];
    state = {...state, feature: enabled};
    try {
      await saveFeatureFlag(db, feature, enabled);
    } catch (_) {
      final restored = {...state};
      if (previous == null) {
        restored.remove(feature);
      } else {
        restored[feature] = previous;
      }
      state = restored;
      rethrow;
    }
  }
}

/// Whether [AppFeature]'s UI should show: it exists on this platform and the
/// user hasn't switched it off.
final featureEnabledProvider = Provider.family<bool, AppFeature>(
  (ref, feature) =>
      feature.availableOn(isWeb: ref.watch(isWebProvider)) &&
      (ref.watch(featureFlagsProvider)[feature] ?? feature.defaultEnabled),
);
