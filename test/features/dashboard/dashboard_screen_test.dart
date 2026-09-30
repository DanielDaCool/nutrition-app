import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/dashboard/dashboard_logic.dart';
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

  Future<void> addProfileAndWeighIn() async {
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            sex: 0,
            birthDate: DateTime(1990),
            heightCm: 180,
            activityLevel: 1,
            goalWeightKg: 78,
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-09-25',
            weightKg: 82,
            createdAt: DateTime(2026, 9, 25),
          ),
        );
  }

  testWidgets('empty database shows one setup card, not empty charts', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Add your first weigh-in'), findsOneWidget);
    expect(find.textContaining('No fully logged days'), findsNothing);
    expect(find.textContaining('No step data'), findsNothing);
    expect(find.textContaining('No workouts in this range'), findsNothing);
    expect(find.textContaining('No maintenance estimate yet'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // The weigh-in step opens the dialog and saves.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('weighInKgField')), '82.4');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await db.select(db.weighIns).get()).single.weightKg, 82.4);
    expect(find.text('Add your first weigh-in'), findsOneWidget); // done ✓
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
    await unmount(tester);
  });

  testWidgets('after setup, empty sections explain and offer a fix', (
    tester,
  ) async {
    await addProfileAndWeighIn();
    await pumpDashboard(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Finish setup'), findsNothing);
    expect(
      find.text('Your trend appears after a few weigh-ins'),
      findsOneWidget,
    );
    expect(find.text('Add weigh-in'), findsOneWidget);
    expect(find.textContaining('No fully logged days'), findsOneWidget);
    expect(find.textContaining('No step data'), findsOneWidget);
    expect(find.byKey(const Key('connectHealthConnect')), findsOneWidget);
    expect(find.textContaining('No workouts in this range'), findsOneWidget);
    expect(find.textContaining('No maintenance estimate yet'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);

    for (final label in ['12 weeks', 'All', '4 weeks']) {
      await tester.tap(find.text(label));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    }
    await unmount(tester);
  });

  testWidgets(
    'connected but no step data shows an empty state, not the connect CTA',
    (tester) async {
      // Bug: Health Connect is already connected, but there's just no step
      // data in range yet (e.g. a fresh emulator) — the steps card used to
      // show "Connect Health Connect" regardless of connection status.
      await addProfileAndWeighIn();
      await pumpDashboard(
        tester,
        extra: [
          healthStatusProvider.overrideWith(
            () => _FixedHealthStatus(
              const HealthConnectStatus(HealthStatusKind.ok),
            ),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('No step data'), findsOneWidget);
      expect(find.byKey(const Key('connectHealthConnect')), findsNothing);
      await unmount(tester);
    },
  );

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
      expect(find.textContaining('No workouts in this range'), findsNothing);
      expect(find.textContaining('No maintenance estimate'), findsNothing);
      expect(find.text('kcal/day'), findsNWidgets(2));
      expect(find.text('steps'), findsOneWidget);
      // Headline numbers on each card.
      expect(find.textContaining(RegExp(r'^Trend \d+\.\d kg · ')), findsOne);
      expect(find.textContaining(RegExp(r'^Avg [\d,]+/day$')), findsOne);
      expect(
        find.textContaining(RegExp(r'^Avg 2,050 of [\d,]+ kcal$')),
        findsOne,
      );
      expect(find.textContaining(RegExp(r'^\d+ workouts · ')), findsOne);
      expect(find.text('Now 2,550 kcal/day'), findsOneWidget);

      await tester.tap(find.text('All'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    }
  });

  testWidgets(
    'workouts chart fetches full Monday-aligned weeks, not a partial '
    'first/last week',
    (tester) async {
      await addProfileAndWeighIn();
      final requestedWindows = <(String, String)>[];
      final extra = [
        activityRangeProvider.overrideWith((ref, r) {
          requestedWindows.add(r);
          return Stream.value(const []);
        }),
      ];
      await pumpDashboard(tester, extra: extra);
      expect(tester.takeException(), isNull);

      // The dashboard window itself: today - 27 .. today (not Monday-
      // aligned in general).
      const today = '2026-09-25';
      final plainWindow = (addDays(today, -27), today);
      expect(requestedWindows, contains(plainWindow));

      // The workouts chart fetches from the Monday on/before that `from`,
      // so every bucketed week (including the first) is a full 7 days.
      final chartWindow = (weekStartOf(plainWindow.$1), today);
      expect(chartWindow.$1, isNot(plainWindow.$1)); // the range isn't
      // already Monday-aligned, so this genuinely exercises the fix.
      expect(requestedWindows, contains(chartWindow));

      await unmount(tester);
    },
  );

  testWidgets(
    'steps chart fetches 6 lead-in days for a real trailing 7-day average',
    (tester) async {
      await addProfileAndWeighIn();
      final requestedWindows = <(String, String)>[];
      final extra = [
        activityRangeProvider.overrideWith((ref, r) {
          requestedWindows.add(r);
          return Stream.value(const []);
        }),
      ];
      await pumpDashboard(tester, extra: extra);
      expect(tester.takeException(), isNull);

      const today = '2026-09-25';
      final plainWindow = (addDays(today, -27), today);
      expect(requestedWindows, contains(plainWindow));

      final avgWindow = (addDays(plainWindow.$1, -6), today);
      expect(requestedWindows, contains(avgWindow));

      await unmount(tester);
    },
  );
}

/// Always reports a fixed [HealthConnectStatus], for testing status-driven UI.
class _FixedHealthStatus extends HealthStatusController {
  _FixedHealthStatus(this._status);
  final HealthConnectStatus _status;

  @override
  HealthConnectStatus build() => _status;
}
