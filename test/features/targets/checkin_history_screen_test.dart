import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/checkin_history_screen.dart';
import 'package:nutrition_app/features/targets/engine/engine.dart';
import 'package:nutrition_app/features/targets/engine/explain.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 27, 9);

Explanation formulaExplanation() => recommend(
  EngineInput(
    today: '2026-09-20',
    profile: EngineProfile(
      sex: Sex.male,
      birthDate: DateTime(1996, 9, 25),
      heightCm: 180,
      activityLevel: ActivityLevel.moderate,
      goalWeightKg: 80,
      weeklyRatePct: 0.5,
      proteinPerKg: 2.0,
      goalDirection: GoalDirection.lose,
    ),
    weighIns: const {'2026-09-20': 90},
    intake: const {},
  ),
).explanation;

Future<void> addRow(
  AppDatabase db,
  String day, {
  String? json,
  double kcal = 2100,
}) => db
    .into(db.targetHistory)
    .insert(
      TargetHistoryCompanion.insert(
        effectiveFrom: day,
        kcal: kcal,
        proteinG: 160,
        fatG: 70,
        carbsG: 200,
        maintenanceKcal: 2450,
        method: TargetMethod.formula.index,
        explanationJson: Value(json),
        createdAt: now,
      ),
    );

Widget app(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
  ],
  child: const MaterialApp(home: CheckInHistoryScreen()),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('empty history says so', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.textContaining('No check-ins yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('lists check-ins newest first and expands to the why', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final e = formulaExplanation();
    final json = jsonEncode(e.toJson());
    await tester.runAsync(() async {
      await addRow(db, '2026-09-13', json: json, kcal: 2000);
      await addRow(db, '2026-09-20', json: json, kcal: 2100);
      // Skip row: a copied explanation tagged skipped.
      await addRow(
        db,
        '2026-09-27',
        json: jsonEncode({...e.toJson(), 'skipped': true, 'keptFrom': 2}),
        kcal: 2100,
      );
      // Legacy rows: no explanation at all, and a marker to a missing row.
      await addRow(db, '2026-09-06');
      await addRow(
        db,
        '2026-08-30',
        json: jsonEncode({'skipped': true, 'keptFrom': 999}),
      );
    });

    await tester.pumpWidget(app(db));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Sun 27 Sep 2026'), findsOneWidget);
    expect(find.text('Skipped, kept 2,100 kcal'), findsNWidgets(2));
    expect(
      find.textContaining('2,000 kcal · maintenance 2,450 kcal'),
      findsOneWidget,
    );
    final top = tester.getTopLeft(find.text('Sun 27 Sep 2026')).dy;
    final older = tester.getTopLeft(find.text('Sun 20 Sep 2026')).dy;
    expect(top, lessThan(older));

    // Expanding shows the stored explanation, plus the basis line.
    await tester.tap(find.text('Sun 20 Sep 2026'));
    await tester.pumpAndSettle();
    expect(find.text(explainLines(e).first), findsOneWidget);
    expect(find.textContaining('Formula estimate: rough'), findsOneWidget);

    // A row with nothing readable says so instead of throwing.
    await tester.tap(find.text('Sun 6 Sep 2026'));
    await tester.pumpAndSettle();
    expect(find.text('No details saved for this check-in.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
