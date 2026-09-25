import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/app.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/settings/setup_screen.dart';

import '../features/activity/fake_health_source.dart';
import '../helpers/test_db.dart';

/// Friday.
final now = DateTime(2026, 9, 25, 9);

Widget app(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
    healthSourceProvider.overrideWithValue(FakeHealthSource()),
  ],
  child: const NutritionApp(),
);

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500)); // route animations
}

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
}

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

void main() {
  testWidgets('app starts and switches tabs', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SetupScreen), findsNothing);
    // Dark only, even when the phone is in light mode (the test default).
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    for (final label in ['Weight', 'Dashboard', 'Settings', 'Today']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
    }
    await unmount(tester);
  });

  testWidgets('first start opens setup; Later closes it for the session', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setupLater')));
    await settle(tester);
    expect(find.byType(SetupScreen), findsNothing);

    // Still no profile, but no nagging within the same session.
    await tester.tap(find.text('Settings').last);
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    expect(find.byType(SetupScreen), findsNothing);
    await unmount(tester);
  });

  testWidgets('Save and start stores the profile and the first weigh-in', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    final setup = find.byType(SetupScreen);
    expect(setup, findsOneWidget);
    Finder inSetup(Finder f) => find.descendant(of: setup, matching: f);

    // Nothing filled in: validation stops it, nothing is saved.
    final save = inSetup(find.byKey(const Key('saveProfile')));
    expect(find.text('Save and start'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(find.text('Enter your weight to get your targets'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.profiles).get()), isEmpty);

    await tester.tap(inSetup(find.byKey(const Key('birthDate'))));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '09/25/1996',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(inSetup(find.byKey(const Key('heightCm'))), '180');
    await tester.enterText(
      inSetup(find.byKey(const Key('goalWeightKg'))),
      '80',
    );
    await tester.enterText(
      inSetup(find.byKey(const Key('setupWeightKg'))),
      '90',
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    expect(find.byType(SetupScreen), findsNothing);
    expect(
      find.text("You're all set. Your calorie target is on Today."),
      findsOneWidget,
    );
    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.heightCm, 180);
    final weighIns = await tester.runAsync(() => db.select(db.weighIns).get());
    expect(weighIns!.single.dayKey, '2026-09-25');
    expect(weighIns.single.weightKg, 90);
    final targets = await tester.runAsync(
      () => db.select(db.targetHistory).get(),
    );
    expect(targets, hasLength(1));
    await unmount(tester);
  });

  testWidgets('Settings gets a badge when a check-in is due', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await seedProfile(db); // check-in on Sundays
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-24',
              weightKg: 90,
              createdAt: now,
            ),
          );
      // Last target from before Sunday the 20th: that check-in was missed.
      await db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: '2026-09-13',
              kcal: 2400,
              proteinG: 180,
              fatG: 70,
              carbsG: 270,
              maintenanceKcal: 2900,
              method: TargetMethod.formula.index,
              createdAt: now,
            ),
          );
    });
    await tester.pumpWidget(app(db));
    await settle(tester);
    final badge = tester.widget<Badge>(find.byKey(const Key('settingsBadge')));
    expect(badge.isLabelVisible, isTrue);
    await unmount(tester);
  });

  testWidgets('tapping Today again jumps back to today', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    expect(container.read(selectedDayProvider), '2026-09-25');
    await unmount(tester);
  });
}
