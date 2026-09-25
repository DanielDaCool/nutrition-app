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

    // Birth date: open the picker, choose the 25th of the initial month
    // (September 1996, i.e. 30 years before "now").
    await tester.tap(find.byKey(const Key('birthDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
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
