import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/activity/widgets/activity_card.dart';

import '../../helpers/test_db.dart';
import 'fake_health_source.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 25, 10, 30);

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  /// One day with 4321 steps and one synced run.
  final day = DayActivity(
    dayKey: '2026-09-25',
    steps: 4321,
    workouts: [
      WorkoutSummary(
        id: 'run-1',
        title: 'Run',
        start: DateTime(2026, 9, 25, 7),
        end: DateTime(2026, 9, 25, 7, 30),
      ),
    ],
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          healthSourceProvider.overrideWithValue(FakeHealthSource()),
          dayActivityProvider.overrideWith((ref, dayKey) => Stream.value(day)),
          ...extra,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [ActivityCard(dayKey: '2026-09-25')],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Override gates({required bool steps, required bool workouts}) =>
      featureEnabledProvider.overrideWith(
        (ref, f) => switch (f) {
          AppFeature.activity => steps,
          AppFeature.workouts => workouts,
          _ => true,
        },
      );

  testWidgets('both parts on: steps, the run and the add button', (
    tester,
  ) async {
    await pumpCard(tester, extra: [gates(steps: true, workouts: true)]);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('steps'), findsOneWidget);
    expect(find.text('Run · 30 min'), findsOneWidget);
    expect(find.byKey(const Key('addExerciseButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Steps off: the card keeps the workouts and the add button', (
    tester,
  ) async {
    await pumpCard(tester, extra: [gates(steps: false, workouts: true)]);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('steps'), findsNothing);
    expect(find.byKey(const Key('stepGoalProgress')), findsNothing);
    expect(find.text('Run · 30 min'), findsOneWidget);
    expect(find.byKey(const Key('addExerciseButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'Workouts off: the card keeps steps, without the run or add button',
    (tester) async {
      await pumpCard(tester, extra: [gates(steps: true, workouts: false)]);
      expect(find.text('steps'), findsOneWidget);
      expect(find.text('Run · 30 min'), findsNothing);
      expect(find.byKey(const Key('addExerciseButton')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('both off: the card renders nothing', (tester) async {
    await pumpCard(tester, extra: [gates(steps: false, workouts: false)]);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('steps'), findsNothing);
    expect(find.text('Run · 30 min'), findsNothing);
    expect(find.byKey(const Key('addExerciseButton')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
