import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/activity/widgets/activity_card.dart';

import '../../helpers/test_db.dart';
import 'fake_health_source.dart';

void main() {
  late AppDatabase db;
  late FakeHealthSource source;
  final now = DateTime(2026, 9, 25, 10, 30);

  setUp(() {
    db = openTestDatabase();
    source = FakeHealthSource();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          healthSourceProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ActivityCard(dayKey: '2026-09-25')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('adding a bike ride estimates calories and shows it', (
    tester,
  ) async {
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-24',
            weightKg: 80,
            createdAt: now,
          ),
        );
    await pump(tester);

    await tester.tap(find.byKey(const Key('addExerciseButton')));
    await tester.pumpAndSettle();

    // Defaults to the first activity (Cycling, leisurely, 6.8 MET), 30 min,
    // and the latest weigh-in (80 kg): 6.8 * 80 * 0.5 = 272 kcal.
    expect(find.byKey(const Key('exerciseWeightField')), findsOneWidget);
    final kcalField = tester.widget<TextFormField>(
      find.byKey(const Key('exerciseKcalField')),
    );
    expect(kcalField.controller!.text, '272');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cycling, leisurely · 30 min'), findsOneWidget);
    expect(find.text('272 kcal · manual'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('editing the calorie field overrides the estimate', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('addExerciseButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('exerciseKcalField')),
      '999',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('999 kcal · manual'), findsOneWidget);
    final row = await db.select(db.manualExercises).getSingle();
    expect(row.kcal, 999);
    expect(row.metValue, isNull);
    await unmount(tester);
  });

  testWidgets('Other requires a name and skips the MET estimate', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('addExerciseButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exerciseTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exerciseWeightField')), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Blocked: no name yet.
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('exerciseCustomNameField')),
      'Hiking',
    );
    await tester.enterText(find.byKey(const Key('exerciseKcalField')), '400');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Hiking · 30 min'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting a manual entry removes it', (tester) async {
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-24',
            weightKg: 80,
            createdAt: now,
          ),
        );
    await pump(tester);
    await tester.tap(find.byKey(const Key('addExerciseButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cycling, leisurely'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cycling, leisurely'), findsNothing);
    expect(find.text('No activity yet'), findsOneWidget);
    await unmount(tester);
  });
}
