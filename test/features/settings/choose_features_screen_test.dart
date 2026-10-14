import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/core/feature_choices_repository.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/settings/choose_features_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool web = false,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          isWebProvider.overrideWithValue(web),
          ...extra,
        ],
        child: const MaterialApp(home: ChooseFeaturesScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('every choosable feature is listed and ticked by default', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Choose features'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(12));
    for (final key in [
      'activity',
      'workouts',
      'recipes',
      'yesterdayPrompt',
      'dashboard',
      'walkReminders',
      'savedMeals',
      'quickCalories',
      'closeDayPrompt',
      'targetInsights',
      'csvExport',
      'labelScan',
    ]) {
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(Key('feature-$key')),
      );
      expect(tile.value, isTrue, reason: key);
    }
    expect(
      find.text('Turning a feature off only hides it; your data is kept.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('always-on and safety features are not listed', (tester) async {
    await pumpScreen(tester);
    for (final key in [
      'backup',
      'installHint',
      'reportProblem',
      'updateAvailable',
      'barcodeScan',
      'gainGoals',
    ]) {
      expect(find.byKey(Key('feature-$key')), findsNothing, reason: key);
    }
  });

  testWidgets('unticking Recipes stores the choice and the provider reads it', (
    tester,
  ) async {
    await pumpScreen(tester);
    ProviderContainer container() => ProviderScope.containerOf(
      tester.element(find.byType(ChooseFeaturesScreen)),
    );
    expect(
      container().read(featureEnabledProvider(AppFeature.recipes)),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('feature-recipes')));
    await waitForWrite(tester);

    final tile = tester.widget<CheckboxListTile>(
      find.byKey(const Key('feature-recipes')),
    );
    expect(tile.value, isFalse);
    expect(await tester.runAsync(() => watchDisabledFeatureKeys(db).first), {
      'recipes',
    });
    expect(
      container().read(featureEnabledProvider(AppFeature.recipes)),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticking a feature back on removes it from the stored choice', (
    tester,
  ) async {
    await tester.runAsync(
      () => setFeatureEnabled(db, AppFeature.dashboard, false),
    );
    await pumpScreen(tester);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('feature-dashboard')))
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('feature-dashboard')));
    await waitForWrite(tester);
    expect(
      await tester.runAsync(() => watchDisabledFeatureKeys(db).first),
      isEmpty,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('feature-dashboard')))
          .value,
      isTrue,
    );
  });

  testWidgets('on web, Steps, Workouts and Walk reminder are not listed', (
    tester,
  ) async {
    await pumpScreen(tester, web: true);
    expect(find.byKey(const Key('feature-activity')), findsNothing);
    expect(find.byKey(const Key('feature-workouts')), findsNothing);
    expect(find.byKey(const Key('feature-walkReminders')), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(8));
    expect(find.byKey(const Key('feature-recipes')), findsOneWidget);
    expect(find.byKey(const Key('feature-yesterdayPrompt')), findsOneWidget);
    expect(find.byKey(const Key('feature-dashboard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

/// Gives a write started by a tap real time to reach the database, then
/// lets the stream update the screen.
Future<void> waitForWrite(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await settle(tester);
}
