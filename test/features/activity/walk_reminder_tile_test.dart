import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/features/activity/walk_reminder_providers.dart';
import 'package:nutrition_app/features/activity/walk_reminder_repository.dart';
import 'package:nutrition_app/features/activity/walk_reminder_scheduler.dart';
import 'package:nutrition_app/features/activity/widgets/walk_reminder_tile.dart';

import '../../helpers/test_db.dart';

/// Records what the settings tile asks it to schedule, without touching the
/// real WorkManager platform channel.
class FakeScheduler implements WalkReminderScheduler {
  WalkReminderSettings? applied;

  @override
  Future<void> apply(WalkReminderSettings settings) async {
    applied = settings;
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('off by default, with no time or threshold controls', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final scheduler = FakeScheduler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          walkReminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WalkReminderSettingsTile()),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Off'), findsOneWidget);
    expect(find.byKey(const Key('walkReminderTime')), findsNothing);
    expect(find.byKey(const Key('walkReminderThreshold')), findsNothing);
  });

  testWidgets('turning it on shows the time and threshold and persists', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final scheduler = FakeScheduler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          walkReminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WalkReminderSettingsTile()),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('walkReminderSwitch')));
    await settle(tester);

    expect(find.byKey(const Key('walkReminderTime')), findsOneWidget);
    expect(find.byKey(const Key('walkReminderThreshold')), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(scheduler.applied?.enabled, isTrue);

    final settings = await tester.runAsync(
      () => loadWalkReminderSettings(db),
    );
    expect(settings!.enabled, isTrue);
    expect(settings.hour, WalkReminderSettings.defaultHour);
    expect(settings.stepThreshold, WalkReminderSettings.defaultStepThreshold);
  });

  testWidgets('dragging the threshold slider saves the new value', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final scheduler = FakeScheduler();
    await tester.runAsync(
      () => saveWalkReminderSettings(
        db,
        const WalkReminderSettings(
          enabled: true,
          hour: 17,
          minute: 0,
          stepThreshold: 5000,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          walkReminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WalkReminderSettingsTile()),
        ),
      ),
    );
    await settle(tester);

    final slider = find.byKey(const Key('walkReminderThreshold'));
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(200, 0));
    await settle(tester);

    final settings = await tester.runAsync(
      () => loadWalkReminderSettings(db),
    );
    expect(settings!.stepThreshold, isNot(5000));
  });
}
