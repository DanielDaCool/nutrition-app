// PresetsScreen and PresetEditScreen: create with ordered exercises, edit
// order/contents, duplicate handling, delete.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/lifting/screens/presets_screen.dart';

import '../../helpers/test_db.dart';
import 'library_test_helpers.dart';

/// Adds exercise [id] to the preset being edited through the picker.
Future<void> pick(WidgetTester tester, int id) async {
  await tapAndSettle(tester, find.byKey(const Key('presetAddExercise')));
  await tapAndSettle(tester, find.byKey(Key('exercisePickerItem_$id')));
}

Future<List<String>> exerciseNames(WidgetTester tester, AppDatabase db) async =>
    [for (final e in (await presets(tester, db)).single.exercises) e.name];

void main() {
  testWidgets('creates a preset with several exercises in order', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final press = await addExercise(tester, db, 'Incline press');
    final deck = await addExercise(tester, db, 'Pec deck');
    final dips = await addExercise(tester, db, 'Dips', isBodyweight: true);
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);
    expect(find.byKey(const Key('presetsEmpty')), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('presetsAddFab')));
    expect(find.text('New preset'), findsWidgets);
    await tester.enterText(find.byKey(const Key('presetNameField')), 'Push day');
    // Picked out of alphabetical order on purpose.
    await pick(tester, press);
    await pick(tester, dips);
    await pick(tester, deck);
    await tapAndSettle(tester, find.byKey(const Key('presetSave')));

    final saved = (await presets(tester, db)).single;
    expect(saved.name, 'Push day');
    expect(await exerciseNames(tester, db), [
      'Incline press',
      'Dips',
      'Pec deck',
    ]);
    // Back on the list.
    expect(find.byKey(const Key('presetNameField')), findsNothing);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Incline press · Dips · Pec deck'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('name and at least one exercise are required', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const Key('presetsAddFab')));
    await tapAndSettle(tester, find.byKey(const Key('presetSave')));
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Add at least one exercise'), findsOneWidget);
    expect(await presets(tester, db), isEmpty);
    await unmount(tester);
  });

  testWidgets('the same exercise cannot be added twice', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final deck = await addExercise(tester, db, 'Pec deck');
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const Key('presetsAddFab')));
    await pick(tester, deck);
    await pick(tester, deck);
    expect(find.text('"Pec deck" is already in this preset'), findsOneWidget);
    expect(find.byKey(Key('presetItem_$deck')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a duplicate preset name shows the inline error', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final deck = await addExercise(tester, db, 'Pec deck');
    await real(tester, () => repoOf(db).createPreset('Push day', [deck]));
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const Key('presetsAddFab')));
    await tester.enterText(find.byKey(const Key('presetNameField')), 'push DAY');
    await pick(tester, deck);
    await tapAndSettle(tester, find.byKey(const Key('presetSave')));

    expect(
      find.text('You already have a preset with this name'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('presetNameField')), findsOneWidget);
    expect(await presets(tester, db), hasLength(1));
    await unmount(tester);
  });

  testWidgets('edits the name, order and contents of a preset', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final press = await addExercise(tester, db, 'Incline press');
    final deck = await addExercise(tester, db, 'Pec deck');
    final dips = await addExercise(tester, db, 'Dips');
    final shoulder = await addExercise(tester, db, 'Shoulder press');
    final id = await real(
      tester,
      () => repoOf(db).createPreset('Push day', [press, deck, dips]),
    );
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(Key('presetTile_$id')));
    expect(find.text('Edit preset'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('presetNameField')))
          .controller!
          .text,
      'Push day',
    );

    // press, deck, dips -> dips first, deck removed, shoulder appended.
    await tapAndSettle(tester, find.byKey(Key('presetItemUp_$dips')));
    await tapAndSettle(tester, find.byKey(Key('presetItemUp_$dips')));
    await tapAndSettle(tester, find.byKey(Key('presetItemRemove_$deck')));
    await pick(tester, shoulder);
    await tapAndSettle(tester, find.byKey(Key('presetItemDown_$press')));
    await tester.enterText(find.byKey(const Key('presetNameField')), 'Push A');
    await tapAndSettle(tester, find.byKey(const Key('presetSave')));

    final saved = (await presets(tester, db)).single;
    expect(saved.id, id);
    expect(saved.name, 'Push A');
    expect(await exerciseNames(tester, db), [
      'Dips',
      'Shoulder press',
      'Incline press',
    ]);
    expect(find.text('Dips · Shoulder press · Incline press'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deletes a preset after confirmation', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final deck = await addExercise(tester, db, 'Pec deck');
    final id = await real(
      tester,
      () => repoOf(db).createPreset('Push day', [deck]),
    );
    await tester.pumpWidget(host(db, const PresetsScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(Key('presetDelete_$id')));
    await tapAndSettle(tester, find.text('Cancel'));
    expect(await presets(tester, db), hasLength(1));

    await tapAndSettle(tester, find.byKey(Key('presetDelete_$id')));
    await tapAndSettle(tester, find.byKey(const Key('presetDeleteConfirm')));
    expect(await presets(tester, db), isEmpty);
    expect(find.text('Push day'), findsNothing);
    expect(find.byKey(const Key('presetsEmpty')), findsOneWidget);
    // The exercise itself is untouched.
    expect(await exerciseRows(tester, db), hasLength(1));
    await unmount(tester);
  });
}
