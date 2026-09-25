import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nutrition_app/data/db/database.dart';

/// Fresh in-memory database for a test. Close it in tearDown.
///
/// closeStreamsSynchronously: drift normally closes a watched query one
/// event-loop turn after its last listener leaves. In widget tests that turn
/// is a fake timer that never fires, which fails the test and hangs close().
AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}
