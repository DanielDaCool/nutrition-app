// Reads and writes the install hint's `app.installHintDismissedAt` KeyValue.
import '../data/db/database.dart';
import 'install_hint.dart';

/// When the install hint was last dismissed, or null if never.
Future<DateTime?> loadInstallHintDismissedAt(AppDatabase db) async {
  final row = await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(installHintDismissedAtKey))).getSingleOrNull();
  if (row == null) return null;
  return DateTime.tryParse(row.value)?.toUtc();
}

/// Records that the install hint was dismissed at [now].
Future<void> saveInstallHintDismissedAt(AppDatabase db, DateTime now) => db
    .into(db.keyValues)
    .insertOnConflictUpdate(
      KeyValuesCompanion.insert(
        key: installHintDismissedAtKey,
        value: now.toUtc().toIso8601String(),
      ),
    );
