// OWNER: Health Connect agent (C).
// Pure decision logic for the daily walk reminder, kept free of Flutter/DB
// imports so it's unit-testable without a database or platform channel.
library;

/// Settings for the daily walk reminder, stored as `hc.walkReminder*`
/// KeyValues.
class WalkReminderSettings {
  const WalkReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.stepThreshold,
  });

  static const defaultHour = 17;
  static const defaultMinute = 0;
  static const defaultStepThreshold = 5000;

  static const defaults = WalkReminderSettings(
    enabled: false,
    hour: defaultHour,
    minute: defaultMinute,
    stepThreshold: defaultStepThreshold,
  );

  /// Whether the reminder is turned on.
  final bool enabled;

  /// Local time of day (24h) the reminder may fire at or after.
  final int hour;
  final int minute;

  /// Steps below which a reminder is sent.
  final int stepThreshold;

  WalkReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? stepThreshold,
  }) => WalkReminderSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    stepThreshold: stepThreshold ?? this.stepThreshold,
  );
}

/// True when, at [now], a walk reminder should fire: reminders are on, the
/// reminder time for today has passed, today's steps are still under the
/// threshold, and none was already sent today ([lastSentDayKey] != [todayKey]).
bool shouldSendWalkReminder({
  required DateTime now,
  required WalkReminderSettings settings,
  required String todayKey,
  required String? lastSentDayKey,
  required int todaySteps,
}) {
  if (!settings.enabled) return false;
  if (lastSentDayKey == todayKey) return false;
  final reminderTime = DateTime(
    now.year,
    now.month,
    now.day,
    settings.hour,
    settings.minute,
  );
  if (now.isBefore(reminderTime)) return false;
  if (todaySteps >= settings.stepThreshold) return false;
  return true;
}
