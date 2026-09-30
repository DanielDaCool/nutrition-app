// OWNER: Health Connect agent (C).
// The WorkManager background task: runs every ~15 minutes (Android's
// minimum periodic interval), and on each run decides whether today's walk
// reminder is due. All the decision logic lives in walk_reminder_logic.dart
// so it's covered by plain unit tests; this file is the untestable platform
// glue that wires it to Health Connect, the local DB and a notification.
import 'package:workmanager/workmanager.dart';

import '../../core/day_key.dart';
import '../../data/db/database.dart';
import 'health_package_source.dart';
import 'walk_reminder_logic.dart';
import 'walk_reminder_notifications.dart';
import 'walk_reminder_repository.dart';

/// Unique WorkManager task name for the walk reminder check.
const walkReminderTaskName = 'walkReminderCheck';

/// Registered with `Workmanager().initialize` in main(). Runs in its own
/// background isolate, so it opens its own DB connection and never throws
/// (an uncaught error would make WorkManager retry aggressively).
@pragma('vm:entry-point')
void walkReminderCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != walkReminderTaskName) return true;
    try {
      await _checkAndMaybeNotify();
    } catch (_) {
      // Never crash the background isolate over a failed check; it just
      // tries again on the next periodic run.
    }
    return true;
  });
}

Future<void> _checkAndMaybeNotify() async {
  final db = AppDatabase.defaults();
  try {
    final settings = await loadWalkReminderSettings(db);
    if (!settings.enabled) return;

    final now = DateTime.now();
    final todayKey = dayKeyOf(now);
    final lastSent = await lastWalkReminderSentDay(db);
    if (lastSent == todayKey) return;

    final steps = await _currentSteps(db, todayKey);
    if (!shouldSendWalkReminder(
      now: now,
      settings: settings,
      todayKey: todayKey,
      lastSentDayKey: lastSent,
      todaySteps: steps,
    )) {
      return;
    }

    await initWalkReminderNotifications();
    await sendWalkReminderIfMarkedSent(
      markSent: () => markWalkReminderSent(db, todayKey),
      notify: showWalkReminderNotification,
    );
  } finally {
    await db.close();
  }
}

/// Marks today's reminder sent, then shows it — never the other way around.
///
/// This background task opens its own DB connection, separate from any
/// foreground sync, so [markSent] can lose to SQLITE_BUSY. If it fails, this
/// skips [notify] for this run and lets the next periodic run retry, rather
/// than show the notification and then fail to record it — which could show
/// it again next run even though the user already saw (and maybe dismissed)
/// it. A top-level function (not inlined) so the ordering is covered by a
/// plain unit test, without a database or notification plugin.
Future<void> sendWalkReminderIfMarkedSent({
  required Future<void> Function() markSent,
  required Future<void> Function() notify,
}) async {
  await markSent();
  await notify();
}

/// Today's steps: a fresh Health Connect read when available, otherwise the
/// last value synced into the local DB.
///
/// A fresh read only happens with both the steps permission AND the
/// background-read permission granted: without the latter, Health Connect
/// refuses reads from a non-foreground app, so a read attempted here would
/// just fail (or, worse, silently return a stale/incomplete value) — going
/// straight to the local copy is both cheaper and no less accurate.
Future<int> _currentSteps(AppDatabase db, String todayKey) async {
  try {
    final source = HealthPackageSource();
    if (await source.hasStepsPermission() &&
        await source.isBackgroundAuthorized()) {
      final fresh = await source.totalSteps(
        startOfDay(todayKey),
        endOfDay(todayKey),
      );
      if (fresh != null) return fresh;
    }
  } catch (_) {
    // Fall back to the local copy below.
  }
  return storedStepsFor(db, todayKey);
}
