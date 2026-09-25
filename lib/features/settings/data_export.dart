// OWNER: engine agent (A).
// Full-database JSON export, shared through the Android share sheet.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/day_key.dart';
import '../../data/db/database.dart';

/// All tables as `{table_name: [row, ...]}`. DateTimes are ISO-8601 strings.
///
/// Wrapped with `app`, `schemaVersion` and `exportedAt` ([now]) metadata.
Future<Map<String, Object?>> exportAllTables(
  AppDatabase db, {
  required DateTime now,
}) async {
  const serializer = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );
  final tables = <String, Object?>{};
  for (final table in db.allTables) {
    final rows = await db.select(table).get();
    tables[table.actualTableName] = [
      for (final row in rows)
        if (row is DataClass) row.toJson(serializer: serializer),
    ];
  }
  return {
    'app': 'nutrition_app',
    'schemaVersion': db.schemaVersion,
    'exportedAt': now.toIso8601String(),
    'tables': tables,
  };
}

/// Writes the export to a temp file and opens the Android share sheet.
///
/// The file is named after [now]'s day key. Errors (I/O, sharing) propagate
/// to the caller.
Future<ShareResult> shareExport(AppDatabase db, DateTime now) async {
  final data = await exportAllTables(db, now: now);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/nutrition-export-${dayKeyOf(now)}.json');
  await file.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Nutrition data export',
      title: 'Export data',
    ),
  );
}
