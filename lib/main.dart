// App entry point: opens the on-device database and starts the app inside a
// ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/db/database.dart';
import 'features/activity/walk_reminder_background.dart';
import 'features/activity/walk_reminder_notifications.dart';

/// Opens the SQLite database and injects it via [databaseProvider].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.defaults();
  await initWalkReminderNotifications();
  await Workmanager().initialize(walkReminderCallbackDispatcher);
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const NutritionApp(),
    ),
  );
}
