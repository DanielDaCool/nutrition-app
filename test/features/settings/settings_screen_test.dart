import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/widgets/health_connect_tile.dart';
import 'package:nutrition_app/features/settings/data_export.dart';
import 'package:nutrition_app/features/settings/settings_screen.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 25, 9);

Widget app(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
  ],
  child: const MaterialApp(home: SettingsScreen()),
);

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

/// A tall screen so the whole settings list is built and tappable.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  testWidgets('saving the profile creates the first target', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(
      () => db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-25',
              weightKg: 90,
              createdAt: now,
            ),
          ),
    );

    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.textContaining('No targets yet'), findsOneWidget);
    expect(find.byType(HealthConnectSettingsTile), findsOneWidget);

    // Birth date is typed, not scrolled to.
    await tester.tap(find.byKey(const Key('birthDate')));
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
    expect(find.text('Sep 25, 1996 · 30 years old'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('heightCm')), '180');
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '80');

    // Activity level -> Moderate.
    await tester.ensureVisible(find.byKey(const Key('activityLevel')));
    await tester.tap(find.byKey(const Key('activityLevel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderate').last);
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.id, 1);
    expect(profile.sex, Sex.male.index);
    expect(profile.birthDate, DateTime(1996, 9, 25));
    expect(profile.heightCm, 180);
    expect(profile.goalWeightKg, 80);
    expect(profile.activityLevel, ActivityLevel.moderate.index);
    expect(profile.weeklyRatePct, 0.5);
    expect(profile.proteinPerKg, 1.8);
    expect(profile.checkInWeekday, DateTime.sunday);

    final rows = await tester.runAsync(() => db.select(db.targetHistory).get());
    expect(rows, hasLength(1));
    expect(
      rows!.single.kcal,
      2470,
    ); // matches engine_test.dart's formula-only case

    expect(find.text('2,470 kcal'), findsOneWidget);
    expect(find.text('Profile saved'), findsOneWidget);
    // With a profile, targets come first again.
    expect(
      tester.getTopLeft(find.byKey(const Key('targetsCard'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('profileForm'))).dy),
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('without a profile the form comes first', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byKey(const Key('startHere')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('profileForm'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('targetsCard'))).dy),
    );
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('saving without a weigh-in says what to do next', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(
      find.text(
        'Profile saved. Next: log your weight on Today to get your targets.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('at or below the goal the rate text says targets hold', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await seedProfile(db); // goal 80 kg
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-25',
              weightKg: 79,
              createdAt: now,
            ),
          );
    });
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(
      find.text("You're at your goal, targets will hold your weight"),
      findsOneWidget,
    );

    // A lower goal brings the loss rate back.
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '75');
    await tester.pump();
    expect(find.textContaining('Weekly loss rate'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  test('age counts whole years', () {
    expect(ageOn(DateTime(1996, 9, 25), DateTime(2026, 9, 25)), 30);
    expect(ageOn(DateTime(1996, 9, 26), DateTime(2026, 9, 25)), 29);
    expect(ageOn(DateTime(1996, 12, 1), DateTime(2026, 9, 25)), 29);
  });

  testWidgets('invalid form is not saved', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(find.text('Enter your height'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.profiles).get()), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  test('export contains every table', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-25',
            weightKg: 90,
            createdAt: now,
          ),
        );
    final data = await exportAllTables(db, now: now);
    final tables = data['tables'] as Map<String, Object?>;
    expect(tables.keys.toSet(), {
      for (final t in db.allTables) t.actualTableName,
    });
    final weighIns = tables['weigh_ins'] as List;
    expect(weighIns.single, {
      'dayKey': '2026-09-25',
      'weightKg': 90.0,
      'createdAt': now.toIso8601String(),
    });
  });
}
