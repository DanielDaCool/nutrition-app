// App entry point: opens the on-device database and starts the app inside a
// ProviderScope.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/app_features.dart';
import 'core/persistent_storage.dart';
import 'data/db/database.dart';
import 'features/activity/walk_reminder_background.dart';
import 'features/activity/walk_reminder_notifications.dart';
import 'features/settings/feature_flags.dart';

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
  // The whole database lives in browser storage on web; ask the browser not
  // to evict it. Not awaited, so it can never delay or break startup.
  if (kIsWeb) unawaited(requestPersistentStorage());
  // Loaded before the first frame so a feature the user switched off never
  // flashes on screen. If it fails, everything stays on.
  var featureFlags = const <AppFeature, bool>{};
  try {
    featureFlags = await loadFeatureFlags(db);
  } catch (e, s) {
    debugPrint('Loading feature flags failed: $e\n$s');
  }
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialFeatureFlagsProvider.overrideWithValue(featureFlags),
      ],
      child: const NutritionApp(),
    ),
  );
}
