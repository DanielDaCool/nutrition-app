import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/activity/walk_reminder_logic.dart';

void main() {
  const enabled = WalkReminderSettings(
    enabled: true,
    hour: 17,
    minute: 0,
    stepThreshold: 5000,
  );

  test('fires after the reminder time when under the step threshold', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 26, 17, 1),
        settings: enabled,
        todayKey: '2026-09-26',
        lastSentDayKey: null,
        todaySteps: 3000,
      ),
      isTrue,
    );
  });

  test('does not fire before the reminder time', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 26, 16, 59),
        settings: enabled,
        todayKey: '2026-09-26',
        lastSentDayKey: null,
        todaySteps: 3000,
      ),
      isFalse,
    );
  });

  test('does not fire when the step threshold is already met', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 26, 18),
        settings: enabled,
        todayKey: '2026-09-26',
        lastSentDayKey: null,
        todaySteps: 5000,
      ),
      isFalse,
    );
  });

  test('does not fire twice in the same day', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 26, 18),
        settings: enabled,
        todayKey: '2026-09-26',
        lastSentDayKey: '2026-09-26',
        todaySteps: 100,
      ),
      isFalse,
    );
  });

  test('fires again the next day', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 27, 18),
        settings: enabled,
        todayKey: '2026-09-27',
        lastSentDayKey: '2026-09-26',
        todaySteps: 100,
      ),
      isTrue,
    );
  });

  test('never fires when disabled', () {
    expect(
      shouldSendWalkReminder(
        now: DateTime(2026, 9, 26, 18),
        settings: enabled.copyWith(enabled: false),
        todayKey: '2026-09-26',
        lastSentDayKey: null,
        todaySteps: 0,
      ),
      isFalse,
    );
  });

  test('copyWith only changes the given fields', () {
    final custom = enabled.copyWith(hour: 8, stepThreshold: 8000);
    expect(custom.hour, 8);
    expect(custom.stepThreshold, 8000);
    expect(custom.minute, enabled.minute);
    expect(custom.enabled, enabled.enabled);
  });
}
