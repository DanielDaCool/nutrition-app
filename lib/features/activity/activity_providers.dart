// OWNER: Health Connect agent (C). Contract stub: keep the public names/types.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

/// Steps and workouts for one day, from the local copy of Health Connect data.
final dayActivityProvider = StreamProvider.family<DayActivity, String>(
  (ref, dayKey) => Stream.value(
    DayActivity(dayKey: dayKey, steps: null, workouts: const []),
  ), // TODO(C): implement
);

/// One DayActivity per calendar day in [from, to] inclusive, oldest first.
final activityRangeProvider =
    StreamProvider.family<List<DayActivity>, (String from, String to)>(
  (ref, range) => Stream.value(const []), // TODO(C): implement
);

/// Syncs Health Connect into the local database. State = last successful sync
/// time (null if never). syncNow() must never throw; failures go into state.
final healthSyncProvider =
    AsyncNotifierProvider<HealthSyncController, DateTime?>(
  HealthSyncController.new,
);

class HealthSyncController extends AsyncNotifier<DateTime?> {
  @override
  FutureOr<DateTime?> build() => null; // TODO(C): read last sync time

  Future<void> syncNow() async {} // TODO(C): implement
}
