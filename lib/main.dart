// App entry point: opens the on-device database and starts the app inside a
// ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/db/database.dart';

/// Opens the SQLite database and injects it via [databaseProvider].
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.defaults();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const NutritionApp(),
    ),
  );
}
