import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/walk_reminder_logic.dart';
import 'package:nutrition_app/features/activity/walk_reminder_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('missing settings load as defaults', () async {
    final settings = await loadWalkReminderSettings(db);
    expect(settings.enabled, WalkReminderSettings.defaults.enabled);
    expect(settings.hour, WalkReminderSettings.defaults.hour);
    expect(settings.minute, WalkReminderSettings.defaults.minute);
    expect(
      settings.stepThreshold,
      WalkReminderSettings.defaults.stepThreshold,
    );
  });

  test('saved settings round-trip', () async {
    const settings = WalkReminderSettings(
      enabled: true,
      hour: 8,
      minute: 30,
      stepThreshold: 7000,
    );
    await saveWalkReminderSettings(db, settings);
    final loaded = await loadWalkReminderSettings(db);
    expect(loaded.enabled, true);
    expect(loaded.hour, 8);
    expect(loaded.minute, 30);
    expect(loaded.stepThreshold, 7000);
  });

  test('last sent day starts null then updates', () async {
    expect(await lastWalkReminderSentDay(db), isNull);
    await markWalkReminderSent(db, '2026-09-26');
    expect(await lastWalkReminderSentDay(db), '2026-09-26');
    await markWalkReminderSent(db, '2026-09-27');
    expect(await lastWalkReminderSentDay(db), '2026-09-27');
  });

  test('stored steps default to 0 with no synced data', () async {
    expect(await storedStepsFor(db, '2026-09-26'), 0);
    await db
        .into(db.dailySteps)
        .insert(
          DailyStepsCompanion.insert(
            dayKey: '2026-09-26',
            steps: 4200,
            syncedAt: DateTime(2026, 9, 26),
          ),
        );
    expect(await storedStepsFor(db, '2026-09-26'), 4200);
  });
}
