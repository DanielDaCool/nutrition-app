// showPresetPicker: returns the tapped preset, shows the empty state with
// a way to create one, null when dismissed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/screens/presets_screen.dart';
import 'package:nutrition_app/features/lifting/widgets/preset_picker.dart';

import '../../helpers/test_db.dart';
import 'library_test_helpers.dart';

void main() {
  late List<LiftPreset?> results;

  Widget picker(AppDatabase db) => host(
    db,
    Opener<LiftPreset>(open: showPresetPicker, onResult: results.add),
  );

  setUp(() => results = []);

  testWidgets('returns the tapped preset with its exercises in order', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final press = await addExercise(tester, db, 'Incline press');
    final deck = await addExercise(tester, db, 'Pec deck');
    final dips = await addExercise(tester, db, 'Dips');
    final squat = await addExercise(tester, db, 'Squat');
    await real(tester, () => repoOf(db).createPreset('Leg day', [squat]));
    final push = await real(
      tester,
      () => repoOf(db).createPreset('Push day', [press, deck, dips]),
    );
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    expect(find.text('Leg day'), findsOneWidget);
    expect(find.text('Incline press · Pec deck · Dips'), findsOneWidget);
    expect(find.byKey(const Key('presetPickerEmpty')), findsNothing);

    await tapAndSettle(tester, find.byKey(Key('presetPickerItem_$push')));
    final picked = results.single!;
    expect(picked.id, push);
    expect(picked.name, 'Push day');
    expect([for (final e in picked.exercises) e.id], [press, deck, dips]);
    expect(find.text('Leg day'), findsNothing);
    await unmount(tester);
  });

  testWidgets('empty state explains presets and opens the presets screen', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    expect(find.byKey(const Key('presetPickerEmpty')), findsOneWidget);
    expect(find.textContaining('named list of exercises'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('presetPickerCreate')));
    expect(find.byType(PresetsScreen), findsOneWidget);
    expect(results, isEmpty);
    await unmount(tester);
  });

  testWidgets('returns null when dismissed', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    expect(find.byKey(const Key('presetPickerEmpty')), findsNothing);
    expect(results, [null]);
    await unmount(tester);
  });
}
