// OWNER: Health Connect agent (C).
// Registers/cancels the periodic WorkManager task behind an interface, so
// providers can be tested with a fake instead of touching a platform channel.
import 'package:workmanager/workmanager.dart';

import 'walk_reminder_background.dart';
import 'walk_reminder_logic.dart';

/// Registers the periodic background check for the walk reminder.
abstract interface class WalkReminderScheduler {
  /// Registers or cancels the periodic check to match [settings].
  Future<void> apply(WalkReminderSettings settings);
}

/// [WalkReminderScheduler] backed by the `workmanager` plugin. Requires
/// `Workmanager().initialize(walkReminderCallbackDispatcher)` to have run in
/// main() first.
class WorkManagerWalkReminderScheduler implements WalkReminderScheduler {
  /// WorkManager's minimum interval for periodic tasks.
  static const _checkInterval = Duration(minutes: 15);
  static const _uniqueName = 'walk-reminder-check';

  @override
  Future<void> apply(WalkReminderSettings settings) async {
    if (!settings.enabled) {
      await Workmanager().cancelByUniqueName(_uniqueName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      walkReminderTaskName,
      frequency: _checkInterval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }
}
