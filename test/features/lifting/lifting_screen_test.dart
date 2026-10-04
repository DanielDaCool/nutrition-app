import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/lifting_providers.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';
import 'package:nutrition_app/features/lifting/lifting_screen.dart';
import 'package:nutrition_app/features/lifting/widgets/lift_entry_card.dart';

import '../../helpers/test_db.dart';

const today = '2026-10-04';

void main() {
  late AppDatabase db;
  late LiftingRepository repo;
  late DateTime now;

  setUp(() {
    db = openTestDatabase();
    now = DateTime(2026, 10, 4, 9);
    repo = LiftingRepository(db, () => now);
  });
  tearDown(() => db.close());

  /// Lets drift's queries and stream updates finish between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500)); // route animations
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const LiftingScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<int> exercise(
    WidgetTester tester,
    String name, {
    MuscleGroup group = MuscleGroup.chest,
    bool bodyweight = false,
  }) => run(
    tester,
    () => repo.addExercise(
      name: name,
      muscleGroup: group,
      isBodyweight: bodyweight,
    ),
  );

  /// Plans [exerciseId] on [dayKey] and tracks [sets] as (weightKg, reps).
  Future<int> entry(
    WidgetTester tester,
    String dayKey,
    int exerciseId, [
    List<(double, int)> sets = const [],
  ]) => run(tester, () async {
    final id = await repo.addEntry(dayKey, exerciseId);
    for (final (weightKg, reps) in sets) {
      await repo.addSet(id, reps: reps, weightKg: weightKg);
    }
    return id;
  });

  Future<List<LiftEntry>> dayOf(WidgetTester tester, String dayKey) =>
      run(tester, () => repo.watchDay(dayKey).first);

  /// The exercise names on screen, top to bottom.
  List<String> shownOrder(WidgetTester tester) => [
    for (final card in tester.widgetList<LiftEntryCard>(
      find.byType(LiftEntryCard),
    ))
      card.entry.exercise.name,
  ];

  Future<void> openEntryMenu(
    WidgetTester tester,
    int entryId,
    String item,
  ) async {
    await tester.tap(find.byKey(ValueKey('liftEntryMenu-$entryId')));
    await settle(tester);
    await tester.tap(find.text(item));
    await settle(tester);
  }

  Future<void> fillSet(
    WidgetTester tester, {
    required String weight,
    required String reps,
  }) async {
    await tester.enterText(find.byKey(const Key('liftSetWeight')), weight);
    await tester.enterText(find.byKey(const Key('liftSetReps')), reps);
    await tester.tap(find.byKey(const Key('liftSetSave')));
    await settle(tester);
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('an empty day shows the empty state with both buttons', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No exercises planned'), findsOneWidget);
    expect(
      find.text('Add exercises or load a preset to get started.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('liftAddExercise')), findsOneWidget);
    expect(find.byKey(const Key('liftLoadPreset')), findsOneWidget);
    expect(find.byType(LiftEntryCard), findsNothing);

    // Nothing on the day: it can't be saved as a preset.
    await tester.tap(find.byKey(const Key('liftMenu')));
    await settle(tester);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);
    final save = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text('Save day as preset'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(save.enabled, isFalse);
    await unmount(tester);
  });

  testWidgets('a seeded day shows names, muscle groups and sets', (
    tester,
  ) async {
    final bench = await exercise(tester, 'Bench press');
    final dips = await exercise(
      tester,
      'Dips',
      group: MuscleGroup.triceps,
      bodyweight: true,
    );
    final fly = await exercise(tester, 'Cable fly');
    await entry(tester, today, bench, [(60, 7), (62.5, 4)]);
    await entry(tester, today, dips, [(0, 8), (20, 6)]);
    await entry(tester, today, fly);

    await pumpScreen(tester);
    expect(shownOrder(tester), ['Bench press', 'Dips', 'Cable fly']);
    expect(find.text('Chest'), findsNWidgets(2));
    expect(find.text('Triceps · Bodyweight'), findsOneWidget);
    expect(find.text('60 kg × 7'), findsOneWidget);
    expect(find.text('62.5 kg × 4'), findsOneWidget);
    expect(find.text('BW × 8'), findsOneWidget);
    expect(find.text('BW + 20 kg × 6'), findsOneWidget);
    expect(find.text('Set 1'), findsNWidgets(2));
    expect(find.text('Set 2'), findsNWidgets(2));
    // Tracked vs only planned.
    expect(find.text('2 sets'), findsNWidgets(2));
    expect(find.text('Planned'), findsOneWidget);
    // No earlier session of any of them.
    expect(find.text('First time'), findsNWidgets(3));
    expect(find.text('No exercises planned'), findsNothing);
    await unmount(tester);
  });

  testWidgets('adding a set through the dialog stores it', (tester) async {
    final bench = await exercise(tester, 'Bench press');
    final id = await entry(tester, today, bench);
    await pumpScreen(tester);

    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);
    expect(find.text('Set 1'), findsOneWidget); // dialog title
    expect(find.text('Weight (kg)'), findsOneWidget);
    await fillSet(tester, weight: '62,5', reps: '7');

    expect(find.text('62.5 kg × 7'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
    var sets = (await dayOf(tester, today)).single.sets;
    expect(sets.single.reps, 7);
    expect(sets.single.weightKg, 62.5);

    // The next set starts from the previous one.
    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);
    expect(fieldText(tester, 'liftSetWeight'), '62.5');
    expect(fieldText(tester, 'liftSetReps'), '7');
    await fillSet(tester, weight: '62.5', reps: '4');

    sets = (await dayOf(tester, today)).single.sets;
    expect(
      [for (final s in sets) (s.weightKg, s.reps)],
      [(62.5, 7), (62.5, 4)],
    );
    expect(find.text('62.5 kg × 4'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a bodyweight set takes extra weight, empty for none', (
    tester,
  ) async {
    final dips = await exercise(tester, 'Dips', bodyweight: true);
    final id = await entry(tester, today, dips);
    await pumpScreen(tester);

    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);
    expect(find.text('Extra weight (kg)'), findsOneWidget);
    await fillSet(tester, weight: '', reps: '8');
    expect(find.text('BW × 8'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);
    // No extra weight shows as an empty field, not "0".
    expect(fieldText(tester, 'liftSetWeight'), '');
    await fillSet(tester, weight: '20', reps: '6');
    expect(find.text('BW + 20 kg × 6'), findsOneWidget);

    final sets = (await dayOf(tester, today)).single.sets;
    expect([for (final s in sets) (s.weightKg, s.reps)], [(0.0, 8), (20.0, 6)]);
    await unmount(tester);
  });

  testWidgets('the first set starts from last time\'s first set', (
    tester,
  ) async {
    final bench = await exercise(tester, 'Bench press');
    await entry(tester, '2026-09-28', bench, [(60, 7), (55, 6)]);
    final id = await entry(tester, today, bench);
    await pumpScreen(tester);

    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);
    expect(fieldText(tester, 'liftSetWeight'), '60');
    expect(fieldText(tester, 'liftSetReps'), '7');
    await tester.tap(find.byKey(const Key('liftSetCancel')));
    await settle(tester);
    expect((await dayOf(tester, today)).single.sets, isEmpty);
    await unmount(tester);
  });

  testWidgets('editing and deleting a set', (tester) async {
    final bench = await exercise(tester, 'Bench press');
    await entry(tester, today, bench, [(60, 7), (60, 4)]);
    await pumpScreen(tester);
    var sets = (await dayOf(tester, today)).single.sets;

    await tester.tap(find.byKey(ValueKey('liftSet-${sets[1].id}')));
    await settle(tester);
    expect(find.text('Set 2'), findsNWidgets(2)); // row + dialog title
    expect(fieldText(tester, 'liftSetWeight'), '60');
    expect(fieldText(tester, 'liftSetReps'), '4');
    await fillSet(tester, weight: '57.5', reps: '5');

    expect(find.text('57.5 kg × 5'), findsOneWidget);
    expect(find.text('60 kg × 4'), findsNothing);
    sets = (await dayOf(tester, today)).single.sets;
    expect(
      [for (final s in sets) (s.weightKg, s.reps)],
      [(60.0, 7), (57.5, 5)],
    );

    await tester.tap(find.byKey(ValueKey('liftSet-${sets[0].id}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('liftSetDelete')));
    await settle(tester);

    expect(find.text('60 kg × 7'), findsNothing);
    // The remaining set is renumbered.
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsNothing);
    sets = (await dayOf(tester, today)).single.sets;
    expect([for (final s in sets) (s.weightKg, s.reps)], [(57.5, 5)]);
    await unmount(tester);
  });

  testWidgets('validation rejects 0 reps and a bad weight', (tester) async {
    final bench = await exercise(tester, 'Bench press');
    final id = await entry(tester, today, bench);
    await pumpScreen(tester);
    await tester.tap(find.byKey(ValueKey('liftAddSet-$id')));
    await settle(tester);

    await fillSet(tester, weight: '60', reps: '0');
    expect(find.text('Enter a whole number above 0'), findsOneWidget);
    expect(find.byKey(const Key('liftSetSave')), findsOneWidget);

    await fillSet(tester, weight: '60', reps: '7.5');
    expect(find.text('Enter a whole number above 0'), findsOneWidget);

    await fillSet(tester, weight: 'abc', reps: '7');
    expect(find.text('Enter a weight of 0 kg or more'), findsOneWidget);
    expect(find.text('Enter a whole number above 0'), findsNothing);

    await fillSet(tester, weight: '-5', reps: '7');
    expect(find.text('Enter a weight of 0 kg or more'), findsOneWidget);

    // Not a bodyweight exercise: the weight can't be left empty.
    await fillSet(tester, weight: '', reps: '');
    expect(find.text('Enter the weight'), findsOneWidget);
    expect(find.text('Enter the reps'), findsOneWidget);
    expect((await dayOf(tester, today)).single.sets, isEmpty);

    await fillSet(tester, weight: '0', reps: '12');
    expect(find.byKey(const Key('liftSetSave')), findsNothing);
    expect(find.text('0 kg × 12'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the Last line lists every set of the previous session', (
    tester,
  ) async {
    final bench = await exercise(tester, 'Bench press');
    final dips = await exercise(tester, 'Dips', bodyweight: true);
    // An older session that must not be shown.
    await entry(tester, '2026-09-21', bench, [(50, 10)]);
    await entry(tester, '2026-09-28', bench, [(60, 7), (60, 4), (55, 6)]);
    await entry(tester, '2026-09-30', dips, [(0, 8), (10, 5)]);
    // Planned but never tracked: doesn't count as "last time".
    await entry(tester, '2026-10-02', bench);
    // A later session isn't "last" either.
    await entry(tester, '2026-10-10', bench, [(70, 3)]);
    final benchToday = await entry(tester, today, bench, [(62.5, 7)]);
    final dipsToday = await entry(tester, today, dips);

    await pumpScreen(tester);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('liftLast-$benchToday'))).data,
      'Last (28 Sep): 60 kg × 7 · 60 kg × 4 · 55 kg × 6',
    );
    expect(
      tester.widget<Text>(find.byKey(ValueKey('liftLast-$dipsToday'))).data,
      'Last (30 Sep): BW × 8 · BW + 10 kg × 5',
    );
    expect(find.text('First time'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a future day can be reached and shows its plan', (tester) async {
    final squat = await exercise(tester, 'Squat', group: MuscleGroup.quads);
    final bench = await exercise(tester, 'Bench press');
    await entry(tester, '2026-10-05', squat);
    await entry(tester, '2026-10-03', bench, [(60, 7)]);
    await pumpScreen(tester);
    expect(find.text('No exercises planned'), findsOneWidget);

    await tester.tap(find.byKey(const Key('liftNextDay')));
    await settle(tester);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(shownOrder(tester), ['Squat']);
    expect(find.text('Planned'), findsOneWidget);

    await tester.tap(find.byKey(const Key('liftNextDay')));
    await settle(tester);
    expect(find.text('Tue, 6 Oct'), findsOneWidget);
    expect(find.text('No exercises planned'), findsOneWidget);
    expect(
      find.text('Plan this day: add exercises or load a preset.'),
      findsOneWidget,
    );

    // The title jumps back to today; the back arrow reaches past days.
    await tester.tap(find.byKey(const Key('liftHeader')));
    await settle(tester);
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('liftPrevDay')));
    await settle(tester);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(shownOrder(tester), ['Bench press']);
    await unmount(tester);
  });

  testWidgets('the date picker allows a future day', (tester) async {
    final squat = await exercise(tester, 'Squat', group: MuscleGroup.quads);
    await entry(tester, '2026-10-20', squat);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('liftPickDay')));
    await settle(tester);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.text('Tue, 20 Oct'), findsOneWidget);
    expect(shownOrder(tester), ['Squat']);
    await unmount(tester);
  });

  testWidgets('the next-day arrow stops a year ahead', (tester) async {
    await pumpScreen(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiftingScreen)),
    );
    IconButton next() =>
        tester.widget<IconButton>(find.byKey(const Key('liftNextDay')));

    container.read(liftSelectedDayProvider.notifier).set('2027-10-03');
    await settle(tester);
    expect(next().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('liftNextDay')));
    await settle(tester);
    expect(container.read(liftSelectedDayProvider), '2027-10-04');
    expect(next().onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('removing a planned entry needs no confirmation', (tester) async {
    final bench = await exercise(tester, 'Bench press');
    final fly = await exercise(tester, 'Cable fly');
    final benchEntry = await entry(tester, today, bench);
    await entry(tester, today, fly);
    await pumpScreen(tester);

    await openEntryMenu(tester, benchEntry, 'Remove');
    expect(find.byKey(const Key('liftConfirmRemove')), findsNothing);
    expect(shownOrder(tester), ['Cable fly']);
    expect(
      [for (final e in await dayOf(tester, today)) e.exercise.name],
      ['Cable fly'],
    );
    await unmount(tester);
  });

  testWidgets('removing an entry with sets asks first', (tester) async {
    final bench = await exercise(tester, 'Bench press');
    final id = await entry(tester, today, bench, [(60, 7), (60, 4)]);
    await pumpScreen(tester);

    await openEntryMenu(tester, id, 'Remove');
    expect(find.text('Remove Bench press?'), findsOneWidget);
    expect(
      find.text('Its 2 tracked sets on this day are deleted too.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await dayOf(tester, today), hasLength(1));

    await openEntryMenu(tester, id, 'Remove');
    await tester.tap(find.byKey(const Key('liftConfirmRemove')));
    await settle(tester);
    expect(await dayOf(tester, today), isEmpty);
    expect(find.text('No exercises planned'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('move up and move down change the order', (tester) async {
    final ids = <int>[];
    for (final name in ['Bench press', 'Cable fly', 'Dips']) {
      ids.add(await entry(tester, today, await exercise(tester, name)));
    }
    await pumpScreen(tester);
    expect(shownOrder(tester), ['Bench press', 'Cable fly', 'Dips']);

    await openEntryMenu(tester, ids[2], 'Move up');
    expect(shownOrder(tester), ['Bench press', 'Dips', 'Cable fly']);

    await openEntryMenu(tester, ids[0], 'Move down');
    expect(shownOrder(tester), ['Dips', 'Bench press', 'Cable fly']);
    expect(
      [for (final e in await dayOf(tester, today)) e.exercise.name],
      ['Dips', 'Bench press', 'Cable fly'],
    );

    // The first can't move up, the last can't move down.
    await tester.tap(find.byKey(ValueKey('liftEntryMenu-${ids[2]}')));
    await settle(tester);
    PopupMenuItem<Object?> item(String text) => tester.widget(
      find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(item('Move up').enabled, isFalse);
    expect(item('Move down').enabled, isTrue);
    await unmount(tester);
  });

  testWidgets('save day as preset, and a taken name is reported inline', (
    tester,
  ) async {
    final bench = await exercise(tester, 'Bench press');
    final fly = await exercise(tester, 'Cable fly');
    await entry(tester, today, bench);
    await entry(tester, today, fly);
    await run(tester, () => repo.createPreset('Push day', [bench]));
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('liftMenu')));
    await settle(tester);
    await tester.tap(find.text('Save day as preset'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('liftPresetSave')));
    await settle(tester);
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('liftPresetName')), 'push day');
    await tester.tap(find.byKey(const Key('liftPresetSave')));
    await settle(tester);
    expect(
      find.text('You already have a preset named "push day"'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('liftPresetName')), 'Chest');
    await tester.tap(find.byKey(const Key('liftPresetSave')));
    await settle(tester);
    expect(find.byKey(const Key('liftPresetName')), findsNothing);
    expect(find.text('Saved preset Chest'), findsOneWidget);

    final presets = await run(tester, () => repo.watchPresets().first);
    final saved = presets.singleWhere((p) => p.name == 'Chest');
    expect(
      [for (final e in saved.exercises) e.name],
      ['Bench press', 'Cable fly'],
    );
    await unmount(tester);
  });

  testWidgets('a day rollover while on today follows to the new today', (
    tester,
  ) async {
    final bench = await exercise(tester, 'Bench press');
    await entry(tester, '2026-10-05', bench);
    await pumpScreen(tester);
    expect(find.text('No exercises planned'), findsOneWidget);

    now = DateTime(2026, 10, 5, 7);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(shownOrder(tester), ['Bench press']);
    await unmount(tester);
  });

  test('formatLiftDay names tomorrow', () {
    expect(formatLiftDay('2026-10-04', today), 'Today');
    expect(formatLiftDay('2026-10-05', today), 'Tomorrow');
    expect(formatLiftDay('2026-10-03', today), 'Yesterday');
    expect(formatLiftDay('2026-10-06', today), 'Tue, 6 Oct');
    expect(formatLiftDay('2027-01-02', today), 'Sat, 2 Jan 2027');
  });
}
