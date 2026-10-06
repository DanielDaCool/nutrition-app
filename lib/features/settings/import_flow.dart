// OWNER: engine agent (A).
// The "Import data" flow shared by Settings and first-run setup: pick a
// backup file, check it, confirm, then replace everything with it.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import 'data_import.dart';

/// Opens the system file picker and returns the chosen file's text, or null
/// if the user cancelled. Overridden in tests.
final pickBackupTextProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    // Any file type: Android often labels a shared .json as
    // application/octet-stream, which a JSON-only filter would hide.
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  },
);

/// Runs the whole import, reporting problems in a snackbar. Returns true if
/// a backup was restored.
Future<bool> runImport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final db = ref.read(databaseProvider);
  final ParsedExport export;
  try {
    final text = await ref.read(pickBackupTextProvider)();
    if (text == null) return false;
    export = parseExport(text, currentSchemaVersion: db.schemaVersion);
  } on ImportException catch (e) {
    say(e.message);
    return false;
  } on FormatException {
    // Not UTF-8 text at all, e.g. a photo.
    say("That file isn't a Nutrition backup.");
    return false;
  } catch (e, s) {
    debugPrint('Reading backup failed: $e\n$s');
    say("Couldn't open that file");
    return false;
  }

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmImportDialog(export: export),
  );
  if (confirmed != true) return false;

  try {
    await restoreExport(db, export);
  } catch (e, s) {
    debugPrint('Restoring backup failed: $e\n$s');
    say("Couldn't restore the backup. Your data wasn't changed.");
    return false;
  }
  say('Backup restored');
  return true;
}

class _ConfirmImportDialog extends StatelessWidget {
  const _ConfirmImportDialog({required this.export});
  final ParsedExport export;

  @override
  Widget build(BuildContext context) {
    final at = export.exportedAt;
    final made = at == null
        ? 'This backup'
        : 'This backup from ${DateFormat.yMMMd().add_jm().format(at)}';
    final weighIns = export.rowCount('weigh_ins');
    final foods = export.rowCount('food_log_entries');
    return AlertDialog(
      title: const Text('Replace your data?'),
      content: Text(
        '$made has $weighIns weigh-ins and $foods logged foods.\n\n'
        'Importing it replaces everything on this device. Anything you '
        "logged here that isn't in the backup will be lost.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirmImport'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Replace'),
        ),
      ],
    );
  }
}
