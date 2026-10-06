// OWNER: engine agent (A).
// Full-database JSON export, shared through the system share sheet (on web,
// the browser's, falling back to a download).

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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

/// Opens the share sheet with the export as a JSON file. On Android the file
/// is written to a temp directory first; the web has no file system, so it
/// shares the bytes and the browser downloads them if it can't share files.
///
/// The file is named after [now]'s day key. Errors (I/O, sharing) propagate
/// to the caller.
Future<ShareResult> shareExport(AppDatabase db, DateTime now) async {
  final data = await exportAllTables(db, now: now);
  final name = 'nutrition-export-${dayKeyOf(now)}.json';
  final text = const JsonEncoder.withIndent(' ').convert(data);
  final XFile file;
  if (kIsWeb) {
    file = XFile.fromData(
      utf8.encode(text),
      name: name,
      mimeType: 'application/json',
    );
  } else {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';
    await File(path).writeAsString(text);
    file = XFile(path, mimeType: 'application/json');
  }
  return SharePlus.instance.share(
    ShareParams(
      files: [file],
      fileNameOverrides: [name],
      subject: 'Nutrition data export',
      title: 'Export data',
    ),
  );
}
