// OWNER: Health Connect agent (C).
// Reads and writes the walk reminder's `hc.walkReminder*` KeyValues.
import '../../data/db/database.dart';
import 'walk_reminder_logic.dart';

const _enabledKey = 'hc.walkReminderEnabled';
const _hourKey = 'hc.walkReminderHour';
const _minuteKey = 'hc.walkReminderMinute';
const _thresholdKey = 'hc.walkReminderStepThreshold';

/// KeyValues key: day key the last reminder notification was sent on.
const walkReminderLastSentDayKey = 'hc.walkReminderLastSentDay';

/// Loads the walk reminder settings, falling back to [WalkReminderSettings.defaults]
/// for any key that isn't stored yet.
Future<WalkReminderSettings> loadWalkReminderSettings(AppDatabase db) async {
  final rows = await (db.select(db.keyValues)..where(
        (t) => t.key.isIn([_enabledKey, _hourKey, _minuteKey, _thresholdKey]),
      ))
      .get();
  final byKey = {for (final r in rows) r.key: r.value};
  final d = WalkReminderSettings.defaults;
  return WalkReminderSettings(
    enabled: byKey[_enabledKey] == 'true',
    hour: int.tryParse(byKey[_hourKey] ?? '') ?? d.hour,
    minute: int.tryParse(byKey[_minuteKey] ?? '') ?? d.minute,
    stepThreshold: int.tryParse(byKey[_thresholdKey] ?? '') ?? d.stepThreshold,
  );
}

/// Persists [settings].
Future<void> saveWalkReminderSettings(
  AppDatabase db,
  WalkReminderSettings settings,
) => db.batch((b) {
  b.insertAllOnConflictUpdate(db.keyValues, [
    KeyValuesCompanion.insert(key: _enabledKey, value: '${settings.enabled}'),
    KeyValuesCompanion.insert(key: _hourKey, value: '${settings.hour}'),
    KeyValuesCompanion.insert(key: _minuteKey, value: '${settings.minute}'),
    KeyValuesCompanion.insert(
      key: _thresholdKey,
      value: '${settings.stepThreshold}',
    ),
  ]);
});

/// The day key the last reminder was sent on, or null if never sent.
Future<String?> lastWalkReminderSentDay(AppDatabase db) async {
  final row = await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(walkReminderLastSentDayKey))).getSingleOrNull();
  return row?.value;
}

/// Records that a reminder was sent for [dayKey].
Future<void> markWalkReminderSent(AppDatabase db, String dayKey) => db
    .into(db.keyValues)
    .insertOnConflictUpdate(
      KeyValuesCompanion.insert(
        key: walkReminderLastSentDayKey,
        value: dayKey,
      ),
    );

/// Steps stored for [dayKey] in the local DailySteps copy, or 0 if none.
Future<int> storedStepsFor(AppDatabase db, String dayKey) async {
  final row = await (db.select(
    db.dailySteps,
  )..where((t) => t.dayKey.equals(dayKey))).getSingleOrNull();
  return row?.steps ?? 0;
}
