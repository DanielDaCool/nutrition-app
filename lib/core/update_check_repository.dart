// Reads and writes the update check's `app.update*` KeyValues, and asks
// GitHub for the latest release tag.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/db/database.dart';
import 'update_check.dart';

const _checkedAtKey = 'app.updateCheckedAt';
const _latestTagKey = 'app.updateLatestTag';
const _dismissedTagKey = 'app.updateDismissedTag';

const _releaseUrl =
    'https://api.github.com/repos/DanielDaCool/nutrition-app/releases/latest';
const _userAgent =
    'NutritionApp (+https://github.com/DanielDaCool/nutrition-app)';

Future<String?> _loadKey(AppDatabase db, String key) async {
  final row = await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
  return row?.value;
}

/// When the last check ran, or null if never.
Future<DateTime?> loadUpdateCheckedAt(AppDatabase db) async {
  final value = await _loadKey(db, _checkedAtKey);
  return value == null ? null : DateTime.tryParse(value)?.toUtc();
}

/// The tag this device last dismissed the banner for, or null.
Future<String?> loadUpdateDismissedTag(AppDatabase db) =>
    _loadKey(db, _dismissedTagKey);

/// Records that [tag]'s update banner was dismissed.
Future<void> saveUpdateDismissedTag(AppDatabase db, String tag) => db
    .into(db.keyValues)
    .insertOnConflictUpdate(
      KeyValuesCompanion.insert(key: _dismissedTagKey, value: tag),
    );

/// Asks GitHub for the latest release tag if it's been at least a day since
/// the last check ([shouldCheckForUpdate]); otherwise returns the tag from
/// the last successful check. Never throws: a network, HTTP or parse
/// failure is swallowed and the previously known tag (or null) comes back,
/// same as if nothing had changed.
Future<String?> latestReleaseTag(
  AppDatabase db,
  http.Client client,
  DateTime now,
) async {
  final lastChecked = await loadUpdateCheckedAt(db);
  final cachedTag = await _loadKey(db, _latestTagKey);
  if (!shouldCheckForUpdate(lastCheckedAt: lastChecked, now: now)) {
    return cachedTag;
  }
  String? tag = cachedTag;
  try {
    final response = await client
        .get(
          Uri.parse(_releaseUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': _userAgent,
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['tag_name'] is String) {
        tag = body['tag_name'] as String;
      }
    }
  } catch (_) {
    // No connection, timeout, bad JSON: try again after the next interval.
  }
  await db.batch((b) {
    b.insertAllOnConflictUpdate(db.keyValues, [
      KeyValuesCompanion.insert(
        key: _checkedAtKey,
        value: now.toUtc().toIso8601String(),
      ),
      if (tag != null)
        KeyValuesCompanion.insert(key: _latestTagKey, value: tag),
    ]);
  });
  return tag;
}
