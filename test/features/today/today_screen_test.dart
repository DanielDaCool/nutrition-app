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
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          currentTargetsProvider.overrideWith((ref) => Stream.value(targets)),
          checkInDueProvider.overrideWith((ref) => Stream.value(checkInDue)),
          dayIntakeProvider.overrideWith(
            (ref, dayKey) => Stream.value(
              DayIntake(
                dayKey: dayKey,
                total: eaten,
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
    expect(
      find.text('Set up your profile in Settings to get calorie targets'),
      findsOneWidget,
    );
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
    // The day has a weigh-in now, so the quick row disappears.
    expect(field, findsNothing);

    await tester.tap(find.byKey(const Key('checkInBanner')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly check-in'), findsOneWidget);
    await unmount(tester);
  });
}
