import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/targets_providers.dart';
import 'package:nutrition_app/features/targets/targets_repository.dart';

import '../../helpers/test_db.dart';

/// Friday.
final friday = DateTime(2026, 9, 25, 9);

/// Sunday (default check-in weekday).
final sunday = DateTime(2026, 9, 27, 9);

Future<void> addProfile(TargetsRepository repo, {int weekday = 7}) =>
    repo.saveProfile(
      sex: Sex.male,
      birthDate: DateTime(1996, 9, 25),
      heightCm: 180,
      activityLevel: ActivityLevel.moderate,
      goalWeightKg: 80,
      weeklyRatePct: 0.5,
      proteinPerKg: 2.0,
      checkInWeekday: weekday,
    );

Future<void> addWeighIn(AppDatabase db, String day, double kg) => db
    .into(db.weighIns)
    .insertOnConflictUpdate(
      WeighInsCompanion.insert(
        dayKey: day,
        weightKg: kg,
        createdAt: startOfDay(day),
      ),
    );

Future<int> addTarget(
  AppDatabase db,
  String day, {
  double kcal = 2400,
  Map<String, Object?>? explanation,
}) => db
    .into(db.targetHistory)
    .insert(
      TargetHistoryCompanion.insert(
        explanationJson: Value(
          explanation == null ? null : jsonEncode(explanation),
        ),
        effectiveFrom: day,
        kcal: kcal,
        proteinG: 180,
        fatG: 70,
        carbsG: 270,
        maintenanceKcal: 2900,
        method: TargetMethod.formula.index,
        createdAt: startOfDay(day),
      ),
    );

