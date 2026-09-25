// OWNER: weight & charts agent (D). Contract stub: keep the public names/types.
// Weigh-in storage and the public weight providers ([weighInsProvider],
// [weightTrendProvider]) other features read.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../domain/trend.dart';
import 'table_watch.dart';

/// Writes the WeighIns table (this feature is its only writer).
class WeightRepository {
  WeightRepository(this._db, this._now);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// All weigh-ins as dayKey -> kg, updating on every change.
  Stream<Map<String, double>> watchAll() {
    final query = _db.select(_db.weighIns)
      ..orderBy([(t) => OrderingTerm.asc(t.dayKey)]);
    return watchTables(_db, [_db.weighIns], () async {
      final rows = await query.get();
      return {for (final r in rows) r.dayKey: r.weightKg};
    });
  }

  /// Saves the weigh-in for [dayKey], replacing any earlier one that day.
  Future<void> upsert(String dayKey, double weightKg) {
    return _db
        .into(_db.weighIns)
        .insertOnConflictUpdate(
          WeighInsCompanion.insert(
            dayKey: dayKey,
            weightKg: weightKg,
            createdAt: _now(),
          ),
        );
  }

  /// Moves/edits a weigh-in: removes [oldDayKey] if the day changed.
  Future<void> replace(String oldDayKey, String dayKey, double weightKg) {
    return _db.transaction(() async {
      if (oldDayKey != dayKey) await delete(oldDayKey);
      await upsert(dayKey, weightKg);
    });
  }

  /// Removes the weigh-in for [dayKey], if any.
  Future<void> delete(String dayKey) {
    return (_db.delete(
      _db.weighIns,
    )..where((t) => t.dayKey.equals(dayKey))).go();
  }
}

/// The [WeightRepository] on the app database, stamping `createdAt` with the
/// injectable clock.
final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) =>
      WeightRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// All weigh-ins: dayKey -> kg.
final weighInsProvider = StreamProvider<Map<String, double>>(
  (ref) => ref.watch(weightRepositoryProvider).watchAll(),
);

/// Daily trend points from the first weigh-in through today.
///
/// Days without a weigh-in carry the trend forward (see `computeTrend`).
/// Empty when there are no weigh-ins. "Today" is read when weigh-ins change,
/// not on a timer.
final weightTrendProvider = StreamProvider<List<TrendPoint>>((ref) async* {
  final weighIns = await ref.watch(weighInsProvider.future);
  final today = dayKeyOf(ref.read(clockProvider)());
  yield computeTrend(weighIns, until: today);
});
