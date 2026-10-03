import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/app.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/dashboard/dashboard_providers.dart';
import 'package:nutrition_app/features/dashboard/dashboard_screen.dart';
import 'package:nutrition_app/features/recipes/recipes_screen.dart';
import 'package:nutrition_app/features/settings/settings_screen.dart';
import 'package:nutrition_app/features/settings/setup_screen.dart';
import 'package:nutrition_app/features/today/today_screen.dart';
import 'package:nutrition_app/features/weight/weight_providers.dart';

import '../features/activity/fake_health_source.dart';
import '../helpers/test_db.dart';

/// Friday.
final now = DateTime(2026, 9, 25, 9);

Widget app(AppDatabase db, {List<Override> extra = const []}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
    healthSourceProvider.overrideWithValue(FakeHealthSource()),
    ...extra,
  ],
  child: const NutritionApp(),
);

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500)); // route animations
}

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
}

Future<void> seedProfile(AppDatabase db) => db
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

void main() {
  testWidgets(
    'a day rollover while backgrounded refreshes weight and dashboard',
    (tester) async {
      tallScreen(tester);
      final db = openTestDatabase();
      addTearDown(db.close);
      await tester.runAsync(() => seedProfile(db));
      var clock = DateTime(2026, 9, 25, 23, 50);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(() => clock),
            healthSourceProvider.overrideWithValue(FakeHealthSource()),
          ],
          child: const NutritionApp(),
        ),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavigationBar)),
      );
      final beforeWindow = await container.read(dashboardWindowProvider.future);
      final beforeTrend = await container.read(weightTrendProvider.future);
      expect(beforeWindow.$2, '2026-09-25');

      clock = DateTime(2026, 9, 26, 7, 30);
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

      final afterWindow = await container.read(dashboardWindowProvider.future);
      expect(afterWindow.$2, '2026-09-26');
      // The trend provider was invalidated too (new instance, same data).
      final afterTrend = await container.read(weightTrendProvider.future);
      expect(afterTrend, beforeTrend);
      await unmount(tester);
    },
  );

  testWidgets('app starts and switches tabs', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SetupScreen), findsNothing);
    // Dark only, even when the phone is in light mode (the test default).
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    for (final label in ['Weight', 'Dashboard', 'Settings', 'Today']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
    }
    await unmount(tester);
  });

  testWidgets('first start opens setup; Later closes it for the session', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setupLater')));
    await settle(tester);
    expect(find.byType(SetupScreen), findsNothing);

    // Still no profile, but no nagging within the same session.
    await tester.tap(find.text('Settings').last);
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    expect(find.byType(SetupScreen), findsNothing);
    await unmount(tester);
  });

  testWidgets('Save and start stores the profile and the first weigh-in', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    final setup = find.byType(SetupScreen);
    expect(setup, findsOneWidget);
    Finder inSetup(Finder f) => find.descendant(of: setup, matching: f);

    // Nothing filled in: validation stops it, nothing is saved.
    final save = inSetup(find.byKey(const Key('saveProfile')));
    expect(find.text('Save and start'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(find.text('Enter your weight to get your targets'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.profiles).get()), isEmpty);

    await tester.tap(inSetup(find.byKey(const Key('birthDate'))));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '09/25/1996',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(inSetup(find.byKey(const Key('heightCm'))), '180');
    await tester.enterText(
      inSetup(find.byKey(const Key('goalWeightKg'))),
      '80',
    );
    await tester.enterText(
      inSetup(find.byKey(const Key('setupWeightKg'))),
      '90',
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    expect(find.byType(SetupScreen), findsNothing);
    expect(
      find.text("You're all set. Your calorie target is on Today."),
      findsOneWidget,
    );
    final profile = await tester.runAsync(
      () => db.select(db.profiles).getSingle(),
    );
    expect(profile!.heightCm, 180);
    final weighIns = await tester.runAsync(() => db.select(db.weighIns).get());
    expect(weighIns!.single.dayKey, '2026-09-25');
    expect(weighIns.single.weightKg, 90);
    final targets = await tester.runAsync(
      () => db.select(db.targetHistory).get(),
    );
    expect(targets, hasLength(1));
    await unmount(tester);
  });

  testWidgets('Settings gets a badge when a check-in is due', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await seedProfile(db); // check-in on Sundays
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: '2026-09-24',
              weightKg: 90,
              createdAt: now,
            ),
          );
      // Last target from before Sunday the 20th: that check-in was missed.
      await db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: '2026-09-13',
              kcal: 2400,
              proteinG: 180,
              fatG: 70,
              carbsG: 270,
              maintenanceKcal: 2900,
              method: TargetMethod.formula.index,
              createdAt: now,
            ),
          );
    });
    await tester.pumpWidget(app(db));
    await settle(tester);
    final badge = tester.widget<Badge>(find.byKey(const Key('settingsBadge')));
    expect(badge.isLabelVisible, isTrue);
    await unmount(tester);
  });

  testWidgets('tapping Today again jumps back to today', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    expect(container.read(selectedDayProvider), '2026-09-25');
    await unmount(tester);
  });

  Finder destination(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.widgetWithText(NavigationDestination, label),
  );

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('the Recipes tab is there by default', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db));
    await settle(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(destination('Recipes'), findsOneWidget);
    expect(find.byType(RecipesScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(destination('Recipes'));
    await settle(tester);
    expect(selectedIndex(tester), 3);
    expect(find.byType(RecipesScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the Recipes tab is left out when switched off', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(
      app(
        db,
        extra: [
          featureEnabledProvider.overrideWith(
            (ref, f) => f != AppFeature.recipes,
          ),
        ],
      ),
    );
    await settle(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(destination('Recipes'), findsNothing);
    expect(find.byType(RecipesScreen, skipOffstage: false), findsNothing);

    // The remaining tabs still open the right screens.
    await tester.tap(destination('Settings'));
    await settle(tester);
    expect(selectedIndex(tester), 3);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    await tester.tap(destination('Dashboard'));
    await settle(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    await unmount(tester);
  });

  testWidgets('hiding Recipes while on Settings keeps Settings and its state', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db, extra: [recipesGate]));
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );

    await tester.tap(destination('Settings'));
    await settle(tester);
    expect(selectedIndex(tester), 4);
    // Put the profile form into a state that a rebuilt Settings would lose.
    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '71');
    final formState = tester.state(find.byKey(const Key('profileForm')));

    container.read(_recipesShown.notifier).set(false);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(destination('Recipes'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byType(RecipesScreen, skipOffstage: false), findsNothing);
    // Still on Settings (now the 4th tab), with the same form state.
    expect(selectedIndex(tester), 3);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.state(find.byKey(const Key('profileForm'))), same(formState));
    expect(find.byKey(const Key('saveProfile')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('goalWeightKg')))
          .controller!
          .text,
      '71',
    );

    // And back: Recipes returns, Settings is still selected and unchanged.
    container.read(_recipesShown.notifier).set(true);
    await settle(tester);
    expect(destination('Recipes'), findsOneWidget);
    expect(selectedIndex(tester), 4);
    expect(tester.state(find.byKey(const Key('profileForm'))), same(formState));
    expect(find.byKey(const Key('saveProfile')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a tab that is hidden while selected falls back to Today', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => seedProfile(db));
    await tester.pumpWidget(app(db, extra: [recipesGate]));
    await settle(tester);
    await tester.tap(destination('Recipes'));
    await settle(tester);
    expect(selectedIndex(tester), 3);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    container.read(_recipesShown.notifier).set(false);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(destination('Recipes'), findsNothing);
    expect(selectedIndex(tester), 0);
    expect(find.byType(TodayScreen), findsOneWidget);

    // Showing it again doesn't jump back to Recipes.
    container.read(_recipesShown.notifier).set(true);
    await settle(tester);
    expect(destination('Recipes'), findsOneWidget);
    expect(selectedIndex(tester), 0);
    await unmount(tester);
  });
}

/// Whether the Recipes gate is open, so a test can flip it while the app runs.
final _recipesShown = NotifierProvider<_RecipesShown, bool>(_RecipesShown.new);

class _RecipesShown extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool shown) => state = shown;
}

/// Gates Recipes on [_recipesShown]; every other feature stays on.
final recipesGate = featureEnabledProvider.overrideWith(
  (ref, f) => f != AppFeature.recipes || ref.watch(_recipesShown),
);
