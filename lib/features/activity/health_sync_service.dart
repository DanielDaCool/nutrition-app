// Health Connect -> local database sync, plus the status and result types
// the settings tile and sync controller report.
import 'package:drift/drift.dart';

import '../../core/day_key.dart';
import '../../data/db/database.dart';
import 'activity_format.dart';
import 'health_source.dart';

/// What the Health Connect settings tile shows.
enum HealthStatusKind { checking, unavailable, needsPermission, ok, error }

/// Snapshot of Health Connect availability, permissions and sync activity.
class HealthConnectStatus {
  const HealthConnectStatus(
    this.kind, {
    this.availability,
    this.message,
    this.historyAvailable = false,
    this.historyAuthorized = false,
    this.syncing = false,
  });

  /// Initial status before anything has been checked.
  static const checking = HealthConnectStatus(HealthStatusKind.checking);

  final HealthStatusKind kind;

  /// Set once availability was checked.
  final HcAvailability? availability;

  /// Error text for [HealthStatusKind.error].
  final String? message;

  /// The "read data older than 30 days" permission exists on this phone.
  final bool historyAvailable;

  /// The history permission is granted, so syncs read back 90 days.
  final bool historyAuthorized;

  /// A sync is running right now.
  final bool syncing;

  /// Health Connect is missing or outdated and the Play Store can fix it.
  bool get canInstall =>
      availability == HcAvailability.notInstalled ||
      availability == HcAvailability.updateRequired;

  /// Copy with only the [syncing] flag changed.
  HealthConnectStatus copyWith({bool? syncing}) => HealthConnectStatus(
    kind,
    availability: availability,
    message: message,
    historyAvailable: historyAvailable,
    historyAuthorized: historyAuthorized,
    syncing: syncing ?? this.syncing,
  );
}

/// Outcome of one [HealthSyncService.sync] call. Failures are reported here
/// rather than thrown.
class SyncResult {
  const SyncResult(
    this.status, {
    this.syncedAt,
    this.fromDay,
    this.toDay,
    this.error,
    this.stackTrace,
  });

  final HealthConnectStatus status;

  /// Set when the sync completed.
  final DateTime? syncedAt;

  /// The re-synced window (inclusive day keys), when a sync ran.
  final String? fromDay;
  final String? toDay;

  /// The exception that ended the sync, if any.
  final Object? error;
  final StackTrace? stackTrace;

  /// True when access was OK and the sync ran.
  bool get ok => status.kind == HealthStatusKind.ok;
}

/// Copies steps and workouts from Health Connect into the local database.
///
/// Owns the `DailySteps` and `Workouts` tables and the `hc.*` KeyValues.
class HealthSyncService {
  HealthSyncService({
    required this.db,
    required this.source,
    required this.clock,
  });

  /// KeyValues key: last successful sync time (UTC ISO-8601).
  static const lastSyncAtKey = 'hc.lastSyncAt';

  /// KeyValues key: day key of the last sync; the next sync starts
  /// [overlapDays] before it.
  static const lastSyncedDayKey = 'hc.lastSyncedDay';

  /// Days re-read before the last synced day, to catch late-arriving data.
  static const overlapDays = 2;

  /// How far back the first sync reads (Health Connect's default limit).
  static const defaultHistoryDays = 30;

  /// How far back the first sync reads when history access is granted.
  static const extendedHistoryDays = 90;

  final AppDatabase db;
  final HealthSource source;
  final DateTime Function() clock;

  Future<SyncResult>? _running;

  /// Runs a sync, or joins the one already running. Never throws.
  Future<SyncResult> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  /// Last successful sync time, or null if never synced.
  Future<DateTime?> lastSyncAt() async {
    final v = await _get(lastSyncAtKey);
    return v == null ? null : DateTime.tryParse(v)?.toLocal();
  }

  /// Makes the next sync start from scratch (e.g. after history access was
  /// granted, so it backfills 90 days).
  Future<void> forgetSyncCursor() => (db.delete(
    db.keyValues,
  )..where((t) => t.key.equals(lastSyncedDayKey))).go();

  /// Health Connect availability and permission state, without syncing.
  Future<HealthConnectStatus> checkStatus() async {
    try {
      return await _checkAccess();
    } catch (e) {
      return HealthConnectStatus(HealthStatusKind.error, message: '$e');
    }
  }

