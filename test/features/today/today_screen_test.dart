import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/food_providers.dart';
import 'package:nutrition_app/features/targets/targets_providers.dart';
import 'package:nutrition_app/features/today/today_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  const targets = DailyTargets(
    effectiveFrom: '2026-09-21',
    macros: Macros(kcal: 2000, proteinG: 150, fatG: 70, carbsG: 200),
    maintenanceKcal: 2500,
    method: TargetMethod.blended,
  );

  Future<void> pumpToday(
    WidgetTester tester, {
    DailyTargets? targets,
    Macros eaten = Macros.zero,
    bool checkInDue = false,
    DateTime Function()? clock,
    DayIntake Function(String dayKey)? intakeFor,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(
            clock ?? () => DateTime(2026, 9, 25, 12),
          ),
          currentTargetsProvider.overrideWith((ref) => Stream.value(targets)),
          checkInDueProvider.overrideWith((ref) => Stream.value(checkInDue)),
          dayIntakeProvider.overrideWith(
            (ref, dayKey) => Stream.value(
              intakeFor?.call(dayKey) ??
                  DayIntake(
                    dayKey: dayKey,
                    total: dayKey == '2026-09-25' ? eaten : Macros.zero,
                    byMeal: const {},
                    fullyLogged: false,
                  ),
            ),
          ),
        ],
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('shows the set-up-profile card when targets are null', (
    tester,
  ) async {
    await pumpToday(tester);
    expect(find.text('Get your daily calorie target'), findsOneWidget);
    expect(find.byKey(const Key('kcalRemaining')), findsNothing);
    expect(find.byKey(const Key('checkInBanner')), findsNothing);
    await unmount(tester);
  });

  testWidgets('remaining kcal = target - eaten, with macro progress', (
    tester,
  ) async {
    await pumpToday(
      tester,
      targets: targets,
      eaten: const Macros(kcal: 1234.4, proteinG: 80.2, fatG: 75, carbsG: 99.6),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('kcalRemaining'))).data,
      '766',
    );
    expect(find.text('kcal remaining'), findsOneWidget);
    expect(find.text('Target 2,000 kcal'), findsOneWidget);
    expect(find.text('Eaten 1,234 kcal'), findsOneWidget);
    expect(find.text('80 / 150 g'), findsOneWidget);
    expect(find.text('75 / 70 g'), findsOneWidget);
    expect(find.text('100 / 200 g'), findsOneWidget);

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((b) => b.value)
        .toList();
    expect(bars[0], closeTo(80.2 / 150, 1e-9));
    expect(bars[1], 1.0); // over target is clamped
    expect(bars[2], closeTo(99.6 / 200, 1e-9));
    await unmount(tester);
  });

  testWidgets('over target shows kcal over', (tester) async {
    await pumpToday(
      tester,
      targets: targets,
      eaten: const Macros(kcal: 2300, proteinG: 0, fatG: 0, carbsG: 0),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('kcalRemaining'))).data,
      '300',
    );
    expect(find.text('kcal over target'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('day navigation cannot go past today; header jumps back', (
    tester,
  ) async {
    await pumpToday(tester, targets: targets);
    expect(find.text('Today'), findsOneWidget);

    final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
    expect(tester.widget<IconButton>(next).onPressed, isNull);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Wed, 23 Sep'), findsOneWidget);

    await tester.tap(next);
    await tester.pump();
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todayHeader')));
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('date picker jumps straight to a past day', (tester) async {
    await pumpToday(tester, targets: targets);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pickDay')));
    await tester.pumpAndSettle();

    // Switch the picker to keyboard input and type the day directly.
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final dateField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'mm/dd/yyyy',
    );
    await tester.enterText(dateField, '09/20/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Sun, 20 Sep'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('check-in banner and quick weigh-in', (tester) async {
    await pumpToday(tester, targets: targets, checkInDue: true);
    expect(find.byKey(const Key('checkInBanner')), findsOneWidget);

    final field = find.byKey(const Key('quickWeighInField'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '81.7');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final rows = await db.select(db.weighIns).get();
    expect(rows.single.dayKey, '2026-09-25');
    expect(rows.single.weightKg, 81.7);
    // The day has a weigh-in now, so a compact summary replaces the field.
    expect(field, findsNothing);
    expect(find.text('Saved 81.7 kg'), findsOneWidget);
    expect(find.text('81.7 kg · trend 81.7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkInBanner')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly check-in'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> addWeighIn(String day, double kg) => db
      .into(db.weighIns)
      .insert(
        WeighInsCompanion.insert(
          dayKey: day,
          weightKg: kg,
          createdAt: DateTime(2026, 9, 25),
        ),
      );

  double topOf(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('morning weigh-in sits above the calorie card, with undo', (
    tester,
  ) async {
    await addWeighIn('2026-09-18', 83.0);
    await addWeighIn('2026-09-24', 82.4);
    await pumpToday(tester, targets: targets);

    final card = find.byKey(const Key('quickWeighInCard'));
    expect(card, findsOneWidget);
    expect(find.text('Last: 82.4'), findsOneWidget);
    expect(
      topOf(tester, card),
      lessThan(topOf(tester, find.byKey(const Key('kcalRemaining')))),
    );

    // Comma works, and Done on the keyboard saves.
    await tester.enterText(find.byKey(const Key('quickWeighInField')), '82,1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Saved 82.1 kg'), findsOneWidget);
    final row = find.byKey(const Key('weighInSummaryRow'));
    expect(row, findsOneWidget);
    expect(card, findsNothing);
    expect(
      topOf(tester, row),
      lessThan(topOf(tester, find.byKey(const Key('kcalRemaining')))),
    );
    // Trend: 83.0, +0.1*(82.4-83.0)=82.94, +0.1*(82.1-82.94)=82.856.
    expect(find.text('82.1 kg · trend 82.9 · −0.1 this week'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Undo'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final rows = await db.select(db.weighIns).get();
    expect(rows.map((r) => r.dayKey), isNot(contains('2026-09-25')));
    expect(find.byKey(const Key('quickWeighInCard')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping the weigh-in summary opens the edit dialog', (
    tester,
  ) async {
    await addWeighIn('2026-09-25', 82.4);
    await pumpToday(tester, targets: targets);
    await tester.tap(find.byKey(const Key('weighInSummaryRow')));
    await tester.pumpAndSettle();
    expect(find.text("Update today's weigh-in"), findsOneWidget);
    await tester.enterText(find.byKey(const Key('weighInKgField')), '82.0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final rows = await db.select(db.weighIns).get();
    expect(rows.single.weightKg, 82.0);
    await unmount(tester);
  });

  testWidgets('past days show a bar that jumps back to today', (tester) async {
    await pumpToday(tester, targets: targets);
    expect(find.byKey(const Key('pastDayBar')), findsNothing);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Viewing Wed 23 Sep'), findsOneWidget);

    await tester.tap(find.text('Back to today'));
    await tester.pump();
    expect(find.byKey(const Key('pastDayBar')), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('jumps to the new day when resumed after midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 25, 23, 50);
    await pumpToday(tester, targets: targets, clock: () => now);
    expect(find.text('Today'), findsOneWidget);

    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    now = DateTime(2026, 9, 26, 7, 30);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    await tester.pump();

    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(const Key('pastDayBar')), findsNothing);
    // Yesterday (the 25th) is reachable with the back arrow.
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Yesterday'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('stays on a past day when resumed after midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 25, 23, 50);
    await pumpToday(tester, targets: targets, clock: () => now);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();

    now = DateTime(2026, 9, 26, 7, 30);
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
    await tester.pump();
    expect(find.text('Viewing Thu 24 Sep'), findsOneWidget);
    await unmount(tester);
  });

  group('yesterday prompt', () {
    DayIntake intake(String dayKey, {required bool logged}) => DayIntake(
      dayKey: dayKey,
      total: dayKey == '2026-09-24'
          ? const Macros(kcal: 1800, proteinG: 0, fatG: 0, carbsG: 0)
          : Macros.zero,
      byMeal: const {},
      fullyLogged: logged,
    );

    testWidgets('Yes marks yesterday fully logged and hides the prompt', (
      tester,
    ) async {
      await pumpToday(
        tester,
        targets: targets,
        intakeFor: (d) => intake(d, logged: false),
      );
      expect(find.text('Was yesterday complete?'), findsOneWidget);

      await tester.tap(find.text('Yes, mark it'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('yesterdayPrompt')), findsNothing);
      final status = await db.select(db.dayStatuses).getSingle();
      expect(status.dayKey, '2026-09-24');
      expect(status.fullyLogged, isTrue);
      expect(find.text('Yesterday marked as complete'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Not really just hides it', (tester) async {
      await pumpToday(
        tester,
        targets: targets,
        intakeFor: (d) => intake(d, logged: false),
      );
      await tester.tap(find.text('Not really'));
      await tester.pump();
      expect(find.byKey(const Key('yesterdayPrompt')), findsNothing);
      expect(await db.select(db.dayStatuses).get(), isEmpty);
      await unmount(tester);
    });

    testWidgets('not shown when yesterday is already complete or empty', (
      tester,
    ) async {
      await pumpToday(
        tester,
        targets: targets,
        intakeFor: (d) => intake(d, logged: true),
      );
      expect(find.byKey(const Key('yesterdayPrompt')), findsNothing);
      await unmount(tester);

      await pumpToday(tester, targets: targets);
      expect(find.byKey(const Key('yesterdayPrompt')), findsNothing);
      await unmount(tester);
    });
  });
}
