import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nutrition_app/data/db/database.dart';

/// Fresh in-memory database for a test. Close it in tearDown.
AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
