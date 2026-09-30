import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/food_providers.dart';
import 'package:nutrition_app/features/settings/setup_screen.dart';
import 'package:nutrition_app/features/targets/targets_providers.dart';
import 'package:nutrition_app/features/today/widgets/calorie_card.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 25, 12);

Future<void> seedProfile(AppDatabase db) => db
    .into(db.profiles)
    .insert(
      ProfilesCompanion.insert(
        sex: Sex.male.index,
        birthDate: DateTime(1996, 9, 25),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate.index,
        goalWeightKg: 80,
        updatedAt: now,
      ),
    );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpCard(
    WidgetTester tester, {
    Stream<DailyTargets?> Function()? targets,
    String dayKey = '2026-09-25',
    Stream<DayIntake> Function(String dayKey)? intake,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          if (targets != null)
            currentTargetsProvider.overrideWith((ref) => targets()),
          dayIntakeProvider.overrideWith(
            (ref, dk) =>
                intake?.call(dk) ??
                Stream.value(
                  DayIntake(
                    dayKey: dk,
                    total: Macros.zero,
                    byMeal: const {},
                    fullyLogged: false,
                  ),
                ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: CalorieCard(dayKey: dayKey)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets('no profile: Set up opens the setup screen', (tester) async {
    await pumpCard(tester);
    expect(find.text('Get your daily calorie target'), findsOneWidget);
    await tester.tap(find.text('Set up'));
    await settle(tester);
    expect(find.byType(SetupScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('profile but no weigh-in: log one right from the card', (
    tester,
  ) async {
    await tester.runAsync(() => seedProfile(db));
    await pumpCard(tester);
    expect(
      find.text('Log your first weigh-in to get your targets'),
      findsOneWidget,
    );
    await tester.tap(find.text('Log weigh-in'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      '90',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    final rows = await tester.runAsync(() => db.select(db.weighIns).get());
    expect(rows!.single.weightKg, 90);
    // The first target is created and shown.
    expect(find.byKey(const Key('kcalRemaining')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('errors are friendly and can be retried', (tester) async {
    var calls = 0;
    await pumpCard(
      tester,
      targets: () {
        calls++;
        return calls == 1
            ? Stream.error(StateError('db exploded'))
            : Stream.value(
                const DailyTargets(
                  effectiveFrom: '2026-09-21',
                  macros: Macros(
                    kcal: 2000,
                    proteinG: 150,
                    fatG: 70,
                    carbsG: 200,
                  ),
                  maintenanceKcal: 2500,
                  method: TargetMethod.formula,
                ),
              );
      },
    );
    expect(find.text("Couldn't load your targets"), findsOneWidget);
    expect(find.textContaining('exploded'), findsNothing);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byKey(const Key('kcalRemaining')), findsOneWidget);
    await unmount(tester);
  });

  Future<void> insertTarget(
    AppDatabase db,
    String effectiveFrom,
    double kcal,
  ) => db
      .into(db.targetHistory)
      .insert(
        TargetHistoryCompanion.insert(
          effectiveFrom: effectiveFrom,
          kcal: kcal,
          proteinG: kcal * 0.3 / 4,
          fatG: kcal * 0.3 / 9,
          carbsG: kcal * 0.4 / 4,
          maintenanceKcal: kcal + 300,
          method: TargetMethod.formula.index,
          createdAt: now,
        ),
      );

  testWidgets(
    'a past day uses the target that was in effect on that day, not today\'s',
    (tester) async {
      await tester.runAsync(() async {
        await insertTarget(db, '2026-09-01', 1800);
        await insertTarget(db, '2026-09-18', 2200); // in effect on 09-20
        await insertTarget(db, '2026-09-22', 3000); // starts after 09-20
      });
      // No override for currentTargetsProvider: a past day must not touch
      // it at all.
      await pumpCard(tester, dayKey: '2026-09-20');
      expect(find.textContaining('Target 2,200 kcal'), findsOneWidget);
      expect(find.textContaining('Target 1,800 kcal'), findsNothing);
      expect(find.textContaining('Target 3,000 kcal'), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('a past day before any target explains there was none', (
    tester,
  ) async {
    await tester.runAsync(() => insertTarget(db, '2026-09-22', 2000));
    await pumpCard(tester, dayKey: '2026-09-10');
    expect(find.byKey(const Key('noTargetForDayCard')), findsOneWidget);
    expect(find.text('No target was set for this day'), findsOneWidget);
    // Unlike today's "no targets" card, there's no setup action to offer.
    expect(find.text('Set up'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
    'today with a profile and weigh-in but no active target shows a '
    'retryable message instead of spinning forever',
    (tester) async {
      await pumpCard(
        tester,
        targets: () => Stream.value(null), // resolved, terminally null
      );
      await tester.runAsync(() => seedProfile(db));
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-25',
              weightKg: 82,
              createdAt: now,
            ),
          );
      await settle(tester);
      expect(find.byKey(const Key('noCurrentTargetCard')), findsOneWidget);
      expect(find.text('No target is active for today'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // Definitely not stuck loading forever.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets(
    'switching days shows the loading state, not a flash of "0 eaten"',
    (tester) async {
      final intakeController = StreamController<DayIntake>();
      addTearDown(intakeController.close);
      await pumpCard(
        tester,
        targets: () => Stream.value(
          const DailyTargets(
            effectiveFrom: '2026-09-25',
            macros: Macros(kcal: 2000, proteinG: 150, fatG: 70, carbsG: 200),
            maintenanceKcal: 2500,
            method: TargetMethod.formula,
          ),
        ),
        intake: (dayKey) => intakeController.stream,
      );
      // Intake never resolved yet: still loading, never "0 eaten".
      expect(find.byKey(const Key('calorieCard')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('kcal remaining'), findsNothing);

      intakeController.add(
        const DayIntake(
          dayKey: '2026-09-25',
          total: Macros(kcal: 500, proteinG: 30, fatG: 10, carbsG: 60),
          byMeal: {},
          fullyLogged: false,
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('calorieCard')), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget); // 2000 - 500 remaining
      await unmount(tester);
    },
  );
}
