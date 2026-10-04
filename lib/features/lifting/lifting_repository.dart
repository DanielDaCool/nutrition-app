// Weight-lifting storage: the user's exercises, the exercises planned on a
// day with their tracked sets, and presets. Only writer of the Lift* tables.
import 'package:drift/drift.dart';

import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../weight/table_watch.dart';

/// Thrown when an exercise or preset name is already used by another one
/// (names are compared without case or surrounding spaces).
class LiftNameTakenException implements Exception {
  const LiftNameTakenException(this.name);
  final String name;

  @override
  String toString() => 'LiftNameTakenException: "$name" is already used';
}

/// Reads and writes the lifting tables.
class LiftingRepository {
  LiftingRepository(this._db, this._now);

  final AppDatabase _db;
  final DateTime Function() _now;

  LiftExercise _exercise(LiftExerciseRow r) => LiftExercise(
    id: r.id,
    name: r.name,
    muscleGroup: MuscleGroup.values[r.muscleGroup],
    isBodyweight: r.isBodyweight,
    isArchived: r.isArchived,
  );

  // ---- Exercises ----

  /// The user's exercises by name; archived ones only with [includeArchived].
  Stream<List<LiftExercise>> watchExercises({bool includeArchived = false}) {
    return watchTables(_db, [_db.liftExercises], () async {
      final query = _db.select(_db.liftExercises)
        ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]);
      if (!includeArchived) query.where((t) => t.isArchived.equals(false));
      return [for (final r in await query.get()) _exercise(r)];
    });
  }

  Future<LiftExerciseRow?> _exerciseNamed(String name) {
    return (_db.select(_db.liftExercises)
          ..where((t) => t.name.lower().equals(name.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Creates an exercise and returns its id. A deleted (archived) exercise
  /// with the same name is brought back instead, keeping its history.
  ///
  /// Throws [LiftNameTakenException] when the name is in use.
  Future<int> addExercise({
    required String name,
    required MuscleGroup muscleGroup,
    required bool isBodyweight,
  }) {
    final trimmed = name.trim();
    return _db.transaction(() async {
      final existing = await _exerciseNamed(trimmed);
      if (existing != null) {
        if (!existing.isArchived) throw LiftNameTakenException(trimmed);
        await (_db.update(
          _db.liftExercises,
        )..where((t) => t.id.equals(existing.id))).write(
          LiftExercisesCompanion(
            name: Value(trimmed),
            muscleGroup: Value(muscleGroup.index),
            isBodyweight: Value(isBodyweight),
            isArchived: const Value(false),
          ),
        );
        return existing.id;
      }
      return _db
          .into(_db.liftExercises)
          .insert(
            LiftExercisesCompanion.insert(
              name: trimmed,
              muscleGroup: muscleGroup.index,
              isBodyweight: Value(isBodyweight),
              createdAt: _now(),
            ),
          );
    });
  }

  /// Renames or relabels exercise [id]; its past days follow.
  ///
  /// Throws [LiftNameTakenException] when another exercise has the name.
  Future<void> updateExercise(
    int id, {
    required String name,
    required MuscleGroup muscleGroup,
    required bool isBodyweight,
  }) {
    final trimmed = name.trim();
    return _db.transaction(() async {
      final existing = await _exerciseNamed(trimmed);
      if (existing != null && existing.id != id) {
        throw LiftNameTakenException(trimmed);
      }
      await (_db.update(
        _db.liftExercises,
      )..where((t) => t.id.equals(id))).write(
        LiftExercisesCompanion(
          name: Value(trimmed),
          muscleGroup: Value(muscleGroup.index),
          isBodyweight: Value(isBodyweight),
        ),
      );
    });
  }

  /// Deletes exercise [id] and takes it out of every preset. If any day
  /// still has it (planned or tracked) it is archived instead, so those
  /// days keep their history.
  Future<void> deleteExercise(int id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.liftPresetItems,
      )..where((t) => t.exerciseId.equals(id))).go();
      final used =
          await (_db.select(_db.liftEntries)
                ..where((t) => t.exerciseId.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (used == null) {
        await (_db.delete(
          _db.liftExercises,
        )..where((t) => t.id.equals(id))).go();
      } else {
        await (_db.update(_db.liftExercises)..where((t) => t.id.equals(id)))
            .write(const LiftExercisesCompanion(isArchived: Value(true)));
      }
    });
  }

  /// Exercises with at least one tracked set (archived ones included), by
  /// name. These are the ones a progress chart can show.
  Stream<List<LiftExercise>> watchLoggedExercises() {
    final tables = <TableInfo>[_db.liftExercises, _db.liftEntries, _db.liftSets];
    return watchTables(_db, tables, () async {
      final rows = await _db
          .customSelect(
            'SELECT x.* FROM lift_exercises x WHERE EXISTS ('
            'SELECT 1 FROM lift_entries e JOIN lift_sets s ON s.entry_id = e.id '
            'WHERE e.exercise_id = x.id) ORDER BY LOWER(x.name)',
          )
          .asyncMap(_db.liftExercises.mapFromRow)
          .get();
      return [for (final r in rows) _exercise(r)];
    });
  }

  // ---- Days ----

  /// The exercises on [dayKey] in order, each with its sets.
  Stream<List<LiftEntry>> watchDay(String dayKey) {
    final tables = <TableInfo>[_db.liftEntries, _db.liftSets, _db.liftExercises];
    return watchTables(_db, tables, () => _loadDay(dayKey));
  }

  Future<List<LiftEntry>> _loadDay(String dayKey) async {
    final query =
        _db.select(_db.liftEntries).join([
            innerJoin(
              _db.liftExercises,
              _db.liftExercises.id.equalsExp(_db.liftEntries.exerciseId),
            ),
          ])
          ..where(_db.liftEntries.dayKey.equals(dayKey))
          ..orderBy([
            OrderingTerm.asc(_db.liftEntries.position),
            OrderingTerm.asc(_db.liftEntries.id),
          ]);
    final rows = await query.get();
    final entryIds = [for (final r in rows) r.readTable(_db.liftEntries).id];
    final setRows =
        await (_db.select(_db.liftSets)
              ..where((t) => t.entryId.isIn(entryIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final setsByEntry = <int, List<LiftSet>>{};
    for (final s in setRows) {
      (setsByEntry[s.entryId] ??= []).add(
        LiftSet(id: s.id, reps: s.reps, weightKg: s.weightKg),
      );
    }
    return [
      for (final r in rows)
        LiftEntry(
          id: r.readTable(_db.liftEntries).id,
          dayKey: dayKey,
          exercise: _exercise(r.readTable(_db.liftExercises)),
          sets: setsByEntry[r.readTable(_db.liftEntries).id] ?? const [],
        ),
    ];
  }

  Future<int> _nextEntryPosition(String dayKey) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM lift_entries '
          'WHERE day_key = ?',
          variables: [Variable.withString(dayKey)],
        )
        .getSingle();
    return row.read<int>('p');
  }

  /// Plans exercise [exerciseId] on [dayKey], after the ones already there.
  /// Returns the new entry's id.
  Future<int> addEntry(String dayKey, int exerciseId) {
    return _db.transaction(() async {
      return _db
          .into(_db.liftEntries)
          .insert(
            LiftEntriesCompanion.insert(
              dayKey: dayKey,
              exerciseId: exerciseId,
              position: await _nextEntryPosition(dayKey),
              createdAt: _now(),
            ),
          );
    });
  }

  /// Takes an exercise off its day, with its sets.
  Future<void> removeEntry(int entryId) {
    return (_db.delete(
      _db.liftEntries,
    )..where((t) => t.id.equals(entryId))).go();
  }

  /// Swaps the exercise of an entry for another one, keeping its place in
  /// the day and any sets already tracked.
  Future<void> changeEntryExercise(int entryId, int exerciseId) {
    return (_db.update(_db.liftEntries)..where((t) => t.id.equals(entryId)))
        .write(LiftEntriesCompanion(exerciseId: Value(exerciseId)));
  }

  /// Puts the entries of a day in the order of [orderedEntryIds].
  Future<void> reorderEntries(List<int> orderedEntryIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedEntryIds.length; i++) {
        await (_db.update(_db.liftEntries)
              ..where((t) => t.id.equals(orderedEntryIds[i])))
            .write(LiftEntriesCompanion(position: Value(i)));
      }
    });
  }

  // ---- Sets ----

  /// Adds a set after the entry's existing ones; returns its id.
  Future<int> addSet(
    int entryId, {
    required int reps,
    required double weightKg,
  }) {
    return _db.transaction(() async {
      final row = await _db
          .customSelect(
            'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM lift_sets '
            'WHERE entry_id = ?',
            variables: [Variable.withInt(entryId)],
          )
          .getSingle();
      return _db
          .into(_db.liftSets)
          .insert(
            LiftSetsCompanion.insert(
              entryId: entryId,
              position: row.read<int>('p'),
              reps: reps,
              weightKg: weightKg,
              createdAt: _now(),
            ),
          );
    });
  }

  /// Changes the reps and weight of set [setId].
  Future<void> updateSet(
    int setId, {
    required int reps,
    required double weightKg,
  }) {
    return (_db.update(_db.liftSets)..where((t) => t.id.equals(setId))).write(
      LiftSetsCompanion(reps: Value(reps), weightKg: Value(weightKg)),
    );
  }

  /// Removes set [setId].
  Future<void> deleteSet(int setId) {
    return (_db.delete(_db.liftSets)..where((t) => t.id.equals(setId))).go();
  }

  // ---- History ----

  /// The days from [from] to [to] (inclusive) on which exercise
  /// [exerciseId] has tracked sets, oldest first, each with all its sets.
  Stream<List<LiftSession>> watchHistory(
    int exerciseId,
    String from,
    String to,
  ) {
    return watchTables(_db, [
      _db.liftEntries,
      _db.liftSets,
    ], () => _history(exerciseId, from, to));
  }

  Future<List<LiftSession>> _history(
    int exerciseId,
    String from,
    String to,
  ) async {
    final query =
        _db.select(_db.liftSets).join([
            innerJoin(
              _db.liftEntries,
              _db.liftEntries.id.equalsExp(_db.liftSets.entryId),
            ),
          ])
          ..where(
            _db.liftEntries.exerciseId.equals(exerciseId) &
                _db.liftEntries.dayKey.isBetweenValues(from, to),
          )
          ..orderBy([
            OrderingTerm.asc(_db.liftEntries.dayKey),
            OrderingTerm.asc(_db.liftEntries.position),
            OrderingTerm.asc(_db.liftEntries.id),
            OrderingTerm.asc(_db.liftSets.position),
            OrderingTerm.asc(_db.liftSets.id),
          ]);
    final byDay = <String, List<LiftSet>>{};
    for (final r in await query.get()) {
      final s = r.readTable(_db.liftSets);
      (byDay[r.readTable(_db.liftEntries).dayKey] ??= []).add(
        LiftSet(id: s.id, reps: s.reps, weightKg: s.weightKg),
      );
    }
    return [
      for (final e in byDay.entries) LiftSession(dayKey: e.key, sets: e.value),
    ];
  }

  /// The most recent day before [beforeDayKey] on which exercise
  /// [exerciseId] has tracked sets, with all of them; null when there is
  /// none.
  Stream<LiftSession?> watchLastSession(int exerciseId, String beforeDayKey) {
    return watchTables(_db, [_db.liftEntries, _db.liftSets], () async {
      final row = await _db
          .customSelect(
            'SELECT MAX(e.day_key) AS d FROM lift_entries e '
            'JOIN lift_sets s ON s.entry_id = e.id '
            'WHERE e.exercise_id = ? AND e.day_key < ?',
            variables: [
              Variable.withInt(exerciseId),
              Variable.withString(beforeDayKey),
            ],
          )
          .getSingle();
      final day = row.readNullable<String>('d');
      if (day == null) return null;
      return (await _history(exerciseId, day, day)).single;
    });
  }

  // ---- Presets ----

  /// All presets by name, each with its exercises in order.
  Stream<List<LiftPreset>> watchPresets() {
    final tables = <TableInfo>[_db.liftPresets, _db.liftPresetItems, _db.liftExercises];
    return watchTables(_db, tables, () async {
      final presets = await (_db.select(
        _db.liftPresets,
      )..orderBy([(t) => OrderingTerm.asc(t.name.lower())])).get();
      final items =
          await (_db.select(_db.liftPresetItems).join([
                innerJoin(
                  _db.liftExercises,
                  _db.liftExercises.id.equalsExp(
                    _db.liftPresetItems.exerciseId,
                  ),
                ),
              ])..orderBy([
                OrderingTerm.asc(_db.liftPresetItems.position),
                OrderingTerm.asc(_db.liftPresetItems.id),
              ]))
              .get();
      final byPreset = <int, List<LiftExercise>>{};
      for (final r in items) {
        (byPreset[r.readTable(_db.liftPresetItems).presetId] ??= []).add(
          _exercise(r.readTable(_db.liftExercises)),
        );
      }
      return [
        for (final p in presets)
          LiftPreset(
            id: p.id,
            name: p.name,
            exercises: byPreset[p.id] ?? const [],
          ),
      ];
    });
  }

  Future<void> _checkPresetName(String name, {int? exceptId}) async {
    final existing =
        await (_db.select(_db.liftPresets)
              ..where((t) => t.name.lower().equals(name.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null && existing.id != exceptId) {
      throw LiftNameTakenException(name);
    }
  }

  Future<void> _writePresetItems(int presetId, List<int> exerciseIds) async {
    await (_db.delete(
      _db.liftPresetItems,
    )..where((t) => t.presetId.equals(presetId))).go();
    for (var i = 0; i < exerciseIds.length; i++) {
      await _db
          .into(_db.liftPresetItems)
          .insert(
            LiftPresetItemsCompanion.insert(
              presetId: presetId,
              exerciseId: exerciseIds[i],
              position: i,
            ),
          );
    }
  }

  /// Creates a preset with [exerciseIds] in that order; returns its id.
  ///
  /// Throws [LiftNameTakenException] when the name is in use.
  Future<int> createPreset(String name, List<int> exerciseIds) {
    final trimmed = name.trim();
    return _db.transaction(() async {
      await _checkPresetName(trimmed);
      final id = await _db
          .into(_db.liftPresets)
          .insert(
            LiftPresetsCompanion.insert(name: trimmed, createdAt: _now()),
          );
      await _writePresetItems(id, exerciseIds);
      return id;
    });
  }

  /// Renames preset [id] and replaces its exercises with [exerciseIds].
  /// Days it was loaded onto earlier don't change.
  ///
  /// Throws [LiftNameTakenException] when another preset has the name.
  Future<void> updatePreset(int id, String name, List<int> exerciseIds) {
    final trimmed = name.trim();
    return _db.transaction(() async {
      await _checkPresetName(trimmed, exceptId: id);
      await (_db.update(_db.liftPresets)..where((t) => t.id.equals(id))).write(
        LiftPresetsCompanion(name: Value(trimmed)),
      );
      await _writePresetItems(id, exerciseIds);
    });
  }

  /// Deletes preset [id]. Days it was loaded onto keep their exercises.
  Future<void> deletePreset(int id) {
    return (_db.delete(_db.liftPresets)..where((t) => t.id.equals(id))).go();
  }

  /// Copies the exercises of preset [presetId] onto [dayKey], after the ones
  /// already there and skipping any the day already has. The day gets its
  /// own copy: changing it later doesn't change the preset. Returns how many
  /// exercises were added.
  Future<int> loadPreset(int presetId, String dayKey) {
    return _db.transaction(() async {
      final items =
          await (_db.select(_db.liftPresetItems)
                ..where((t) => t.presetId.equals(presetId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      final onDay = {
        for (final e in await (_db.select(
          _db.liftEntries,
        )..where((t) => t.dayKey.equals(dayKey))).get())
          e.exerciseId,
      };
      var position = await _nextEntryPosition(dayKey);
      var added = 0;
      for (final item in items) {
        if (!onDay.add(item.exerciseId)) continue;
        await _db
            .into(_db.liftEntries)
            .insert(
              LiftEntriesCompanion.insert(
                dayKey: dayKey,
                exerciseId: item.exerciseId,
                position: position++,
                createdAt: _now(),
              ),
            );
        added++;
      }
      return added;
    });
  }

  /// Saves the exercises on [dayKey], in order, as a new preset named
  /// [name]; returns its id.
  ///
  /// Throws [LiftNameTakenException] when the name is in use.
  Future<int> savePresetFromDay(String dayKey, String name) async {
    final entries = await _loadDay(dayKey);
    final ids = <int>[];
    for (final e in entries) {
      if (!ids.contains(e.exercise.id)) ids.add(e.exercise.id);
    }
    return createPreset(name, ids);
  }
}
