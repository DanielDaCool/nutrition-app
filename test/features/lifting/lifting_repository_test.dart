import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late LiftingRepository repo;
  final now = DateTime(2026, 10, 4, 9);

  setUp(() {
    db = openTestDatabase();
    repo = LiftingRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<int> exercise(
    String name, {
    MuscleGroup group = MuscleGroup.chest,
    bool bodyweight = false,
  }) => repo.addExercise(name: name, muscleGroup: group, isBodyweight: bodyweight);

  List<String> names(Iterable<LiftExercise> xs) => [for (final x in xs) x.name];

  group('exercises', () {
    test('are listed by name with their labels', () async {
      await exercise('pec deck');
      await exercise('Dips', group: MuscleGroup.triceps, bodyweight: true);
      await exercise('  Incline barbell press ');

      final all = await repo.watchExercises().first;
      expect(names(all), ['Dips', 'Incline barbell press', 'pec deck']);
      expect(all.first.muscleGroup, MuscleGroup.triceps);
      expect(all.first.isBodyweight, isTrue);
      expect(all.last.isBodyweight, isFalse);
    });

    test('a name can only be used once, whatever the case', () async {
      await exercise('Dips');
      expect(
        () => exercise(' dips '),
        throwsA(isA<LiftNameTakenException>()),
      );
      final other = await exercise('Pec deck');
      expect(
        () => repo.updateExercise(
          other,
          name: 'DIPS',
          muscleGroup: MuscleGroup.chest,
          isBodyweight: false,
        ),
        throwsA(isA<LiftNameTakenException>()),
      );
    });

    test('can be renamed and relabelled, keeping its own name', () async {
      final id = await exercise('Dips');
      await repo.updateExercise(
        id,
        name: 'dips',
        muscleGroup: MuscleGroup.triceps,
        isBodyweight: true,
      );
      final x = (await repo.watchExercises().first).single;
      expect(x.name, 'dips');
      expect(x.muscleGroup, MuscleGroup.triceps);
      expect(x.isBodyweight, isTrue);
    });

    test('deleting an unused exercise removes it, also from presets', () async {
      final dips = await exercise('Dips');
      final deck = await exercise('Pec deck');
      await repo.createPreset('Push day', [dips, deck]);

      await repo.deleteExercise(dips);
      expect(names(await repo.watchExercises(includeArchived: true).first), [
        'Pec deck',
      ]);
      final preset = (await repo.watchPresets().first).single;
      expect(names(preset.exercises), ['Pec deck']);
    });

    test('deleting a used exercise archives it and keeps its days', () async {
      final dips = await exercise('Dips');
      final entry = await repo.addEntry('2026-10-01', dips);
      await repo.addSet(entry, reps: 8, weightKg: 0);

      await repo.deleteExercise(dips);
      expect(await repo.watchExercises().first, isEmpty);
      final day = await repo.watchDay('2026-10-01').first;
      expect(day.single.exercise.name, 'Dips');
      expect(day.single.exercise.isArchived, isTrue);
      expect(day.single.sets.single.reps, 8);

      // Creating it again brings the old one back, history included.
      final again = await exercise('dips', group: MuscleGroup.triceps);
      expect(again, dips);
      final x = (await repo.watchExercises().first).single;
      expect(x.isArchived, isFalse);
      expect(x.muscleGroup, MuscleGroup.triceps);
    });
  });

  group('days', () {
    test('a planned day lists its exercises in order, without sets', () async {
      final a = await exercise('Incline barbell press');
      final b = await exercise('Pec deck');
      await repo.addEntry('2026-10-10', b);
      await repo.addEntry('2026-10-10', a);
      await repo.addEntry('2026-10-11', a);

      final day = await repo.watchDay('2026-10-10').first;
      expect([for (final e in day) e.exercise.name], [
        'Pec deck',
        'Incline barbell press',
      ]);
      expect(day.every((e) => e.sets.isEmpty), isTrue);
      expect(day.every((e) => e.dayKey == '2026-10-10'), isTrue);
      expect(await repo.watchDay('2026-10-12').first, isEmpty);
    });

    test('sets keep their order and can be edited and removed', () async {
      final a = await exercise('Incline barbell press');
      final entry = await repo.addEntry('2026-10-04', a);
      final s1 = await repo.addSet(entry, reps: 7, weightKg: 60);
      final s2 = await repo.addSet(entry, reps: 4, weightKg: 60);
      await repo.addSet(entry, reps: 6, weightKg: 55);

      await repo.updateSet(s2, reps: 5, weightKg: 62.5);
      await repo.deleteSet(s1);
      final sets = (await repo.watchDay('2026-10-04').first).single.sets;
      expect([for (final s in sets) (s.reps, s.weightKg)], [(5, 62.5), (6, 55)]);

      // A new set still goes last.
      await repo.addSet(entry, reps: 3, weightKg: 50);
      final after = (await repo.watchDay('2026-10-04').first).single.sets;
      expect(after.last.reps, 3);
    });

    test('entries can be reordered, swapped and removed', () async {
      final a = await exercise('A');
      final b = await exercise('B');
      final c = await exercise('C');
      final ea = await repo.addEntry('2026-10-04', a);
      final eb = await repo.addEntry('2026-10-04', b);
      await repo.addSet(eb, reps: 8, weightKg: 40);

      await repo.reorderEntries([eb, ea]);
      await repo.changeEntryExercise(eb, c);
      var day = await repo.watchDay('2026-10-04').first;
      expect([for (final e in day) e.exercise.name], ['C', 'A']);
      // The swapped entry keeps the sets already tracked.
      expect(day.first.sets.single.weightKg, 40);

      await repo.removeEntry(eb);
      day = await repo.watchDay('2026-10-04').first;
      expect([for (final e in day) e.exercise.name], ['A']);
      expect(await db.select(db.liftSets).get(), isEmpty);
    });

    test('a day update reaches the watcher', () async {
      final a = await exercise('A');
      final seen = <int>[];
      final sub = repo.watchDay('2026-10-04').listen((d) => seen.add(d.length));
      await pumpEventQueue();
      await repo.addEntry('2026-10-04', a);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [0, 1]);
    });
  });

  group('history', () {
    late int press;

    setUp(() async {
      press = await exercise('Incline barbell press');
      final other = await exercise('Pec deck');
      Future<void> day(String dayKey, List<(int, double)> sets) async {
        final entry = await repo.addEntry(dayKey, press);
        for (final (reps, kg) in sets) {
          await repo.addSet(entry, reps: reps, weightKg: kg);
        }
      }

      await day('2026-09-21', [(8, 55)]);
      await day('2026-09-28', [(7, 60), (4, 60), (6, 55)]);
      await day('2026-10-04', [(8, 60)]);
      // Planned only: not part of the history.
      await repo.addEntry('2026-10-02', press);
      final e = await repo.addEntry('2026-09-30', other);
      await repo.addSet(e, reps: 12, weightKg: 30);
    });

    test('lists the tracked days in a range with all their sets', () async {
      final sessions = await repo
          .watchHistory(press, '2026-09-22', '2026-10-04')
          .first;
      expect([for (final s in sessions) s.dayKey], ['2026-09-28', '2026-10-04']);
      expect(
        [for (final s in sessions.first.sets) (s.reps, s.weightKg)],
        [(7, 60), (4, 60), (6, 55)],
      );
    });

    test('last session is the latest tracked day before the given one', () async {
      final last = await repo.watchLastSession(press, '2026-10-04').first;
      expect(last!.dayKey, '2026-09-28');
      expect([for (final s in last.sets) s.reps], [7, 4, 6]);

      // Planning ahead: the day itself doesn't count, earlier ones do.
      final ahead = await repo.watchLastSession(press, '2026-10-10').first;
      expect(ahead!.dayKey, '2026-10-04');
      expect(await repo.watchLastSession(press, '2026-09-21').first, isNull);
    });

    test('logged exercises are the ones with at least one set', () async {
      await exercise('Never done');
      expect(names(await repo.watchLoggedExercises().first), [
        'Incline barbell press',
        'Pec deck',
      ]);
    });
  });

  group('presets', () {
    late List<int> push;

    setUp(() async {
      push = [
        await exercise('Incline barbell press'),
        await exercise('Pec deck'),
        await exercise('Dips', bodyweight: true),
      ];
    });

    test('keep their exercises in order', () async {
      await repo.createPreset(' Push day ', [push[2], push[0], push[1]]);
      final preset = (await repo.watchPresets().first).single;
      expect(preset.name, 'Push day');
      expect(names(preset.exercises), [
        'Dips',
        'Incline barbell press',
        'Pec deck',
      ]);
    });

    test('names are unique; a preset may keep its own name', () async {
      final id = await repo.createPreset('Push day', push);
      expect(
        () => repo.createPreset('push day', const []),
        throwsA(isA<LiftNameTakenException>()),
      );
      await repo.updatePreset(id, 'Push day', [push[1]]);
      final preset = (await repo.watchPresets().first).single;
      expect(names(preset.exercises), ['Pec deck']);
    });

    test('loading copies the exercises onto the day', () async {
      final id = await repo.createPreset('Push day', push);
      expect(await repo.loadPreset(id, '2026-10-10'), 3);

      // Changing the day afterwards leaves the preset alone.
      final day = await repo.watchDay('2026-10-10').first;
      await repo.removeEntry(day.first.id);
      await repo.changeEntryExercise(
        day[1].id,
        await exercise('Shoulder press', group: MuscleGroup.shoulders),
      );
      final after = await repo.watchDay('2026-10-10').first;
      expect([for (final e in after) e.exercise.name], [
        'Shoulder press',
        'Dips',
      ]);
      final preset = (await repo.watchPresets().first).single;
      expect(names(preset.exercises), [
        'Incline barbell press',
        'Pec deck',
        'Dips',
      ]);
    });

    test('loading goes after what is planned and skips duplicates', () async {
      final id = await repo.createPreset('Push day', push);
      await repo.addEntry('2026-10-10', push[1]);
      expect(await repo.loadPreset(id, '2026-10-10'), 2);
      final day = await repo.watchDay('2026-10-10').first;
      expect([for (final e in day) e.exercise.name], [
        'Pec deck',
        'Incline barbell press',
        'Dips',
      ]);
      expect(await repo.loadPreset(id, '2026-10-10'), 0);
    });

    test('a day can be saved as a preset', () async {
      await repo.addEntry('2026-10-04', push[1]);
      await repo.addEntry('2026-10-04', push[0]);
      await repo.savePresetFromDay('2026-10-04', 'Chest');
      final preset = (await repo.watchPresets().first).single;
      expect(preset.name, 'Chest');
      expect(names(preset.exercises), ['Pec deck', 'Incline barbell press']);
    });

    test('deleting a preset keeps the days it was loaded onto', () async {
      final id = await repo.createPreset('Push day', push);
      await repo.loadPreset(id, '2026-10-10');
      await repo.deletePreset(id);
      expect(await repo.watchPresets().first, isEmpty);
      expect(await db.select(db.liftPresetItems).get(), isEmpty);
      expect(await repo.watchDay('2026-10-10').first, hasLength(3));
    });
  });
}
