// showExercisePicker: returns the tapped exercise, filters by search text,
// creates a new exercise and returns it, null when dismissed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/widgets/exercise_picker.dart';

import '../../helpers/test_db.dart';
import 'library_test_helpers.dart';

void main() {
  late List<LiftExercise?> results;

  Widget picker(AppDatabase db) => host(
    db,
    Opener<LiftExercise>(
      open: (context) => showExercisePicker(context, title: 'Pick one'),
      onResult: results.add,
    ),
  );

  setUp(() => results = []);

  testWidgets('returns the tapped exercise', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await addExercise(tester, db, 'Pec deck');
    final dips = await addExercise(
      tester,
      db,
      'Dips',
      muscleGroup: MuscleGroup.triceps,
      isBodyweight: true,
    );
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    expect(find.text('Pick one'), findsOneWidget);
    expect(find.text('Pec deck'), findsOneWidget);
    expect(find.text('Triceps · Bodyweight'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(Key('exercisePickerItem_$dips')));
    expect(results, hasLength(1));
    final picked = results.single!;
    expect(picked.id, dips);
    expect(picked.name, 'Dips');
    expect(picked.muscleGroup, MuscleGroup.triceps);
    expect(picked.isBodyweight, isTrue);
    expect(find.byKey(const Key('exercisePickerSearch')), findsNothing);
    await unmount(tester);
  });

  testWidgets('filters by search text (name or muscle group)', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await addExercise(tester, db, 'Pec deck');
    await addExercise(tester, db, 'Incline barbell press');
    await addExercise(tester, db, 'Squat', muscleGroup: MuscleGroup.quads);
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    final search = find.byKey(const Key('exercisePickerSearch'));
    await tester.enterText(search, 'PRESS');
    await settle(tester);
    expect(find.text('Incline barbell press'), findsOneWidget);
    expect(find.text('Pec deck'), findsNothing);
    expect(find.text('Squat'), findsNothing);

    await tester.enterText(search, 'quad');
    await settle(tester);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Incline barbell press'), findsNothing);

    await tester.enterText(search, '');
    await settle(tester);
    expect(find.text('Pec deck'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(results, isEmpty);
    await unmount(tester);
  });

  testWidgets('offers to create the search text and returns the new exercise', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await addExercise(tester, db, 'Pec deck');
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    await tester.enterText(
      find.byKey(const Key('exercisePickerSearch')),
      'Tricep extension',
    );
    await settle(tester);
    expect(find.text('Create "Tricep extension"'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('exercisePickerCreate')));
    // The dialog opens prefilled with the search text.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exerciseNameField')))
          .controller!
          .text,
      'Tricep extension',
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseMuscleGroup_triceps')),
    );
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));

    final rows = await exerciseRows(tester, db);
    final row = rows.singleWhere((r) => r.name == 'Tricep extension');
    expect(results, hasLength(1));
    expect(results.single!.id, row.id);
    expect(results.single!.name, 'Tricep extension');
    expect(results.single!.muscleGroup, MuscleGroup.triceps);
    expect(results.single!.isBodyweight, isFalse);
    // Both the dialog and the sheet are closed.
    expect(find.byKey(const Key('exerciseDialogSave')), findsNothing);
    expect(find.byKey(const Key('exercisePickerSearch')), findsNothing);
    await unmount(tester);
  });

  testWidgets('"New exercise" works with no exercises yet', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));
    expect(find.textContaining('You have no exercises yet'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('exercisePickerNew')));
    await tester.enterText(find.byKey(const Key('exerciseNameField')), 'Squat');
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseMuscleGroup_quads')),
    );
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));

    expect(results.single!.name, 'Squat');
    expect(results.single!.id, (await exerciseRows(tester, db)).single.id);
    await unmount(tester);
  });

  testWidgets('cancelling the dialog keeps the picker open; dismissing '
      'returns null', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await addExercise(tester, db, 'Pec deck');
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));

    await tapAndSettle(tester, find.byKey(const Key('exercisePickerNew')));
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogCancel')));
    expect(find.byKey(const Key('exercisePickerSearch')), findsOneWidget);
    expect(results, isEmpty);

    // Tap the scrim above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    expect(find.byKey(const Key('exercisePickerSearch')), findsNothing);
    expect(results, [null]);
    await unmount(tester);
  });

  testWidgets('scrolls with many exercises', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    for (var i = 10; i < 50; i++) {
      await addExercise(tester, db, 'Exercise $i');
    }
    await tester.pumpWidget(picker(db));
    await tapAndSettle(tester, find.text('open'));
    expect(tester.takeException(), isNull);
    expect(find.text('Exercise 10'), findsOneWidget);
    expect(find.text('Exercise 49'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Exercise 49'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(); // lay out the final scroll offset
    await tapAndSettle(tester, find.text('Exercise 49'));
    expect(results.single!.name, 'Exercise 49');
    await unmount(tester);
  });
}
