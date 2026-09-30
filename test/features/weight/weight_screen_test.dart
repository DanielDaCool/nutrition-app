import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/weight/weight_providers.dart';
import 'package:nutrition_app/features/weight/weight_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> addWeighIn(String day, double kg) => db
      .into(db.weighIns)
      .insert(
        WeighInsCompanion.insert(
          dayKey: day,
          weightKg: kg,
          createdAt: DateTime(2026, 9, 25),
        ),
      );

  Future<Map<String, double>> stored() async => {
    for (final r in await db.select(db.weighIns).get()) r.dayKey: r.weightKg,
  };

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 8)),
          ...extra,
        ],
        child: const MaterialApp(home: WeightScreen()),
      ),
    );
    await settle(tester);
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
    expect(
      find.text('Your trend appears after a few weigh-ins'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Add weigh-in'), findsOneWidget);

    // Out of range is rejected and the dialog stays open.
    await tester.enterText(find.byKey(const Key('weighInKgField')), '12');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('between 30 and 300'), findsOneWidget);

    // A comma is turned into a dot while typing.
    await tester.enterText(find.byKey(const Key('weighInKgField')), '82,4');
    expect(find.text('82.4'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Saved 82.4 kg'), findsOneWidget);
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
    expect(await stored(), {'2026-09-25': 82.4});
    await unmount(tester);
  });

  testWidgets('add mode prefills the last weight and warns on a taken day', (
    tester,
  ) async {
    await addWeighIn('2026-09-23', 83.0);
    await addWeighIn('2026-09-24', 82.6);
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('weighInKgField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '82.6');
    expect(field.controller.selection.baseOffset, 0);
    expect(field.controller.selection.extentOffset, 4);
    // Today is free, so no warning.
    expect(find.byKey(const Key('weighInReplaceWarning')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Editing yesterday: no warning for its own day.
    await tester.tap(find.byKey(const ValueKey('weighIn-2026-09-24')));
    await tester.pumpAndSettle();
    expect(find.text('Edit weigh-in'), findsOneWidget);
    expect(find.byKey(const Key('weighInReplaceWarning')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets("FAB updates today's weigh-in, and Undo restores it", (
    tester,
  ) async {
    await addWeighIn('2026-09-24', 83.0);
    await addWeighIn('2026-09-25', 82.6);
    await pumpScreen(tester);
    expect(find.text('Update today'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text("Update today's weigh-in"), findsOneWidget);
    await tester.enterText(find.byKey(const Key('weighInKgField')), '82.1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(await stored(), {'2026-09-24': 83.0, '2026-09-25': 82.1});
    expect(find.text('Saved 82.1 kg'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await stored(), {'2026-09-24': 83.0, '2026-09-25': 82.6});
    await unmount(tester);
  });

  testWidgets('lists newest first with change, deletes with undo', (
    tester,
  ) async {
    for (final (day, kg) in [
      ('2026-09-20', 84.0),
      ('2026-09-24', 83.1),
      ('2026-09-22', 83.6),
    ]) {
      await addWeighIn(day, kg);
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weighIn-2026-09-24')),
        matching: find.text('−0.5 kg'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('weighIn-2026-09-22')),
        matching: find.byTooltip('Delete'),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('weighIn-2026-09-22')), findsNothing);
    expect((await stored()).length, 2);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await stored())['2026-09-22'], 83.6);
    await unmount(tester);
  });

  testWidgets('shows 14 weigh-ins, then all on request', (tester) async {
    for (var i = 0; i < 20; i++) {
      await addWeighIn(addDays('2026-09-25', -i), 80 + i * 0.1);
    }
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('weighIn-2026-09-25')), findsOneWidget);
    expect(find.text('Show all (6 more)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('showAllWeighIns')),
      300,
    );
    await tester.tap(find.byKey(const Key('showAllWeighIns')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('weighIn-2026-09-06')),
      300,
    );
    expect(find.byKey(const ValueKey('weighIn-2026-09-06')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('goal weight: distance in the summary and a chart label', (
    tester,
  ) async {
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            sex: 0,
            birthDate: DateTime(1990),
            heightCm: 180,
            activityLevel: 1,
            goalWeightKg: 78,
            weeklyRatePct: const Value(0.5),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await addWeighIn('2026-09-24', 81.1);
    await addWeighIn('2026-09-25', 81.1);
    await pumpScreen(tester);

    expect(find.text('3.1 kg to goal'), findsOneWidget);
    expect(find.textContaining('smooths out daily ups and downs'), findsOne);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'delete Undo shows a snackbar instead of throwing when the restore '
    'write fails',
    (tester) async {
      await addWeighIn('2026-09-22', 83.6);
      await pumpScreen(
        tester,
        extra: [
          weightRepositoryProvider.overrideWith(
            (ref) => _ThrowingUpsertRepo(db, () => DateTime(2026, 9, 25, 8)),
          ),
        ],
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('weighIn-2026-09-22')),
          matching: find.byTooltip('Delete'),
        ),
      );
      await settle(tester);
      expect((await stored()).length, 0); // delete itself still works

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(
        find.text("Couldn't undo that. Please try again."),
        findsOneWidget,
      );
      await unmount(tester);
    },
  );
}

/// A [WeightRepository] whose `upsert` always fails, for exercising the
/// delete Undo failure path.
class _ThrowingUpsertRepo extends WeightRepository {
  _ThrowingUpsertRepo(super.db, super.now);

  @override
  Future<void> upsert(String dayKey, double weightKg) =>
      Future<void>.error(StateError('upsert failed'));
}
