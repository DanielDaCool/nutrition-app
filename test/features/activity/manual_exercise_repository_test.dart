import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/activity_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 25, 10, 30);

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('a manual exercise shows up in loadActivityRange as a workout', () async {
    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Cycling, moderate',
      durationMin: 30,
      kcal: 320,
      metValue: 8.0,
      now: now,
    );

    final days = await loadActivityRange(db, '2026-09-25', '2026-09-25');
    expect(days, hasLength(1));
    expect(days.single.workouts, hasLength(1));
    final w = days.single.workouts.single;
    expect(w.title, 'Cycling, moderate');
    expect(w.isManual, isTrue);
    expect(w.kcal, 320);
    expect(w.duration, const Duration(minutes: 30));
    expect(w.id, startsWith('manual-'));
  });

  test('merges with Health Connect workouts on the same day, sorted by time', () async {
    await db
        .into(db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: 'hc1',
            dayKey: '2026-09-25',
            title: 'Strength training',
            startTime: DateTime(2026, 9, 25, 18),
            endTime: DateTime(2026, 9, 25, 18, 45),
            syncedAt: now,
          ),
        );
    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Treadmill walk',
      durationMin: 20,
      kcal: 100,
      metValue: 3.5,
      now: DateTime(2026, 9, 25, 7),
    );

    final days = await loadActivityRange(db, '2026-09-25', '2026-09-25');
    final titles = days.single.workouts.map((w) => w.title).toList();
    expect(titles, ['Treadmill walk', 'Strength training']);
  });

  test('deleteManualExercise removes only that entry', () async {
    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Rowing machine',
      durationMin: 20,
      kcal: 150,
      metValue: 7.0,
      now: now,
    );
    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Swimming',
      durationMin: 20,
      kcal: 120,
      metValue: 6.0,
      now: now,
    );

    var days = await loadActivityRange(db, '2026-09-25', '2026-09-25');
    expect(days.single.workouts, hasLength(2));

    final toDelete = days.single.workouts.firstWhere(
      (w) => w.title == 'Rowing machine',
    );
    final id = int.parse(toDelete.id.substring('manual-'.length));
    await deleteManualExercise(db, id);

    days = await loadActivityRange(db, '2026-09-25', '2026-09-25');
    expect(days.single.workouts, hasLength(1));
    expect(days.single.workouts.single.title, 'Swimming');
  });

  test('an overridden estimate is stored with a null metValue', () async {
    await addManualExercise(
      db,
      dayKey: '2026-09-25',
      activityName: 'Other',
      durationMin: 45,
      kcal: 500,
      metValue: null,
      now: now,
    );
    final row = await db.select(db.manualExercises).getSingle();
    expect(row.metValue, isNull);
    expect(row.kcal, 500);
  });
}
