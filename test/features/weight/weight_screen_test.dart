import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/weight/weight_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 8)),
        ],
        child: const MaterialApp(home: WeightScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('empty state, then add a weigh-in via the dialog', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('No weigh-ins yet'), findsOneWidget);
    expect(find.text('No weigh-ins in this range yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add weigh-in'), findsOneWidget);

    // Out of range is rejected and the dialog stays open.
    await tester.enterText(find.byKey(const Key('weighInKgField')), '12');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('between 30 and 300'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('weighInKgField')), '82,4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add weigh-in'), findsNothing);
    final tile = find.byKey(const ValueKey('weighIn-2026-09-25'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('82.4 kg')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Today')),
      findsOneWidget,
    );
    expect(find.text('No weigh-ins yet'), findsNothing);

    final rows = await db.select(db.weighIns).get();
    expect(rows.single.dayKey, '2026-09-25');
    expect(rows.single.weightKg, 82.4);
    await unmount(tester);
  });

  testWidgets('lists newest first and deletes', (tester) async {
    for (final (day, kg) in [
      ('2026-09-20', 84.0),
      ('2026-09-24', 83.1),
      ('2026-09-22', 83.6),
    ]) {
      await db
          .into(db.weighIns)
          .insert(
            WeighInsCompanion.insert(
              dayKey: day,
              weightKg: kg,
              createdAt: DateTime(2026, 9, 25),
            ),
          );
    }
    await pumpScreen(tester);

    final tiles = find.byWidgetPredicate(
      (w) => w is ListTile && w.key is ValueKey<String>,
    );
    final keys = tester
        .widgetList<ListTile>(tiles)
        .map((t) => (t.key! as ValueKey<String>).value)
        .toList();
    expect(keys, [
      'weighIn-2026-09-24',
      'weighIn-2026-09-22',
      'weighIn-2026-09-20',
    ]);
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('weighIn-2026-09-22')),
        matching: find.byTooltip('Delete'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('weighIn-2026-09-22')), findsNothing);
    expect((await db.select(db.weighIns).get()).length, 2);
    await unmount(tester);
  });
}
