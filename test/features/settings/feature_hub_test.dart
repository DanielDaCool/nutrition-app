import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/app_features.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/settings/feature_flags.dart';
import 'package:nutrition_app/features/settings/feature_hub.dart';
import 'package:nutrition_app/features/settings/settings_screen.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 25, 9);

Widget app(AppDatabase db, {List<Override> extra = const []}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
    ...extra,
  ],
  child: const MaterialApp(home: SettingsScreen()),
);

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> openHub(WidgetTester tester) async {
  await tester.tap(find.text('Feature hub'));
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
}

SwitchListTile tile(WidgetTester tester, AppFeature f) =>
    tester.widget<SwitchListTile>(find.byKey(Key('feature-${f.storageKey}')));

void main() {
  testWidgets('Settings has two tabs; Personal details comes first', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Personal details'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Feature hub'), findsOneWidget);
    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.byKey(const Key('targetsCard')), findsOneWidget);
    expect(find.byType(FeatureHub), findsNothing);

    await openHub(tester);
    expect(find.byType(FeatureHub), findsOneWidget);
    expect(find.byKey(const Key('profileForm')).hitTestable(), findsNothing);
    await unmount(tester);
  });

  testWidgets('Feature hub lists a switch per feature, all on by default', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    await openHub(tester);

    expect(
      find.byType(SwitchListTile),
      findsNWidgets(AppFeature.values.length),
    );
    for (final f in AppFeature.values) {
      expect(tile(tester, f).value, isTrue, reason: f.name);
      expect(tile(tester, f).onChanged, isNotNull, reason: f.name);
      expect(find.text(f.label), findsOneWidget);
      expect(find.text(f.description), findsOneWidget);
    }
    expect(find.textContaining('Not available in the web app.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('tapping a switch flips the provider and saves it', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    await openHub(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FeatureHub)),
    );

    await tester.tap(find.byKey(const Key('feature-recipes')));
    await settle(tester);
    expect(tile(tester, AppFeature.recipes).value, isFalse);
    expect(container.read(featureEnabledProvider(AppFeature.recipes)), isFalse);
    expect(await tester.runAsync(() => loadFeatureFlags(db)), {
      AppFeature.recipes: false,
    });

    await tester.tap(find.byKey(const Key('feature-recipes')));
    await settle(tester);
    expect(tile(tester, AppFeature.recipes).value, isTrue);
    expect(container.read(featureEnabledProvider(AppFeature.recipes)), isTrue);
    expect(await tester.runAsync(() => loadFeatureFlags(db)), {
      AppFeature.recipes: true,
    });
    await unmount(tester);
  });

  testWidgets('switches start from the stored flags', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      app(
        db,
        extra: [
          initialFeatureFlagsProvider.overrideWithValue(const {
            AppFeature.barcodeScan: false,
          }),
        ],
      ),
    );
    await settle(tester);
    await openHub(tester);
    expect(tile(tester, AppFeature.barcodeScan).value, isFalse);
    expect(tile(tester, AppFeature.recipes).value, isTrue);
    await unmount(tester);
  });

  testWidgets('on web an Android-only feature is shown off and disabled', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      app(db, extra: [isWebProvider.overrideWithValue(true)]),
    );
    await settle(tester);
    await openHub(tester);

    final activity = tile(tester, AppFeature.activity);
    expect(activity.value, isFalse);
    expect(activity.onChanged, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('feature-activity')),
        matching: find.textContaining('Not available in the web app.'),
      ),
      findsOneWidget,
    );
    // Tapping it does nothing.
    await tester.tap(find.byKey(const Key('feature-activity')));
    await settle(tester);
    expect(await tester.runAsync(() => loadFeatureFlags(db)), isEmpty);

    expect(tile(tester, AppFeature.recipes).value, isTrue);
    expect(tile(tester, AppFeature.recipes).onChanged, isNotNull);
    await unmount(tester);
  });

  testWidgets('a failed save puts the switch back and says so', (tester) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      app(db, extra: [featureFlagsProvider.overrideWith(_FailingFlags.new)]),
    );
    await settle(tester);
    await openHub(tester);

    await tester.tap(find.byKey(const Key('feature-recipes')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text("Couldn't save that setting"), findsOneWidget);
    expect(tile(tester, AppFeature.recipes).value, isTrue);
    await unmount(tester);
  });

  testWidgets('the profile form keeps its edit state across a tab switch', (
    tester,
  ) async {
    tallScreen(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('heightCm')), '181');

    await openHub(tester);
    await tester.tap(find.text('Personal details'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('heightCm')))
          .controller!
          .text,
      '181',
    );
    await unmount(tester);
  });
}

/// Feature flags whose save always fails, after the same optimistic update
/// and revert as the real notifier.
class _FailingFlags extends FeatureFlags {
  @override
  Future<void> setEnabled(AppFeature feature, bool enabled) async {
    final previous = state;
    state = {...state, feature: enabled};
    state = previous;
    throw StateError('save failed');
  }
}
