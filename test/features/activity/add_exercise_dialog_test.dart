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

  Future<void> addWeighIn80() => db
      .into(db.weighIns)
      .insert(
        WeighInsCompanion.insert(
          dayKey: '2026-09-24',
          weightKg: 80,
          createdAt: now,
        ),
      );

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

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('addExerciseButton')));
    await tester.pumpAndSettle();
  }

  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('exerciseTypeField')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label).last); // the menu scrolls
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a bike ride is estimated from its MET and body weight', (
    tester,
  ) async {
    await addWeighIn80();
    await pump(tester);
    await openDialog(tester);
    await selectType(tester, 'Cycling, leisurely');

    // 6.8 MET * 80 kg * 0.5 h = 272 kcal.
    expect(fieldText(tester, 'exerciseKcalField'), '272');
    expect(find.byKey(const Key('exerciseSpeedField')), findsNothing);
    await save(tester);

    expect(find.text('Cycling, leisurely · 30 min'), findsOneWidget);
    expect(find.text('272 kcal · manual'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('treadmill walk: speed and incline give distance and kcal', (
    tester,
  ) async {
    await addWeighIn80();
    await pump(tester);
    await openDialog(tester); // Treadmill walk is the default

    await tester.enterText(
      find.byKey(const Key('exerciseDurationField')),
      '60',
    );
    await tester.enterText(find.byKey(const Key('exerciseSpeedField')), '5');
    await tester.enterText(find.byKey(const Key('exerciseInclineField')), '10');
    await tester.pump();

    expect(fieldText(tester, 'exerciseDistanceField'), '5');
    // ACSM walk: (3.5 + 8.333 + 15) ml/kg/min * 80 kg * 5 kcal/L * 60 min.
    expect(fieldText(tester, 'exerciseKcalField'), '644');
    await save(tester);

    expect(find.text('Treadmill walk · 1 h'), findsOneWidget);
    expect(
      find.text('5 km · 5 km/h · 10% incline · 644 kcal · manual'),
      findsOneWidget,
    );
    final row = await db.select(db.manualExercises).getSingle();
    expect(row.distanceKm, closeTo(5, 1e-9));
    expect(row.inclinePct, 10);
    expect(row.metValue, isNull);
    await unmount(tester);
  });

  testWidgets('outdoor walk: distance and time give the speed', (tester) async {
    await addWeighIn80();
    await pump(tester);
    await openDialog(tester);
    await selectType(tester, 'Walk');

    await tester.enterText(
      find.byKey(const Key('exerciseDistanceField')),
      '2.5',
    );
    await tester.pump();

    expect(fieldText(tester, 'exerciseSpeedField'), '5');
    // Half of the flat 5 km/h hour (284 kcal).
    expect(fieldText(tester, 'exerciseKcalField'), '142');
    await save(tester);

    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text('2.5 km · 5 km/h · 142 kcal · manual'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a walk needs a distance or a speed', (tester) async {
    await addWeighIn80();
    await pump(tester);
    await openDialog(tester);
    await save(tester);

    expect(find.text('Enter distance or speed'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('typing calories overrides the estimate, no weight needed', (
    tester,
  ) async {
    await pump(tester);
    await openDialog(tester);

    await tester.enterText(find.byKey(const Key('exerciseKcalField')), '999');
    await save(tester);

    expect(find.text('999 kcal · manual'), findsOneWidget);
    final row = await db.select(db.manualExercises).getSingle();
    expect(row.kcal, 999);
    expect(row.metValue, isNull);
    await unmount(tester);
  });

  testWidgets('Other requires a name and skips the estimate', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await selectType(tester, 'Other');

    expect(find.byKey(const Key('exerciseWeightField')), findsNothing);
    await save(tester);
    expect(find.byType(AlertDialog), findsOneWidget); // no name yet

    await tester.enterText(
      find.byKey(const Key('exerciseCustomNameField')),
      'Hiking',
    );
    await tester.enterText(find.byKey(const Key('exerciseKcalField')), '400');
    await save(tester);

    expect(find.text('Hiking · 30 min'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting a manual entry removes it', (tester) async {
    await addWeighIn80();
    await pump(tester);
    await openDialog(tester);
    await selectType(tester, 'Cycling, leisurely');
    await save(tester);

    expect(find.textContaining('Cycling, leisurely'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cycling, leisurely'), findsNothing);
    expect(find.text('No activity yet'), findsOneWidget);
    await unmount(tester);
  });
}
