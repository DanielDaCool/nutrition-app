import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/dashboard/dashboard_screen.dart';
import 'package:nutrition_app/features/food/food_providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<Override> extra = const [],
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          ...extra,
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D5B),
              brightness: brightness,
            ),
          ),
          home: const DashboardScreen(),
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

  testWidgets('empty database shows every empty state without errors', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('No weigh-ins in this range yet'), findsOneWidget);
    expect(find.textContaining('No fully logged days'), findsOneWidget);
    expect(find.textContaining('No step data'), findsOneWidget);
    expect(find.text('No workouts in this range'), findsOneWidget);
    expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);

    for (final label in ['12 weeks', 'All', '4 weeks']) {
      await tester.tap(find.text(label));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    }
    await unmount(tester);
  });

  testWidgets('renders charts with data in light and dark', (tester) async {
    for (var i = 0; i < 40; i++) {
      final day = addDays('2026-09-25', -i);
      if (i % 2 == 0) {
        await db
            .into(db.weighIns)
            .insert(
              WeighInsCompanion.insert(
                dayKey: day,
                weightKg: 85 + i * 0.05,
                createdAt: DateTime(2026, 9, 25),
              ),
            );
      }
    }
    for (final (from, m) in [('2026-08-20', 2600.0), ('2026-09-14', 2550.0)]) {
      await db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: from,
              kcal: m - 500,
              proteinG: 150,
              fatG: 70,
              carbsG: 200,
              maintenanceKcal: m,
              method: 1,
              createdAt: DateTime(2026, 9, 25),
            ),
          );
    }
    List<String> daysOf((String, String) r) => [
      for (var d = r.$1; d.compareTo(r.$2) <= 0; d = addDays(d, 1)) d,
    ];
    final extra = [
      intakeRangeProvider.overrideWith(
        (ref, r) => Stream.value([
          for (final d in daysOf(r))
            DayIntake(
              dayKey: d,
              total: const Macros(kcal: 2050, proteinG: 0, fatG: 0, carbsG: 0),
              byMeal: const {},
              fullyLogged: startOfDay(d).day.isEven,
            ),
        ]),
      ),
      activityRangeProvider.overrideWith(
        (ref, r) => Stream.value([
          for (final d in daysOf(r))
            DayActivity(
              dayKey: d,
              steps: d.endsWith('0') ? null : 8000 + startOfDay(d).day * 100,
              workouts: [
                if (d.endsWith('3'))
                  WorkoutSummary(
                    id: d,
                    title: 'Strength',
                    start: DateTime(2026, 9, 1, 18),
                    end: DateTime(2026, 9, 1, 19),
                  ),
              ],
            ),
        ]),
      ),
    ];

    for (final brightness in Brightness.values) {
      await pumpDashboard(tester, extra: extra, brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('No weigh-ins in this range yet'), findsNothing);
      expect(find.textContaining('No step data'), findsNothing);
      expect(find.text('No workouts in this range'), findsNothing);
      expect(find.textContaining('No maintenance estimate'), findsNothing);
      expect(find.text('kcal/day'), findsNWidgets(2));
      expect(find.text('steps'), findsOneWidget);

      await tester.tap(find.text('All'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    }
  });
}
