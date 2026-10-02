import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/widget_home/home_widget_sync.dart';

import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  late AppDatabase db;
  late DateTime now;
  late ProviderContainer container;
  late List<MethodCall> calls;

  setUp(() {
    db = openTestDatabase();
    now = DateTime(2026, 9, 25, 10, 30);
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'saveWidgetData') return true;
          if (call.method == 'updateWidget') return true;
          return null;
        });
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    container.dispose();
    await db.close();
  });

  Future<void> syncNow() =>
      container.read(homeWidgetSyncProvider.notifier).syncNow();

  String? textArg(String method, String key) {
    for (final call in calls) {
      if (call.method == method && call.arguments['id'] == key) {
        return call.arguments['data'] as String?;
      }
    }
    return null;
  }

  test('no profile yet shows a setup placeholder and no steps', () async {
    await syncNow();

    expect(textArg('saveWidgetData', 'kcalLeftText'), 'Set up your targets');
    expect(textArg('saveWidgetData', 'stepsText'), 'No step data');
    expect(
      calls.where((c) => c.method == 'updateWidget'),
      isNotEmpty,
    );
    expect(container.read(homeWidgetSyncProvider).value, now);
  });

  test('computes remaining kcal and steps from the day\'s data', () async {
    await db
        .into(db.targetHistory)
        .insert(
          TargetHistoryCompanion.insert(
            effectiveFrom: '2026-09-25',
            kcal: 2200,
            proteinG: 150,
            fatG: 70,
            carbsG: 220,
            maintenanceKcal: 2400,
            method: 0,
            createdAt: now,
          ),
        );
    final foodId = await db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            source: 'custom',
            name: 'Chicken and rice',
            kcalPer100g: 165,
            proteinPer100g: 31,
            fatPer100g: 3.6,
            carbsPer100g: 0,
            createdAt: now,
          ),
        );
    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            dayKey: '2026-09-25',
            meal: 0,
            foodId: foodId,
            grams: 100,
            kcal: 1650, // comfortably below the 2200 target
            proteinG: 0,
            fatG: 0,
            carbsG: 0,
            createdAt: now,
          ),
        );
    await db
        .into(db.dailySteps)
        .insertOnConflictUpdate(
          DailyStepsCompanion.insert(
            dayKey: '2026-09-25',
            steps: 8432,
            syncedAt: now,
          ),
        );

    await syncNow();

    expect(textArg('saveWidgetData', 'kcalLeftText'), '550 kcal left');
    expect(textArg('saveWidgetData', 'stepsText'), '8,432 steps');
  });

  test('syncNow never throws even if the platform channel fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });

    await syncNow(); // must not throw

    expect(container.read(homeWidgetSyncProvider).hasError, isFalse);
    expect(container.read(homeWidgetSyncProvider).value, now);
  });
}
