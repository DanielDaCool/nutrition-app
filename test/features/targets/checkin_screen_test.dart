import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/checkin_screen.dart';

import '../../helpers/test_db.dart';

/// Sunday, the default check-in day.
final now = DateTime(2026, 9, 27, 9);

Future<void> seed(AppDatabase db) async {
  await db
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
  // 60 days losing 0.065 kg/day while logging 2,000 kcal: maintenance ~2,500.
  final foodId = await db
      .into(db.foods)
      .insert(
        FoodsCompanion.insert(
          source: 'custom',
          name: 'Food',
          kcalPer100g: 100,
          proteinPer100g: 0,
          fatPer100g: 0,
          carbsPer100g: 0,
          createdAt: now,
        ),
      );
  final today = dayKeyOf(now);
  for (var i = 0; i < 60; i++) {
    final day = addDays(today, -60 + i);
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: day,
            weightKg: 92 - 500 / 7700 * i,
            createdAt: now,
          ),
        );
    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            dayKey: day,
            meal: Meal.dinner.index,
            foodId: foodId,
            grams: 2000,
            kcal: 2000,
            proteinG: 0,
            fatG: 0,
            carbsG: 0,
            createdAt: now,
          ),
        );
    await db
        .into(db.dayStatuses)
        .insert(
          DayStatusesCompanion.insert(
            dayKey: day,
            fullyLogged: const Value(true),
          ),
        );
  }
  await db
      .into(db.targetHistory)
      .insert(
        TargetHistoryCompanion.insert(
          effectiveFrom: addDays(today, -7),
          kcal: 2100,
          proteinG: 160,
          fatG: 70,
          carbsG: 200,
          maintenanceKcal: 2450,
          method: TargetMethod.blended.index,
          createdAt: now,
        ),
      );
}

Widget app(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
  ],
  child: const MaterialApp(home: CheckInScreen()),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('shows why and accepting saves a TargetHistory row', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seed(db));

    await tester.pumpWidget(app(db));
    await settle(tester);

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('2,100 kcal'), findsOneWidget);
    expect(
      find.textContaining(
        'You averaged 2,000 kcal on 28 fully logged days '
        'and your weight went down 1.7 kg in 27 days',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Accept'));
    await tester.tap(find.text('Accept'));
    await settle(tester);

    final rows = await tester.runAsync(
      () => (db.select(
        db.targetHistory,
      )..orderBy([(t) => OrderingTerm.asc(t.effectiveFrom)])).get(),
    );
    expect(rows, hasLength(2));
    final saved = rows!.last;
    expect(saved.effectiveFrom, '2026-09-27');
    expect(saved.method, TargetMethod.adaptive.index);
    expect(saved.maintenanceKcal, closeTo(2444, 1));
    expect(saved.explanationJson, contains('"loggedDays":28'));
    expect(find.text('New targets saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('skip keeps the current target', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seed(db));

    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await settle(tester);

    final rows = await tester.runAsync(() => db.select(db.targetHistory).get());
    expect(rows, hasLength(2));
    expect(rows!.map((r) => r.kcal), [2100, 2100]);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