/// Waits until [provider] emits a value matching [matcher].
Future<T> waitFor<T>(
  ProviderContainer c,
  StreamProvider<T> provider,
  bool Function(T) matcher,
) async {
  final done = Completer<T>();
  final sub = c.listen<AsyncValue<T>>(provider, (_, next) {
    final v = next.value;
    if (next.hasValue && matcher(v as T) && !done.isCompleted) {
      done.complete(v);
    }
  }, fireImmediately: true);
  try {
    return await done.future.timeout(const Duration(seconds: 5));
  } finally {
    sub.close();
  }
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late ProviderContainer container;
  late TargetsRepository repo;

  setUp(() {
    db = openTestDatabase();
    now = friday;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    repo = container.read(targetsRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('no profile: no targets and no check-in', () async {
    expect(
      await waitFor(container, currentTargetsProvider, (_) => true),
      isNull,
    );
    expect(await waitFor(container, checkInDueProvider, (_) => true), isFalse);
  });

  test('first target is auto-created after saving a profile', () async {
    // Listen before anything exists, then add data: the stream must react.
    expect(
      await waitFor(container, currentTargetsProvider, (_) => true),
      isNull,
    );
    await addWeighIn(db, '2026-09-25', 90);
    await addProfile(repo);

    final t = await waitFor<DailyTargets?>(
      container,
      currentTargetsProvider,
      (t) => t != null,
    );
    // Same numbers as the engine test's formula-only recommendation.
    expect(t!.effectiveFrom, '2026-09-25');
    expect(t.macros.kcal, 2470);
    expect(t.method, TargetMethod.formula);

    final rows = await db.select(db.targetHistory).get();
    expect(rows, hasLength(1));
    expect(rows.single.effectiveFrom, '2026-09-25');
    final why = jsonDecode(rows.single.explanationJson!) as Map;
    expect(why['formulaKcal'], closeTo(2914, 1e-6));

    // First target starts today, and today is not the check-in day.
    expect(await waitFor(container, checkInDueProvider, (_) => true), isFalse);
  });

  test('profile without weigh-in: no targets and no check-in yet', () async {
    await addProfile(repo);
    expect(
      await waitFor(container, currentTargetsProvider, (_) => true),
      isNull,
    );
    expect(await waitFor(container, checkInDueProvider, (_) => true), isFalse);
  });

  test('not due without weigh-ins even when the target is old', () async {
    now = sunday;
    await addProfile(repo);
    await addTarget(db, '2026-09-13');
    expect(await repo.checkInDue(), isFalse);
  });

  test('a missed check-in day stays due until it is done', () async {
    // Check-in day was Sunday 20th; it is now Friday 25th.
    await addProfile(repo);
    await addWeighIn(db, '2026-09-24', 90);
    await addTarget(db, '2026-09-13');
    expect(await waitFor(container, checkInDueProvider, (_) => true), isTrue);

    await repo.keepCurrentTarget(); // skip, stored as today
    expect(await waitFor(container, checkInDueProvider, (d) => !d), isFalse);
  });

  test('check-in is due on the check-in weekday', () async {
    now = sunday;
    await addProfile(repo); // Sunday
    await addWeighIn(db, '2026-09-19', 90);
    await addTarget(db, '2026-09-20');
    expect(await waitFor(container, checkInDueProvider, (_) => true), isTrue);

    final rec = await repo.recommendToday();
    await repo.saveRecommendation(rec!);
    expect(await waitFor(container, checkInDueProvider, (d) => !d), isFalse);
  });

  test('check-in is not due on other weekdays', () async {
    await addProfile(repo, weekday: DateTime.sunday);
    await addWeighIn(db, '2026-09-24', 90);
    await addTarget(db, '2026-09-20');
    expect(await waitFor(container, checkInDueProvider, (_) => true), isFalse);
  });

  test('accepting saves a TargetHistory row effective today', () async {
    now = sunday;
    await addProfile(repo);
    await addWeighIn(db, '2026-09-19', 90);
    await addTarget(db, '2026-09-20', kcal: 2000);

    final rec = await repo.recommendToday();
    // Previous maintenance 2900, formula ~2914: within ±150, not limited.
    expect(rec!.explanation.previousMaintenanceKcal, 2900);
    await repo.saveRecommendation(rec);
    await repo.saveRecommendation(rec); // same day again: replaced, not added

    final rows = await (db.select(
      db.targetHistory,
    )..orderBy([(t) => OrderingTerm.asc(t.effectiveFrom)])).get();
    expect(rows.map((r) => r.effectiveFrom), ['2026-09-20', '2026-09-27']);
    expect(rows.last.kcal, rec.macros.kcal);
    expect(rows.last.explanationJson, isNotNull);

    final t = await waitFor<DailyTargets?>(
      container,
      currentTargetsProvider,
      (t) => t?.effectiveFrom == '2026-09-27',
    );
    expect(t!.macros.kcal, rec.macros.kcal);
  });

  test('skip keeps the current numbers and ends the check-in', () async {
    now = sunday;
    await addProfile(repo);
    await addWeighIn(db, '2026-09-19', 90);
    await addTarget(db, '2026-09-20', kcal: 2000);
    await repo.keepCurrentTarget();
    final rows = await db.select(db.targetHistory).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.kcal), [2000, 2000]);
    expect(await repo.checkInDue(), isFalse);
  });

  group('skip keeps the engine state', () {
    // A real explanation, with Kalman state as if data had been measured.
    Future<Map<String, Object?>> realExplanation() async {
      now = DateTime(2026, 9, 20, 9);
      await addProfile(repo);
      await addWeighIn(db, '2026-09-19', 90);
      final rec = (await repo.recommendToday())!;
      return rec.explanation.toJson()
        ..['phaseStartDayKey'] = '2026-09-06'
        ..['smoothedMeasuredKcal'] = 2600.0
        ..['measuredVarianceKcal2'] = 10000.0;
    }

    test('skip copies the kept explanation forward', () async {
      final kept = await realExplanation();
      final keptId = await addTarget(db, '2026-09-20', explanation: kept);
      now = sunday;
      await repo.keepCurrentTarget();

      final skipRow = await (db.select(
        db.targetHistory,
      )..where((t) => t.effectiveFrom.equals('2026-09-27'))).getSingle();
      final stored =
          jsonDecode(skipRow.explanationJson!) as Map<String, Object?>;
      expect(stored['skipped'], isTrue);
      expect(stored['keptFrom'], keptId);
      expect(stored['formulaKcal'], kept['formulaKcal']);

      // Next week's check-in sees the kept target's state, not a reset.
      now = DateTime(2026, 10, 4, 9);
      final input = (await repo.loadInput())!;
      expect(input.previousPhaseStartDayKey, '2026-09-06');
      expect(input.previousWeeklyRatePctRaw, 0.5);
      expect(input.previousFormulaKcal, kept['formulaKcal']);
      expect(input.previousMaintenanceMode, isFalse);
      expect(input.previousSmoothedMeasuredKcal, 2600);
      // One skipped week of process noise on top of the kept variance.
      expect(input.previousMeasuredVarianceKcal2, 10000 + 50 * 50);
    });

    test(
      'an old skip marker row is followed back to the kept target',
      () async {
        final kept = await realExplanation();
        final keptId = await addTarget(db, '2026-09-20', explanation: kept);
        await addTarget(
          db,
          '2026-09-27',
          explanation: {'skipped': true, 'keptFrom': keptId},
        );
        now = DateTime(2026, 10, 4, 9);
        final input = (await repo.loadInput())!;
        expect(input.previousPhaseStartDayKey, '2026-09-06');
        expect(input.previousFormulaKcal, kept['formulaKcal']);
        expect(input.previousSmoothedMeasuredKcal, 2600);

        // Skipping again copies the real explanation, not the bare marker.
        now = DateTime(2026, 10, 5, 9);
        await repo.keepCurrentTarget();
        final row = await (db.select(
          db.targetHistory,
        )..where((t) => t.effectiveFrom.equals('2026-10-05'))).getSingle();
        final stored = jsonDecode(row.explanationJson!) as Map<String, Object?>;
        expect(stored['formulaKcal'], kept['formulaKcal']);
      },
    );
  });

  test('future-dated targets are ignored', () async {
    await addProfile(repo);
    await addWeighIn(db, '2026-09-25', 90);
    await addTarget(db, '2026-09-20', kcal: 2000);
    await addTarget(db, '2026-10-01', kcal: 1800);
    final t = await waitFor<DailyTargets?>(
      container,
      currentTargetsProvider,
      (t) => t != null,
    );
    expect(t!.macros.kcal, 2000);
  });

  test(
    'loadInput sums logged kcal per day and reads fully-logged flags',
    () async {
      await addProfile(repo);
      await addWeighIn(db, '2026-09-20', 91);
      await addWeighIn(db, '2026-09-24', 90);
      await addWeighIn(db, '2026-09-26', 89); // after today: ignored
      final foodId = await db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              source: 'custom',
              name: 'Test food',
              kcalPer100g: 100,
              proteinPer100g: 1,
              fatPer100g: 1,
              carbsPer100g: 1,
              createdAt: friday,
            ),
          );
      Future<void> log(String day, double kcal) => db
          .into(db.foodLogEntries)
          .insert(
            FoodLogEntriesCompanion.insert(
              dayKey: day,
              meal: Meal.lunch.index,
              foodId: foodId,
              grams: 100,
              kcal: kcal,
              proteinG: 0,
              fatG: 0,
              carbsG: 0,
              createdAt: friday,
            ),
          );
      await log('2026-09-23', 1200);
      await log('2026-09-23', 900);
      await log('2026-09-24', 1500);
      await log('2026-09-25', 800); // today: outside the window
      await log('2026-08-01', 800); // before the window
      await db
          .into(db.dayStatuses)
          .insert(
            DayStatusesCompanion.insert(
              dayKey: '2026-09-23',
              fullyLogged: const Value(true),
            ),
          );
      await addTarget(db, '2026-09-20');

      final input = (await repo.loadInput())!;
      expect(input.today, '2026-09-25');
      expect(input.weighIns.keys, ['2026-09-20', '2026-09-24']);
      expect(input.intake.keys.toSet(), {'2026-09-23', '2026-09-24'});
      expect(input.intake['2026-09-23']!.kcal, 2100);
      expect(input.intake['2026-09-23']!.fullyLogged, isTrue);
      expect(input.intake['2026-09-24']!.fullyLogged, isFalse);
      expect(input.previousMaintenanceKcal, 2900);
    },
  );

  group('check-in date logic', () {
    test('last check-in day is the latest matching weekday', () {
      // 2026-09-25 is a Friday.
      expect(lastCheckInDay('2026-09-25', DateTime.friday), '2026-09-25');
      expect(lastCheckInDay('2026-09-25', DateTime.sunday), '2026-09-20');
      expect(lastCheckInDay('2026-09-25', DateTime.saturday), '2026-09-19');
      expect(lastCheckInDay('2026-09-25', DateTime.monday), '2026-09-21');
    });

    test('due only when the target started before the last check-in day', () {
      bool due(String from) => isCheckInDue(
        today: '2026-09-25',
        currentEffectiveFrom: from,
        checkInWeekday: DateTime.sunday,
      );
      expect(due('2026-09-13'), isTrue); // missed Sunday 20th
      expect(due('2026-09-19'), isTrue);
      expect(due('2026-09-20'), isFalse); // done on the day
      expect(due('2026-09-22'), isFalse); // done late
    });
  });
}
