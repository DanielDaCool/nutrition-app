// OWNER: Health Connect agent (C).
// Riverpod providers for the walk reminder settings and its scheduler.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'walk_reminder_logic.dart';
import 'walk_reminder_notifications.dart';
import 'walk_reminder_repository.dart';
import 'walk_reminder_scheduler.dart';

export 'walk_reminder_logic.dart' show WalkReminderSettings;

/// Registers/cancels the periodic background check. Override with a fake in
/// tests so they don't touch the WorkManager platform channel.
final walkReminderSchedulerProvider = Provider<WalkReminderScheduler>(
  (ref) => WorkManagerWalkReminderScheduler(),
);

/// The walk reminder's settings, loaded from KeyValues.
final walkReminderSettingsProvider =
    AsyncNotifierProvider<WalkReminderSettingsController, WalkReminderSettings>(
      WalkReminderSettingsController.new,
    );

/// Holds the walk reminder settings; [update] persists them, then
/// (re)schedules the background check and, when turning it on, asks for the
/// Android 13+ notification permission.
class WalkReminderSettingsController
    extends AsyncNotifier<WalkReminderSettings> {
  @override
  FutureOr<WalkReminderSettings> build() =>
      loadWalkReminderSettings(ref.watch(databaseProvider));

  /// Persists [settings], then (re)schedules the background check. Named
  /// `save` (not `update`) to avoid colliding with [AsyncNotifier.update].
  Future<void> save(WalkReminderSettings settings) async {
    await saveWalkReminderSettings(ref.read(databaseProvider), settings);
    state = AsyncData(settings);
    try {
      await ref.read(walkReminderSchedulerProvider).apply(settings);
    } catch (_) {
      // The reminder still works next time the app is opened, or once the
      // user retries the toggle; nothing to surface here.
    }
    if (settings.enabled) {
      try {
        await requestWalkReminderPermission();
      } catch (_) {}
    }
  }
}
