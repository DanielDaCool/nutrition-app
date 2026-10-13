// Reads and writes which features the user has switched off. Pure Drift: no
// Flutter imports. The choice lives in one KeyValues row, so it travels with
// backups like any other KeyValues row.
import '../data/db/database.dart';
import 'app_features.dart';

/// KeyValues key: comma-separated, sorted storage keys of the features the
/// user has switched off. No row means every feature is on.
const disabledFeaturesKey = 'app.disabledFeatures';

Set<String> _parseDisabled(String? value) {
  if (value == null) return {};
  return {
    for (final key in value.split(','))
      if (key.isNotEmpty) key,
  };
}

/// Storage keys of the switched-off features, updated whenever the choice
/// changes (including by a restore).
Stream<Set<String>> watchDisabledFeatureKeys(AppDatabase db) {
  final query = db.select(db.keyValues)
    ..where((t) => t.key.equals(disabledFeaturesKey));
  return query.watchSingleOrNull().map((row) => _parseDisabled(row?.value));
}

/// Switches [feature] on or off. Keys this build doesn't know are kept as
/// they are. When nothing is switched off the row is deleted.
Future<void> setFeatureEnabled(
  AppDatabase db,
  AppFeature feature,
  bool enabled,
) {
  return db.transaction(() async {
    final query = db.select(db.keyValues)
      ..where((t) => t.key.equals(disabledFeaturesKey));
    final row = await query.getSingleOrNull();
    final disabled = _parseDisabled(row?.value);
    if (enabled) {
      disabled.remove(feature.storageKey);
    } else {
      disabled.add(feature.storageKey);
    }
    if (disabled.isEmpty) {
      final delete = db.delete(db.keyValues)
        ..where((t) => t.key.equals(disabledFeaturesKey));
      await delete.go();
      return;
    }
    final sorted = disabled.toList()..sort();
    await db
        .into(db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion.insert(
            key: disabledFeaturesKey,
            value: sorted.join(','),
          ),
        );
  });
}
