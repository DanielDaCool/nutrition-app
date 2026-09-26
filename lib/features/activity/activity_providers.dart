// OWNER: Health Connect agent (C).
// Riverpod providers for the Health Connect feature: the public activity
// contract (day/range streams, sync controller) and the status the settings
// tile shows.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import 'activity_repository.dart';
import 'health_package_source.dart';
import 'health_source.dart';
import 'health_sync_service.dart';

export 'health_sync_service.dart' show HealthConnectStatus, HealthStatusKind;

/// Steps and workouts for one day, from the local copy of Health Connect data.
final dayActivityProvider = StreamProvider.family<DayActivity, String>(
  (ref, dayKey) => watchActivityRange(
    ref.watch(databaseProvider),
    dayKey,
    dayKey,
  ).map((days) => days.single),
);

/// One DayActivity per calendar day in [from, to] inclusive, oldest first.
final activityRangeProvider =
    StreamProvider.family<List<DayActivity>, (String from, String to)>(
      (ref, range) =>
          watchActivityRange(ref.watch(databaseProvider), range.$1, range.$2),
    );

/// Adds a manually logged aerobic exercise for [dayKey].
Future<void> addManualExerciseEntry(
  WidgetRef ref, {
  required String dayKey,
  required String activityName,
  required double durationMin,
  required double kcal,
  double? metValue,
  double? distanceKm,
  double? inclinePct,
}) => addManualExercise(
  ref.read(databaseProvider),
  dayKey: dayKey,
  activityName: activityName,
  durationMin: durationMin,
  kcal: kcal,
  metValue: metValue,
  distanceKm: distanceKm,
  inclinePct: inclinePct,
  now: ref.read(clockProvider)(),
);

/// Removes a manually logged exercise by its [WorkoutSummary.id].
Future<void> deleteManualExerciseEntry(WidgetRef ref, String workoutId) {
  final id = int.parse(workoutId.substring('manual-'.length));
  return deleteManualExercise(ref.read(databaseProvider), id);
}

/// Access to Health Connect. Override with a fake in tests.
final healthSourceProvider = Provider<HealthSource>(
  (ref) => HealthPackageSource(),
);

/// The [HealthSyncService] wired to the app database, [healthSourceProvider]
/// and the injectable clock.
final healthSyncServiceProvider = Provider<HealthSyncService>(
  (ref) => HealthSyncService(
    db: ref.watch(databaseProvider),
    source: ref.watch(healthSourceProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Health Connect availability / permission / last error, for the settings
/// tile. Updated by [HealthSyncController].
final healthStatusProvider =
    NotifierProvider<HealthStatusController, HealthConnectStatus>(
      HealthStatusController.new,
    );

/// Holds the current [HealthConnectStatus]; starts as "checking" until the
/// first sync reports back.
class HealthStatusController extends Notifier<HealthConnectStatus> {
  @override
  HealthConnectStatus build() => HealthConnectStatus.checking;

  void set(HealthConnectStatus status) => state = status;

  /// Flags whether a sync is running, keeping the rest of the status.
  void setSyncing(bool syncing) => state = state.copyWith(syncing: syncing);
}

/// Syncs Health Connect into the local database. State = last successful sync
/// time (null if never). syncNow() must never throw; failures go into state.
final healthSyncProvider =
    AsyncNotifierProvider<HealthSyncController, DateTime?>(
      HealthSyncController.new,
    );

/// Drives syncing and the connect flow. Its state is the last successful
/// sync time, loaded from the `hc.lastSyncAt` KeyValue on build.
class HealthSyncController extends AsyncNotifier<DateTime?> {
  Future<void>? _inFlight;

  @override
  FutureOr<DateTime?> build() =>
      ref.watch(healthSyncServiceProvider).lastSyncAt();

  /// Pulls new data from Health Connect. Never prompts, never throws.
  /// Concurrent calls share one run.
  Future<void> syncNow() =>
      _inFlight ??= _syncNow().whenComplete(() => _inFlight = null);

  Future<void> _syncNow() async {
    try {
      try {
        await future; // let build() read the stored time first
      } catch (_) {}
      if (!ref.mounted) return;
      final status = ref.read(healthStatusProvider.notifier);
      status.setSyncing(true);
      final result = await ref.read(healthSyncServiceProvider).sync();
      if (!ref.mounted) return;
      status.set(result.status);
      if (result.ok) {
        state = AsyncData(result.syncedAt);
      } else if (result.error != null) {
        // Riverpod keeps the previous value on AsyncError, so the last
        // successful sync time stays readable via state.value.
        state = AsyncError(
          result.error!,
          result.stackTrace ?? StackTrace.empty,
        );
      }
    } catch (e, st) {
      if (!ref.mounted) return;
      ref
          .read(healthStatusProvider.notifier)
          .set(HealthConnectStatus(HealthStatusKind.error, message: '$e'));
      state = AsyncError(e, st);
    }
  }

  /// Shows the Health Connect permission screens (steps + exercise, then
  /// history access where available), then syncs. Call from a button only.
  Future<void> connect() async {
    final source = ref.read(healthSourceProvider);
    final service = ref.read(healthSyncServiceProvider);
    try {
      if (await source.availability() != HcAvailability.available) {
        await syncNow(); // records the "unavailable" status
        return;
      }
      if (!await source.hasPermissions()) {
        await source.requestPermissions();
      }
      if (await source.hasPermissions() &&
          await source.isHistoryAvailable() &&
          !await source.isHistoryAuthorized()) {
        if (await source.requestHistoryAuthorization()) {
          // Re-read the full 90 days on the next sync.
          await service.forgetSyncCursor();
        }
      }
    } catch (e) {
      if (ref.mounted) {
        ref
            .read(healthStatusProvider.notifier)
            .set(HealthConnectStatus(HealthStatusKind.error, message: '$e'));
      }
      return;
    }
    await syncNow();
  }

  /// Opens the Play Store to install or update Health Connect.
  Future<void> installHealthConnect() async {
    try {
      await ref.read(healthSourceProvider).installHealthConnect();
    } catch (_) {
      // Nothing useful to show; the button stays available.
    }
  }
}
