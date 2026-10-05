// OWNER: engine agent (A).
// Restores a full-database JSON export (see data_export.dart), replacing
// everything on this device. The one place that writes every table: a
// restore has to, so it bypasses the per-feature table owners on purpose.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/db/database.dart';

/// Why a file can't be imported. [message] is shown to the user as is.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;

  @override
  String toString() => 'ImportException: $message';
}

/// A parsed, validated export, ready to show to the user and restore.
class ParsedExport {
  ParsedExport._(this.schemaVersion, this.exportedAt, this._tables);

  /// Schema version of the app that wrote the file.
  final int schemaVersion;

  /// When the export was made, if the file says.
  final DateTime? exportedAt;

  /// Rows per table, already upgraded to the current schema's JSON shape.
  final Map<String, List<Map<String, dynamic>>> _tables;

  int rowCount(String table) => _tables[table]?.length ?? 0;
}

const _serializer = ValueSerializer.defaults(
  serializeDateTimeValuesAsString: true,
);

/// Turns one exported row (from `toJson`) back into an insertable row, per
/// table. Must list every table; a test checks it against `db.allTables`.
final Map<String, Insertable<Object?> Function(Map<String, dynamic>)>
_rowReaders = {
  'profiles': (j) => Profile.fromJson(j, serializer: _serializer),
  'foods': (j) => Food.fromJson(j, serializer: _serializer),
  'food_log_entries': (j) => FoodLogEntry.fromJson(j, serializer: _serializer),
  'saved_meals': (j) => SavedMeal.fromJson(j, serializer: _serializer),
  'saved_meal_items': (j) => SavedMealItem.fromJson(j, serializer: _serializer),
  'weigh_ins': (j) => WeighIn.fromJson(j, serializer: _serializer),
  'day_statuses': (j) => DayStatus.fromJson(j, serializer: _serializer),
  'daily_steps': (j) => DailyStep.fromJson(j, serializer: _serializer),
  'workouts': (j) => Workout.fromJson(j, serializer: _serializer),
  'manual_exercises': (j) =>
      ManualExercise.fromJson(j, serializer: _serializer),
  'target_history': (j) => TargetRecord.fromJson(j, serializer: _serializer),
  'key_values': (j) => KeyValue.fromJson(j, serializer: _serializer),
};

/// Tables the importer knows how to restore (for tests).
Iterable<String> get importableTables => _rowReaders.keys;

/// Parses and validates an export file's text for a database at
/// [currentSchemaVersion]. Throws [ImportException] with a user-facing
/// message if the file isn't a usable export.
ParsedExport parseExport(String text, {required int currentSchemaVersion}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const ImportException("That file isn't a Nutrition backup.");
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['app'] != 'nutrition_app' ||
      decoded['tables'] is! Map<String, dynamic>) {
    throw const ImportException("That file isn't a Nutrition backup.");
  }
  final version = decoded['schemaVersion'];
  if (version is! int || version < 1) {
    throw const ImportException("That backup file is damaged.");
  }
  if (version > currentSchemaVersion) {
    throw const ImportException(
      'That backup is from a newer version of the app. Update the app, '
      'then import it again.',
    );
  }

  final rawTables = decoded['tables'] as Map<String, dynamic>;
  final tables = <String, List<Map<String, dynamic>>>{};
  for (final name in _rowReaders.keys) {
    final rows = rawTables[name];
    if (rows == null) continue; // Table didn't exist in that version.
    if (rows is! List || rows.any((r) => r is! Map<String, dynamic>)) {
      throw const ImportException("That backup file is damaged.");
    }
    tables[name] = [for (final r in rows) Map.of(r as Map<String, dynamic>)];
  }
  _upgrade(tables, from: version);

  // Read every row now so a bad file fails here, before anything is deleted.
  for (final MapEntry(key: name, value: rows) in tables.entries) {
    for (final row in rows) {
      try {
        _rowReaders[name]!(row);
      } catch (_) {
        throw const ImportException("That backup file is damaged.");
      }
    }
  }

  return ParsedExport._(
    version,
    DateTime.tryParse(decoded['exportedAt'] as String? ?? '')?.toLocal(),
    tables,
  );
}

/// Brings rows written by an older schema up to the current one, mirroring
/// the steps in `AppDatabase.migration`. Columns a newer version added get
/// the same default the migration gives existing rows.
void _upgrade(
  Map<String, List<Map<String, dynamic>>> tables, {
  required int from,
}) {
  if (from < 3) {
    for (final row in tables['profiles'] ?? const <Map<String, dynamic>>[]) {
      row.putIfAbsent('goalDirection', () => 0);
    }
  }
}

/// Replaces every table's contents with [export], in one transaction: on any
/// error nothing changes.
Future<void> restoreExport(AppDatabase db, ParsedExport export) {
  return db.transaction(() async {
    // Rows go in table order, but foreign keys point both ways across the
    // delete/insert steps; checking them at commit keeps the order irrelevant.
    await db.customStatement('PRAGMA defer_foreign_keys = ON');
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
    for (final table in db.allTables) {
      final rows = export._tables[table.actualTableName];
      if (rows == null) continue;
      final read = _rowReaders[table.actualTableName]!;
      await db.batch(
        (b) => b.insertAll(table, [for (final r in rows) read(r)]),
      );
    }
  });
}
