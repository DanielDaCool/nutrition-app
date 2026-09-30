// Tests for the shared weigh-in flows in weigh_in_actions.dart: the dialog
// waits for a real snapshot before opening (W4), and the various Undo /
// Try again buttons handle failures instead of throwing (W5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/weight/weigh_in_actions.dart';
import 'package:nutrition_app/features/weight/weight_providers.dart';

import '../../helpers/test_db.dart';

/// A bare screen with a button that opens the weigh-in dialog for
/// [dayKey], for testing [openWeighInDialog] outside any real screen's own
/// loading gate. It does watch [weighInsProvider] once, like every real
/// screen that offers this button does (WeightScreen, TodayScreen,
/// DashboardScreen all watch it in their own build) — this test is only
/// about the DB read *within that watch* still being in flight, not about
/// nobody watching the provider at all.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(weighInsProvider);
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => openWeighInDialog(context, ref),
        child: const Text('open'),
      ),
    );
  }
}

/// Pumps a bounded number of frames instead of `pumpAndSettle`, which never
/// returns while something (a stream, an animation) keeps scheduling work.
/// `runAsync` lets real async work (drift's native DB IO) actually run
/// between pumps, same as calorie_card_test.dart's `settle`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

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

  testWidgets(
    'openWeighInDialog waits for the real snapshot instead of opening '
    'against an empty one while the initial read is still in flight',
    (tester) async {
      await addWeighIn('2026-09-25', 82.6); // already has a weigh-in today
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 8)),
          ],
          child: const MaterialApp(home: _Harness()),
        ),
      );
      // Tap on the very first frame, before weighInsProvider's own DB read
      // has resolved — the exact race this fix closes.
      await tester.tap(find.text('open'));
      await _settle(tester);

      // Opens as an edit of the real existing value, with the field
      // prefilled — not a blank "add" that would silently overwrite it.
      expect(find.text("Update today's weigh-in"), findsOneWidget);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('weighInKgField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '82.6');
    },
  );

  testWidgets(
    'saveWeighInWithUndo Undo shows a snackbar instead of throwing when '
    'the restore write fails',
    (tester) async {
      final repo = _ThrowingRestoreRepo(db, () => DateTime(2026, 9, 25, 8));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await saveWeighInWithUndo(
                    messenger: messenger,
                    repo: repo,
                    before: const {},
                    dayKey: '2026-09-25',
                    weightKg: 82.0,
                  );
                },
                child: const Text('save'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await _settle(tester);
      expect(find.text('Saved 82.0 kg'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await _settle(tester);

      // The failed restore is caught and surfaced, not left unhandled.
      expect(tester.takeException(), isNull);
      expect(
        find.text("Couldn't undo that. Please try again."),
        findsOneWidget,
      );
    },
  );
}

/// A [WeightRepository] whose `restore` always fails, for exercising
/// Undo's failure path.
class _ThrowingRestoreRepo extends WeightRepository {
  _ThrowingRestoreRepo(super.db, super.now);

  @override
  Future<void> restore({
    required String dayKey,
    required double? weightKg,
    String? oldDayKey,
    double? oldWeightKg,
  }) => Future<void>.error(StateError('restore failed'));
}
