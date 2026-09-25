import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/activity/health_source.dart';
import 'package:nutrition_app/features/activity/health_sync_service.dart';

import '../../helpers/test_db.dart';
import 'fake_health_source.dart';

void main() {
  late AppDatabase db;
  late FakeHealthSource source;
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    source = FakeHealthSource();
    now = DateTime(2026, 9, 25, 10, 30);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        healthSourceProvider.overrideWithValue(source),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> syncNow() =>
      container.read(healthSyncProvider.notifier).syncNow();

  Future<String?> kv(String key) async => (await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  HcWorkout workout(
    String id,
    DateTime start, {
    Duration length = const Duration(minutes: 72),
    String type = 'STRENGTH_TRAINING',
    String? title,
    double? kcal,
  }) => HcWorkout(
    id: id,
    start: start,
    end: start.add(length),
    activityType: type,
    title: title,
    sourceApp: 'com.hevy',
    kcal: kcal,
  );

  group('sync window', () {
    test('first sync reads the last 30 days without history access', () async {
      source.historyAuthorized = false;
      await syncNow();

      expect(source.stepCalls.first.$1, DateTime(2026, 8, 26));
      expect(source.stepCalls.last.$1, DateTime(2026, 9, 25));
      expect(source.stepCalls, hasLength(31));
      expect(source.workoutCalls.single, (
        DateTime(2026, 8, 26),
        DateTime(2026, 9, 26),
      ));
      expect(await kv('hc.lastSyncedDay'), '2026-09-25');
      expect(DateTime.parse((await kv('hc.lastSyncAt'))!).toLocal(), now);
      expect(container.read(healthSyncProvider).value, now);
      expect(container.read(healthStatusProvider).kind, HealthStatusKind.ok);
    });

    test('first sync reads 90 days when history access is granted', () async {
      source.historyAuthorized = true;
      await syncNow();
      expect(source.stepCalls.first.$1, DateTime(2026, 6, 27));
      expect(source.stepCalls, hasLength(91));
    });

    test('incremental sync re-reads from last synced day minus 2', () async {
      now = DateTime(2026, 9, 20, 9);
      await syncNow();
      source.stepCalls.clear();
      source.workoutCalls.clear();

      now = DateTime(2026, 9, 25, 21);
      await syncNow();
      expect(source.stepCalls.first.$1, DateTime(2026, 9, 18));
      expect(source.stepCalls.last.$1, DateTime(2026, 9, 25));
      expect(source.stepCalls, hasLength(8));
      expect(source.workoutCalls.single.$1, DateTime(2026, 9, 18));
      expect(await kv('hc.lastSyncedDay'), '2026-09-25');
    });

    test('long gap is clamped to what Health Connect allows', () async {
      await db
          .into(db.keyValues)
          .insert(
            KeyValuesCompanion.insert(
              key: 'hc.lastSyncedDay',
              value: '2026-01-01',
            ),
          );
      await syncNow();
      expect(source.stepCalls.first.$1, DateTime(2026, 8, 26));
    });

    test('state starts with the stored last sync time', () async {
      final t = DateTime(2026, 9, 24, 7, 15);
      await db
          .into(db.keyValues)
          .insert(
            KeyValuesCompanion.insert(
              key: 'hc.lastSyncAt',
              value: t.toUtc().toIso8601String(),
            ),
          );
      expect(await container.read(healthSyncProvider.future), t);
    });
  });

  group('upserts', () {
    test('syncing twice keeps one row per day and per workout', () async {
      source.stepsByDay['2026-09-24'] = 5000;
      source.workoutRecords.add(workout('w1', DateTime(2026, 9, 24, 18)));
      await syncNow();
      await syncNow();

      source.stepsByDay['2026-09-24'] = 6200;
      source.workoutRecords[0] = workout(
        'w1',
        DateTime(2026, 9, 24, 18),
        kcal: 310,
      );
      await syncNow();

      final steps = await db.select(db.dailySteps).get();
      expect(steps.single.dayKey, '2026-09-24');
      expect(steps.single.steps, 6200);

      final workouts = await db.select(db.workouts).get();
      expect(workouts, hasLength(1));
      final w = workouts.single;
      expect(w.id, 'w1');
      expect(w.dayKey, '2026-09-24');
      expect(w.title, 'Strength training');
      expect(w.activityType, 'STRENGTH_TRAINING');
      expect(w.sourceApp, 'com.hevy');
      expect(w.kcal, 310);
      expect(w.endTime.difference(w.startTime), const Duration(minutes: 72));
    });

    test('uses the session title when the source exposes one', () async {
      source.workoutRecords.add(
        workout('w1', DateTime(2026, 9, 24, 18), title: 'Chest and back'),
      );
      await syncNow();
      expect(
        (await db.select(db.workouts).getSingle()).title,
        'Chest and back',
      );
    });

    test('days that drop to 0 steps lose their row', () async {
      source.stepsByDay['2026-09-24'] = 5000;
      await syncNow();
      source.stepsByDay['2026-09-24'] = 0;
      await syncNow();
      expect(await db.select(db.dailySteps).get(), isEmpty);
    });

    test('a failed step read keeps the stored value', () async {
      source.stepsByDay['2026-09-24'] = 5000;
      await syncNow();
      source.stepsByDay['2026-09-24'] = null;
      await syncNow();
      expect((await db.select(db.dailySteps).getSingle()).steps, 5000);
    });
  });

  test(
    'workouts removed from Health Connect are deleted in the window only',
    () async {
      source.workoutRecords
        ..add(workout('keep', DateTime(2026, 9, 23, 18)))
        ..add(workout('gone', DateTime(2026, 9, 24, 18)));
      await syncNow();
      // An old workout outside any re-synced window.
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              id: 'old',
              dayKey: '2026-01-10',
              title: 'Strength training',
              startTime: DateTime(2026, 1, 10, 18),
              endTime: DateTime(2026, 1, 10, 19),
              syncedAt: DateTime(2026, 1, 10, 20),
            ),
          );

      source.workoutRecords.removeWhere((w) => w.id == 'gone');
      await syncNow();

      final ids = (await db.select(db.workouts).get()).map((w) => w.id).toSet();
      expect(ids, {'keep', 'old'});
    },
  );

  group('no access', () {
    test('missing permission records status and does not throw', () async {
      source.permissionsGranted = false;
      await syncNow();
      expect(
        container.read(healthStatusProvider).kind,
        HealthStatusKind.needsPermission,
      );
      expect(source.requestPermissionCalls, 0);
      expect(source.stepCalls, isEmpty);
      expect(container.read(healthSyncProvider).value, isNull);
      expect(container.read(healthSyncProvider).hasError, isFalse);
      expect(await kv('hc.lastSyncAt'), isNull);
    });

    test('Health Connect not installed records unavailable', () async {
      source.availabilityValue = HcAvailability.notInstalled;
      await syncNow();
      final status = container.read(healthStatusProvider);
      expect(status.kind, HealthStatusKind.unavailable);
      expect(status.canInstall, isTrue);
      expect(source.stepCalls, isEmpty);
    });

    test('read errors go into state and keep the last sync time', () async {
      await syncNow();
      final firstSync = now;
      source.stepsByDay['2026-09-25'] = 4000;
      source.workoutsError = StateError('boom');
      now = now.add(const Duration(hours: 1));

      await syncNow(); // must not throw

      final state = container.read(healthSyncProvider);
      expect(state.hasError, isTrue);
      expect(state.value, firstSync);
      final status = container.read(healthStatusProvider);
      expect(status.kind, HealthStatusKind.error);
      expect(status.message, contains('boom'));
      // Nothing was written for the failed run.
      expect(await db.select(db.dailySteps).get(), isEmpty);
      expect(DateTime.parse((await kv('hc.lastSyncAt'))!).toLocal(), firstSync);
    });
  });

  test('concurrent syncs share one run', () async {
    source.gate = Completer<void>();
    final notifier = container.read(healthSyncProvider.notifier);
    final a = notifier.syncNow();
    final b = notifier.syncNow();
    // A second path straight to the service joins the same run too.
    final c = container.read(healthSyncServiceProvider).sync();
    source.gate!.complete();
    await Future.wait([a, b, c]);
    expect(source.availabilityCalls, 1);
    expect(source.workoutCalls, hasLength(1));
  });

  test(
    'day boundaries are local midnights and workouts use local start day',
    () async {
      source.workoutRecords
        ..add(workout('late', DateTime(2026, 9, 23, 23, 30)))
        ..add(workout('early', DateTime(2026, 9, 24, 0, 15)));
      await syncNow();

      for (final (start, end) in source.stepCalls) {
        expect(start.isUtc, isFalse);
        expect((start.hour, start.minute, start.second), (0, 0, 0));
        expect(end, DateTime(start.year, start.month, start.day + 1));
      }
      final rows = {
        for (final w in await db.select(db.workouts).get()) w.id: w.dayKey,
      };
      expect(rows, {'late': '2026-09-23', 'early': '2026-09-24'});
    },
  );

  group('connect', () {
    test('requests permissions, then history, then syncs 90 days', () async {
      source.permissionsGranted = false;
      await container.read(healthSyncProvider.notifier).connect();
      expect(source.requestPermissionCalls, 1);
      expect(source.requestHistoryCalls, 1);
      expect(source.stepCalls, hasLength(91));
      expect(container.read(healthStatusProvider).historyAuthorized, isTrue);
    });

    test('does not re-request permissions already granted', () async {
      source.historyAuthorized = true;
      await container.read(healthSyncProvider.notifier).connect();
      expect(source.requestPermissionCalls, 0);
      expect(source.requestHistoryCalls, 0);
    });
  });

  group('activity providers', () {
    Future<void> putSteps(String day, int steps) => db
        .into(db.dailySteps)
        .insertOnConflictUpdate(
          DailyStepsCompanion.insert(dayKey: day, steps: steps, syncedAt: now),
        );

    test('range fills missing days, oldest first', () async {
      await putSteps('2026-09-23', 5000);
      await putSteps('2026-09-25', 7000);
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              id: 'w1',
              dayKey: '2026-09-22',
              title: 'Chest and back',
              startTime: DateTime(2026, 9, 22, 18),
              endTime: DateTime(2026, 9, 22, 19, 12),
              sourceApp: const Value('com.hevy'),
              syncedAt: now,
            ),
          );

      final provider = activityRangeProvider(('2026-09-22', '2026-09-25'));
      // Riverpod 3 pauses providers nobody listens to.
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final days = await container.read(provider.future);
      expect(days.map((d) => d.dayKey), [
        '2026-09-22',
        '2026-09-23',
        '2026-09-24',
        '2026-09-25',
      ]);
      expect(days.map((d) => d.steps), [null, 5000, null, 7000]);
      expect(days.first.workouts.single.title, 'Chest and back');
      expect(days.first.workouts.single.duration, const Duration(minutes: 72));
      expect(days[1].workouts, isEmpty);
    });

    test('range and day providers react to database changes', () async {
      final seen = <List<int?>>[];
      final sub = container.listen<AsyncValue<List<DayActivity>>>(
        activityRangeProvider(('2026-09-24', '2026-09-25')),
        (_, next) {
          if (next case AsyncData(:final value)) {
            seen.add(value.map((d) => d.steps).toList());
          }
        },
        fireImmediately: true,
      );
      final day = container.listen(
        dayActivityProvider('2026-09-25'),
        (_, _) {},
      );
      await container.read(
        activityRangeProvider(('2026-09-24', '2026-09-25')).future,
      );
      await putSteps('2026-09-25', 1234);
      await pumpEventQueue();

      expect(seen.first, [null, null]);
      expect(seen.last, [null, 1234]);
      expect(
        container.read(dayActivityProvider('2026-09-25')).value?.steps,
        1234,
      );
      sub.close();
      day.close();
    });

    test('sync results show up in dayActivityProvider', () async {
      source.stepsByDay['2026-09-25'] = 8432;
      await syncNow();
      final sub = container.listen(
        dayActivityProvider('2026-09-25'),
        (_, _) {},
      );
      addTearDown(sub.close);
      final day = await container.read(
        dayActivityProvider('2026-09-25').future,
      );
      expect(day.steps, 8432);
    });
  });

  test('checkStatus reports without syncing', () async {
    final service = HealthSyncService(
      db: db,
      source: source..permissionsGranted = false,
      clock: () => now,
    );
    final status = await service.checkStatus();
    expect(status.kind, HealthStatusKind.needsPermission);
    expect(source.stepCalls, isEmpty);
  });
}
