// App entry point: opens the on-device database and starts the app inside a
// ProviderScope.

import 'package:flutter/foundation.dart';
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
  // Notifications and background work are Android plugins with no web
  // implementation; calling them on web throws before runApp.
  if (!kIsWeb) {
    await initWalkReminderNotifications();
    // POST_NOTIFICATIONS is an app-wide permission, not per-channel — this used
    // to only be requested when the user enabled the walk reminder, so anyone
    // who never touched that setting never got asked, and the lock-screen
    // notification silently never showed. Ask once at startup instead.
    await requestWalkReminderPermission();
    await Workmanager().initialize(walkReminderCallbackDispatcher);
  }
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const NutritionApp(),
    ),
  );
}