  Future<SyncResult> _sync() async {
    try {
      final access = await _checkAccess();
      if (access.kind != HealthStatusKind.ok) return SyncResult(access);

      final now = clock();
      final today = dayKeyOf(now);
      final from = await _windowStart(today, access.historyAuthorized);

      // Each data type is gated on its own permission: Health Connect lets
      // the user grant steps but decline workouts (or vice versa), and one
      // declined optional type must not block the rest of the sync.
      final hasSteps = await source.hasStepsPermission();
      final hasWorkouts = await source.hasWorkoutPermission();

      // Read everything first, then write in one transaction.
      final steps = <String, int?>{};
      if (hasSteps) {
        for (var d = from; d.compareTo(today) <= 0; d = addDays(d, 1)) {
          steps[d] = await source.totalSteps(startOfDay(d), endOfDay(d));
        }
      }
      final workouts = hasWorkouts
          ? await source.workouts(startOfDay(from), endOfDay(today))
          : const <HcWorkout>[];

      await db.transaction(() async {
        for (final e in steps.entries) {
          final count = e.value;
          if (count == null) continue; // read failed: keep what we have
          if (count <= 0) {
            // Health Connect reports 0 for days without data.
            await (db.delete(
              db.dailySteps,
            )..where((t) => t.dayKey.equals(e.key))).go();
          } else {
            await db
                .into(db.dailySteps)
                .insertOnConflictUpdate(
                  DailyStepsCompanion.insert(
                    dayKey: e.key,
                    steps: count,
                    syncedAt: now,
                  ),
                );
          }
        }

        final ids = <String>{};
        for (final w in workouts) {
          if (w.id.isEmpty || ids.contains(w.id)) continue;
          ids.add(w.id);
          final title = (w.title?.trim().isNotEmpty ?? false)
              ? w.title!.trim()
              : readableActivityType(w.activityType);
          await db
              .into(db.workouts)
              .insertOnConflictUpdate(
                WorkoutsCompanion.insert(
                  id: w.id,
                  dayKey: dayKeyOf(w.start),
                  title: title,
                  startTime: w.start,
                  endTime: w.end,
                  activityType: Value(w.activityType),
                  sourceApp: Value(w.sourceApp),
                  kcal: Value(w.kcal),
                  syncedAt: now,
                ),
              );
        }

        // Workouts deleted in Health Connect (or by the source app).
        // The health plugin returns an empty list when a read fails, so an
        // empty result never deletes anything: a failed read must not wipe
        // stored workouts. (Cost: deleting the only workout in the window
        // isn't mirrored until another workout lands in that window.)
        if (ids.isNotEmpty) {
          await (db.delete(db.workouts)..where(
                (t) =>
                    t.dayKey.isBetweenValues(from, today) & t.id.isNotIn(ids),
              ))
              .go();
        }

        await _put(lastSyncAtKey, now.toUtc().toIso8601String());
        await _put(lastSyncedDayKey, today);
      });

      return SyncResult(access, syncedAt: now, fromDay: from, toDay: today);
    } catch (e, st) {
      return SyncResult(
        HealthConnectStatus(HealthStatusKind.error, message: _describe(e)),
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<HealthConnectStatus> _checkAccess() async {
    final availability = await source.availability();
    if (availability != HcAvailability.available) {
      return HealthConnectStatus(
        HealthStatusKind.unavailable,
        availability: availability,
      );
    }
    final historyAvailable = await source.isHistoryAvailable();
    // Steps and workouts are independent Health Connect permissions the user
    // can toggle separately; needing *both* declined to count as
    // "not connected" means one still-granted type isn't blocked by the
    // other having been turned off (see hasStepsPermission/hasWorkoutPermission
    // and how the sync itself uses them).
    if (!await source.hasPermissions()) {
      return HealthConnectStatus(
        HealthStatusKind.needsPermission,
        availability: availability,
        historyAvailable: historyAvailable,
      );
    }
    final historyAuthorized =
        historyAvailable && await source.isHistoryAuthorized();
    return HealthConnectStatus(
      HealthStatusKind.ok,
      availability: availability,
      historyAvailable: historyAvailable,
      historyAuthorized: historyAuthorized,
    );
  }

  /// First day to (re)read: (last synced day - 2), but no further back than
  /// Health Connect allows (30 days, or 90 with history access).
  Future<String> _windowStart(String today, bool historyAuthorized) async {
    final maxBack = historyAuthorized
        ? extendedHistoryDays
        : defaultHistoryDays;
    final earliest = addDays(today, -maxBack);
    final last = await _get(lastSyncedDayKey);
    if (last == null) return earliest;
    String from;
    try {
      from = addDays(last, -overlapDays);
    } on FormatException {
      return earliest;
    }
    if (from.compareTo(earliest) < 0) from = earliest;
    if (from.compareTo(today) > 0) from = today; // clock moved backwards
    return from;
  }

  Future<String?> _get(String key) async {
    final row = await (db.select(
      db.keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _put(String key, String value) => db
      .into(db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion.insert(key: key, value: value),
      );

  static String _describe(Object e) {
    final text = e.toString();
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }
}
