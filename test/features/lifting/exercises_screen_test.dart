// ExercisesScreen and the exercise dialog: create, duplicate-name error,
// edit, delete (unused and used on a day).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/screens/exercises_screen.dart';

import '../../helpers/test_db.dart';
import 'library_test_helpers.dart';

void main() {
  testWidgets('shows the empty state, then creates an exercise', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);
    expect(find.byKey(const Key('exercisesEmpty')), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('exercisesAddFab')));
    expect(find.text('Log only the extra weight you add'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exerciseNameField')), ' Dips ');
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseMuscleGroup_triceps')),
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseBodyweightSwitch')),
    );
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));

    final rows = await exerciseRows(tester, db);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Dips');
    expect(rows.single.muscleGroup, MuscleGroup.triceps.index);
    expect(rows.single.isBodyweight, isTrue);

    expect(find.byKey(const Key('exerciseDialogSave')), findsNothing);
    expect(find.text('Dips'), findsOneWidget);
    expect(find.text('Triceps · Bodyweight'), findsOneWidget);
    expect(find.byKey(const Key('exercisesEmpty')), findsNothing);
    await unmount(tester);
  });

  testWidgets('name and muscle group are required', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const Key('exercisesAddFab')));
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Pick a muscle group'), findsOneWidget);
    expect(await exerciseRows(tester, db), isEmpty);
    await unmount(tester);
  });

  testWidgets('a duplicate name shows the inline error', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await addExercise(tester, db, 'Pec deck');
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const Key('exercisesAddFab')));
    await tester.enterText(
      find.byKey(const Key('exerciseNameField')),
      'pec DECK',
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseMuscleGroup_chest')),
    );
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));

    expect(
      find.text('You already have an exercise with this name'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('exerciseDialogSave')), findsOneWidget);
    expect(await exerciseRows(tester, db), hasLength(1));
    await unmount(tester);
  });

  testWidgets('tapping an exercise edits it', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await addExercise(tester, db, 'Pull up');
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);
    expect(find.text('Chest'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(Key('exerciseTile_$id')));
    expect(find.text('Edit exercise'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('exerciseNameField')),
      'Pull-ups',
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseMuscleGroup_back')),
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('exerciseBodyweightSwitch')),
    );
    await tapAndSettle(tester, find.byKey(const Key('exerciseDialogSave')));

    final row = (await exerciseRows(tester, db)).single;
    expect(row.id, id);
    expect(row.name, 'Pull-ups');
    expect(row.muscleGroup, MuscleGroup.back.index);
    expect(row.isBodyweight, isTrue);
    expect(find.text('Pull-ups'), findsOneWidget);
    expect(find.text('Back · Bodyweight'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting an unused exercise removes it', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await addExercise(tester, db, 'Pec deck');
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);

    await tapAndSettle(tester, find.byKey(Key('exerciseDelete_$id')));
    expect(find.textContaining('keep their history'), findsOneWidget);
    await tapAndSettle(tester, find.text('Cancel'));
    expect(await exerciseRows(tester, db), hasLength(1));

    await tapAndSettle(tester, find.byKey(Key('exerciseDelete_$id')));
    await tapAndSettle(tester, find.byKey(const Key('exerciseDeleteConfirm')));
    expect(await exerciseRows(tester, db), isEmpty);
    expect(find.text('Pec deck'), findsNothing);
    expect(find.byKey(const Key('exercisesEmpty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting an exercise used on a day hides it, keeping history', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await addExercise(tester, db, 'Shoulder press');
    await real(tester, () => repoOf(db).addEntry(today, id));
    await tester.pumpWidget(host(db, const ExercisesScreen()));
    await settle(tester);
    expect(find.text('Shoulder press'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(Key('exerciseDelete_$id')));
    await tapAndSettle(tester, find.byKey(const Key('exerciseDeleteConfirm')));

    expect(find.text('Shoulder press'), findsNothing);
    final row = (await exerciseRows(tester, db)).single;
    expect(row.isArchived, isTrue);
    final day = await real(tester, () => repoOf(db).watchDay(today).first);
    expect(day.single.exercise.name, 'Shoulder press');
    await unmount(tester);
  });
}
