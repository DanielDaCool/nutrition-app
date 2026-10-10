import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/activity/health_source.dart';
import 'package:nutrition_app/features/activity/step_goal_logic.dart';
import 'package:nutrition_app/features/activity/step_goal_repository.dart';
import 'package:nutrition_app/features/activity/widgets/activity_card.dart';
import 'package:nutrition_app/features/activity/widgets/health_connect_tile.dart';

import '../../helpers/test_db.dart';
import 'fake_health_source.dart';

void main() {
  late AppDatabase db;
  late FakeHealthSource source;
  final now = DateTime(2026, 9, 25, 10, 30);

  setUp(() {
    db = openTestDatabase();
    source = FakeHealthSource();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          healthSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    // Let drift stream subscriptions close before the DB does.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('ActivityCard', () {
    testWidgets('shows steps and workouts', (tester) async {
      await tester.runAsync(() async {
        await db
            .into(db.dailySteps)
            .insert(
              DailyStepsCompanion.insert(
                dayKey: '2026-09-25',
                steps: 8432,
                syncedAt: now,
              ),
            );
        await db
            .into(db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                id: 'w1',
                dayKey: '2026-09-25',
                title: 'Chest and back',
                startTime: DateTime(2026, 9, 25, 7),
                endTime: DateTime(2026, 9, 25, 8, 12),
                sourceApp: const Value('com.hevy'),
                syncedAt: now,
              ),
            );
      });
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));

      expect(find.text('8,432'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
      expect(find.byKey(const Key('stepGoalProgress')), findsOneWidget);
      expect(find.text('Chest and back · 1 h 12 min'), findsOneWidget);
      expect(find.text('from Hevy'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the step goal section with zero steps synced', (
      tester,
    ) async {
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows active calories when Health Connect reports them', (
      tester,
    ) async {
      source.activeCaloriesByDay['2026-09-25'] = 234;
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));
      expect(find.text('234 kcal'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('steps and calories row does not overflow on a narrow phone', (
      tester,
    ) async {
      // Regression: a Row with no Flexible/Expanded overflowed by ~160px at
      // this width with realistic (not even extreme) step/calorie values.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await db
            .into(db.dailySteps)
            .insert(
              DailyStepsCompanion.insert(
                dayKey: '2026-09-25',
                steps: 15234,
                syncedAt: now,
              ),
            );
      });
      source.activeCaloriesByDay['2026-09-25'] = 842;
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));

      expect(tester.takeException(), isNull);
      expect(find.text('15,234'), findsOneWidget);
      expect(find.text('842 kcal'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('omits calories when Health Connect has no permission', (
      tester,
    ) async {
      source.permissionsGranted = false;
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));
      expect(find.byIcon(Icons.local_fire_department), findsNothing);
      await unmount(tester);
    });

    testWidgets('progress bar reflects steps over the goal', (tester) async {
      await tester.runAsync(() async {
        await saveStepGoalSettings(db, const StepGoalSettings(stepGoal: 5000));
        await db
            .into(db.dailySteps)
            .insert(
              DailyStepsCompanion.insert(
                dayKey: '2026-09-25',
                steps: 2500,
                syncedAt: now,
              ),
            );
      });
      await pump(tester, const ActivityCard(dayKey: '2026-09-25'));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('stepGoalProgress')),
      );
      expect(bar.value, closeTo(0.5, 0.0001));
      expect(find.text('Goal: 5,000 steps'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('workout without steps still shows the goal section', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await db
            .into(db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                id: 'w1',
                dayKey: '2026-09-24',
                title: 'Strength training',
                startTime: DateTime(2026, 9, 24, 18),
                endTime: DateTime(2026, 9, 24, 18, 45),
                syncedAt: now,
              ),
            );
      });
      await pump(tester, const ActivityCard(dayKey: '2026-09-24'));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Strength training · 45 min'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('HealthConnectSettingsTile', () {
    testWidgets('needs permission: Connect requests access and syncs', (
      tester,
    ) async {
      source.permissionsGranted = false;
      await pump(tester, const HealthConnectSettingsTile());
      await tester.runAsync(() async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HealthConnectSettingsTile)),
        );
        await container.read(healthSyncProvider.notifier).syncNow();
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Not connected'), findsOneWidget);
      expect(find.text('Never synced'), findsOneWidget);

      await tester.tap(find.text('Connect'));
      await tester.pump();
      // Let the async permission + sync chain finish on real time.
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && source.workoutCalls.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(source.requestPermissionCalls, 1);
      expect(find.textContaining('Connected'), findsOneWidget);
      expect(find.text('Last sync: today 10:30'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('offers install when Health Connect is missing', (
      tester,
    ) async {
      source.availabilityValue = HcAvailability.notInstalled;
      await pump(tester, const HealthConnectSettingsTile());
      await tester.runAsync(() async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HealthConnectSettingsTile)),
        );
        await container.read(healthSyncProvider.notifier).syncNow();
      });
      await tester.pumpAndSettle();
      expect(find.text('Health Connect is not installed.'), findsOneWidget);
      await tester.tap(find.text('Install Health Connect'));
      await tester.pump();
      expect(source.installCalls, 1);
      await unmount(tester);
    });
  });
}
