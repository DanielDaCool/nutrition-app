import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/widgets/health_connect_tile.dart';
import 'package:nutrition_app/features/settings/setup_screen.dart';
import 'package:nutrition_app/features/weight/weight_providers.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 25, 9);

/// A weight repository whose saves fail, to simulate a weigh-in DB error.
class _FailingWeightRepository extends WeightRepository {
  _FailingWeightRepository(AppDatabase db) : super(db, () => now);

  var calls = 0;

  @override
  Future<void> upsert(String dayKey, double weightKg) async {
    calls++;
    throw StateError('disk full');
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('a failed weigh-in is reported apart from the profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    addTearDown(db.close);
    final failing = _FailingWeightRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          weightRepositoryProvider.overrideWithValue(failing),
        ],
        child: const MaterialApp(home: SetupScreen()),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('birthDate')));
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
    await tester.enterText(find.byKey(const Key('heightCm')), '180');
    await tester.enterText(find.byKey(const Key('goalWeightKg')), '80');
    await tester.enterText(find.byKey(const Key('setupWeightKg')), '90');

    final save = find.byKey(const Key('saveProfile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    // The profile did save; only the weigh-in failed, and it says so.
    final profiles = await tester.runAsync(() => db.select(db.profiles).get());
    expect(profiles, hasLength(1));
    expect(failing.calls, 1);
    expect(
      find.text("Profile saved, but your weight couldn't be saved"),
      findsOneWidget,
    );
    expect(find.text("Couldn't save your profile"), findsNothing);
    expect(find.byType(SetupScreen), findsOneWidget); // stays open to retry

    // Try again retries the weigh-in.
    await tester.pump(const Duration(seconds: 1)); // snackbar slides in
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(failing.calls, 2);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('Health Connect is offered on Android but not on web', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);

    for (final isWeb in [false, true]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(isWeb),
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(() => now),
            isWebProvider.overrideWithValue(isWeb),
          ],
          child: const MaterialApp(home: SetupScreen()),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text("I'll do this later"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byType(HealthConnectSettingsTile),
        isWeb ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Steps and workouts (optional)'),
        isWeb ? findsNothing : findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
