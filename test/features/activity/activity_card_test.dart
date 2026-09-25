import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/activity_providers.dart';
import 'package:nutrition_app/features/activity/health_source.dart';
import 'package:nutrition_app/features/activity/widgets/activity_card.dart';

import '../../helpers/test_db.dart';
import 'fake_health_source.dart';

void main() {
  late AppDatabase db;
  late FakeHealthSource source;
  final now = DateTime(2026, 9, 25, 10, 30);

  setUp(() {
    db = openTestDatabase();
    source = FakeHealthSource();
  });
  tearDown(() => db.close());

  /// Pumps the card and runs one sync so the Health Connect status is known.
  Future<void> pumpSynced(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          healthSourceProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ActivityCard(dayKey: '2026-09-25')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ActivityCard)),
      );
      await container.read(healthSyncProvider.notifier).syncNow();
    });
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('not connected: Connect right on the card', (tester) async {
    source.permissionsGranted = false;
    source.grantOnRequest = false;
    await pumpSynced(tester);
    expect(
      find.text('Connect Health Connect to see steps and workouts'),
      findsOneWidget,
    );
    expect(find.text('No activity yet'), findsNothing);
    await tester.tap(find.text('Connect'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(source.requestPermissionCalls, 1);
    await unmount(tester);
  });

  testWidgets('not installed: Install right on the card', (tester) async {
    source.availabilityValue = HcAvailability.notInstalled;
    await pumpSynced(tester);
    expect(
      find.text('Install Health Connect to see steps and workouts'),
      findsOneWidget,
    );
    await tester.tap(find.text('Install'));
    await tester.pump();
    expect(source.installCalls, 1);
    await unmount(tester);
  });

  testWidgets('connected but empty: No activity yet, no buttons', (
    tester,
  ) async {
    await pumpSynced(tester);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await unmount(tester);
  });
}
