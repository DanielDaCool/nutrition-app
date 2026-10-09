import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/widgets/health_connect_tile.dart';
import 'package:nutrition_app/features/activity/widgets/step_goal_tile.dart';
import 'package:nutrition_app/features/activity/widgets/walk_reminder_tile.dart';
import 'package:nutrition_app/features/settings/data_export.dart';
import 'package:nutrition_app/features/settings/report_problem_tile.dart';
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
    final edit = find.byKey(const Key('editProfile'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump();
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSaveProfile')));
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

    // The profile is locked; unlock it before editing.
    final edit = find.byKey(const Key('editProfile'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump();

    // A lower goal brings the loss rate back.
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '75');
    await tester.pump();
    expect(find.textContaining('Weekly loss rate'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('an existing profile is locked until Edit is tapped', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);

    // Locked: no Save button, fields disabled, an Edit button instead.
    expect(find.byKey(const Key('saveProfile')), findsNothing);
    expect(find.byKey(const Key('editProfile')), findsOneWidget);
    final heightField = tester.widget<TextFormField>(
      find.byKey(const Key('heightCm')),
    );
    expect(heightField.enabled, isFalse);

    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pump();
    expect(find.byKey(const Key('saveProfile')), findsOneWidget);
    expect(find.byKey(const Key('editProfile')), findsNothing);

    // Cancel discards the change and relocks without saving.
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '70');
    await tester.tap(find.byKey(const Key('cancelEditProfile')));
    await settle(tester);
    expect(find.byKey(const Key('editProfile')), findsOneWidget);
    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.goalWeightKg, 80);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('dismissing the save confirmation keeps the old profile', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '70');
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await settle(tester);

    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.goalWeightKg, 80);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('a profile saved elsewhere after the form was built shows up', (
    tester,
  ) async {
    // Settings is built at startup (inside the home shell) before first-run
    // setup saves the profile from its own form.
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byKey(const Key('startHere')), findsOneWidget);

    await tester.runAsync(
      () => db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              sex: Sex.female.index,
              birthDate: DateTime(1990, 3, 4),
              heightCm: 165,
              activityLevel: ActivityLevel.active.index,
              goalWeightKg: 60,
              weeklyRatePct: const Value(0.25),
              proteinPerKg: const Value(2.0),
              checkInWeekday: const Value(DateTime.wednesday),
              updatedAt: now,
            ),
          ),
    );
    await settle(tester);

    String fieldText(String key) =>
        tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
    expect(fieldText('heightCm'), '165');
    expect(fieldText('goalWeightKg'), '60');
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<Sex>>(find.byType(SegmentedButton<Sex>))
          .selected,
      {Sex.female},
    );

    // Editing and saving keeps the real values, not the form's defaults.
    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pump();
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSaveProfile')));
    await settle(tester);
    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.sex, Sex.female.index);
    expect(profile.checkInWeekday, DateTime.wednesday);
    expect(profile.activityLevel, ActivityLevel.active.index);
    expect(profile.weeklyRatePct, 0.25);
    expect(profile.proteinPerKg, 2.0);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('a rate above the current cap is shown capped but not saved '
      'lower', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              sex: Sex.male.index,
              birthDate: DateTime(1996, 9, 25),
              heightCm: 180,
              activityLevel: ActivityLevel.moderate.index,
              goalWeightKg: 65,
              weeklyRatePct: const Value(1.0),
              updatedAt: now,
            ),
          );
      // Lean now (BMI 21.6, ~17% fat): capped at 0.5 %/week.
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-25',
              weightKg: 70,
              createdAt: now,
            ),
          );
    });
    await tester.pumpWidget(app(db));
    await settle(tester);

    expect(find.textContaining('Weekly loss rate: 0.50 %'), findsOneWidget);
    expect(
      find.textContaining('Your chosen 1.00 % is capped at 0.50 %'),
      findsOneWidget,
    );

    // Edit something unrelated and save: the chosen rate is kept.
    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '66');
    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSaveProfile')));
    await settle(tester);
    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.goalWeightKg, 66);
    expect(profile.weeklyRatePct, 1.0);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('typing birth date digits only auto-inserts the slashes', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.tap(find.byKey(const Key('birthDate')));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '09251996');
    expect(
      (tester.widget(field) as TextField).controller!.text,
      '09/25/1996',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Sep 25, 1996 · 30 years old'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('editing a middle digit of the birth date keeps the cursor '
      'near the edit instead of jumping to the end', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.tap(find.byKey(const Key('birthDate')));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '09251996');
    expect(
      (tester.widget(field) as TextField).controller!.text,
      '09/25/1996',
    );

    // Regression: the old formatter ignored the edit position and always
    // collapsed the cursor to the end, so correcting a typo in the middle
    // (e.g. day "25" should have been "05") left the cursor stranded at the
    // end instead of where the user was editing.
    await tester.showKeyboard(field);
    // Replaces the '2' at index 3 with '0': "09/25/1996" -> "09/05/1996",
    // as the platform would report it, with the cursor right after the
    // digit that was just typed.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '09/05/1996',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    final updated = tester.widget(field) as TextField;
    expect(updated.controller!.text, '09/05/1996');
    expect(
      updated.controller!.selection,
      const TextSelection.collapsed(offset: 4),
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('picking Gain weight saves goalDirection as gain', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);

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

    await tester.enterText(find.byKey(const Key('heightCm')), '180');
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '85');

    await tester.ensureVisible(find.byKey(const Key('goalDirection')));
    await tester.tap(find.text('Gain weight'));
    await tester.pump();

    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.goalDirection, GoalDirection.gain.index);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  test('age counts whole years', () {
    expect(ageOn(DateTime(1996, 9, 25), DateTime(2026, 9, 25)), 30);
    expect(ageOn(DateTime(1996, 9, 26), DateTime(2026, 9, 25)), 29);
    expect(ageOn(DateTime(1996, 12, 1), DateTime(2026, 9, 25)), 29);
  });

  testWidgets(
    'a birth date too far in the past names both bounds, not just the '
    '13-years-ago one',
    (tester) async {
      tallScreen(tester);
      final db = openTestDatabase();
      addTearDown(db.close);
      await tester.pumpWidget(app(db));
      await settle(tester);

      await tester.tap(find.byKey(const Key('birthDate')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        // now is 2026-09-25: firstDate is 1926, so this is a year too old.
        '09/25/1925',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a date between 1926 and 2013'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

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

  testWidgets('height and goal weight reject letters and a minus sign', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('heightCm')), '180');
    await tester.enterText(find.byKey(const Key('heightCm')), '-abc180');
    await tester.pump();
    expect(
      (tester.widget(find.byKey(const Key('heightCm'))) as TextFormField)
          .controller!
          .text,
      '180',
    );

    await tester.enterText(find.byKey(const Key('goalWeightKg')), '80');
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '-abc80');
    await tester.pump();
    expect(
      (tester.widget(find.byKey(const Key('goalWeightKg'))) as TextFormField)
          .controller!
          .text,
      '80',
    );

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

  testWidgets('web hides the Android-only settings but keeps backups', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          isWebProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.byKey(const Key('targetsCard')), findsOneWidget);
    expect(find.byType(HealthConnectSettingsTile), findsNothing);
    expect(find.byType(StepGoalSettingsTile), findsNothing);
    expect(find.byType(WalkReminderSettingsTile), findsNothing);
    // Backups work on web too: an iPhone friend's data lives only there.
    expect(find.byType(ExportDataTile), findsOneWidget);
    expect(find.byType(ImportDataTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Android keeps the Health Connect, reminder and export rows', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(app(db));
    await settle(tester);

    expect(find.byType(HealthConnectSettingsTile), findsOneWidget);
    expect(find.byType(StepGoalSettingsTile), findsOneWidget);
    expect(find.byType(WalkReminderSettingsTile), findsOneWidget);
    expect(find.byType(ExportDataTile), findsOneWidget);
    expect(find.byType(ImportDataTile), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the app version at the bottom', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(app(db));
    await settle(tester);

    // Tests don't pass --dart-define=APP_VERSION.
    expect(find.text('Version Development build'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the backup rows are left out when switched off', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          featureEnabledProvider.overrideWith(
            (ref, f) => f != AppFeature.backup,
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.byType(ExportDataTile), findsNothing);
    expect(find.byType(ImportDataTile), findsNothing);
    expect(find.text('Your data'), findsNothing);
    // Android-only rows stay, since only the backup gate is off here.
    expect(find.byType(HealthConnectSettingsTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sending a report closes the dialog on success', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    http.BaseRequest? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          reportProblemClientProvider.overrideWithValue(client),
          reportRelayUrlProvider.overrideWithValue(
            'https://relay.example/report',
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    expect(find.byType(ReportProblemTile), findsOneWidget);
    await tester.tap(find.byType(ReportProblemTile));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Nothing typed: validated locally, no request sent.
    await tester.tap(find.byKey(const Key('reportProblemSend')));
    await tester.pump();
    expect(find.text('Describe what went wrong first.'), findsOneWidget);
    expect(sent, isNull);

    await tester.enterText(
      find.byKey(const Key('reportProblemDescription')),
      'The app crashed on save',
    );
    await tester.tap(find.byKey(const Key('reportProblemSend')));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Thanks — your report was sent.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed send keeps the dialog open with an error', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    final client = MockClient((request) async => http.Response('', 500));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          reportProblemClientProvider.overrideWithValue(client),
          reportRelayUrlProvider.overrideWithValue(
            'https://relay.example/report',
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(ReportProblemTile));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reportProblemDescription')),
      'The app crashed on save',
    );
    await tester.tap(find.byKey(const Key('reportProblemSend')));
    await settle(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text("Couldn't send that. Check your connection and try again."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the report-a-problem row is left out when switched off', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          featureEnabledProvider.overrideWith(
            (ref, f) => f != AppFeature.reportProblem,
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.byType(ReportProblemTile), findsNothing);
    // Everything else, including the version footer, is unaffected.
    expect(find.byType(ExportDataTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the lose/gain choice is hidden while gain goals are off', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          featureEnabledProvider.overrideWith(
            (ref, f) => f != AppFeature.gainGoals,
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.byKey(const Key('goalWeightKg')), findsOneWidget);
    expect(find.byKey(const Key('goalDirection')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
