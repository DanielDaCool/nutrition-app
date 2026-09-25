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
            (ref, dayKey) => Stream.value(
              DayIntake(
                dayKey: dayKey,
                total: Macros.zero,
                byMeal: const {},
                fullyLogged: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CalorieCard(dayKey: '2026-09-25')),
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
}
