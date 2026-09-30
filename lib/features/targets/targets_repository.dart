// OWNER: engine agent (A).
// Data access for the targets feature: profile, target history, engine input
// and the reactive streams behind the targets providers.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/day_key.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import 'engine/engine.dart';

/// Loads engine input from the DB, and reads/writes Profiles + TargetHistory.
class TargetsRepository {
  TargetsRepository(this.db, this.clock);

  final AppDatabase db;
  final DateTime Function() clock;

  /// Today's day key according to [clock].
  String get today => dayKeyOf(clock());

  // ---- Profile -----------------------------------------------------------

  /// The single profile row (id = 1), or null before setup.
  Future<Profile?> loadProfile() =>
      (db.select(db.profiles)..where((p) => p.id.equals(1))).getSingleOrNull();

  /// Uses [watch] (table-update based) rather than a drift query stream:
  /// drift query streams leave a zero-duration timer behind on cancel, which
  /// fails widget tests that end right after unmounting.
  Stream<Profile?> watchProfile() => watch([db.profiles], loadProfile);

  /// Inserts or updates the single profile row. [birthDate] is truncated to
  /// a local date; [checkInWeekday] uses DateTime.weekday (7 = Sunday).
  Future<void> saveProfile({
    required Sex sex,
    required DateTime birthDate,
    required double heightCm,
    required ActivityLevel activityLevel,
    required double goalWeightKg,
    required double weeklyRatePct,
    required double proteinPerKg,
    required int checkInWeekday,
  }) => db
      .into(db.profiles)
      .insertOnConflictUpdate(
        ProfilesCompanion.insert(
          id: const Value(1),
          sex: sex.index,
          birthDate: DateTime(birthDate.year, birthDate.month, birthDate.day),
          heightCm: heightCm,
          activityLevel: activityLevel.index,
          goalWeightKg: goalWeightKg,
          weeklyRatePct: Value(weeklyRatePct),
          proteinPerKg: Value(proteinPerKg),
          checkInWeekday: Value(checkInWeekday),
          updatedAt: clock(),
        ),
      );

  /// Converts a DB row (enum indexes) to the engine's profile type.
  static EngineProfile toEngineProfile(Profile p) => EngineProfile(
    sex: Sex.values[p.sex],
    birthDate: p.birthDate,
    heightCm: p.heightCm,
    activityLevel: ActivityLevel.values[p.activityLevel],
    goalWeightKg: p.goalWeightKg,
    weeklyRatePct: p.weeklyRatePct,
    proteinPerKg: p.proteinPerKg,
  );

  // ---- Targets -----------------------------------------------------------

  /// Newest target with effectiveFrom <= [day] (or < [day] when [before]).
  Future<TargetRecord?> latestTarget(String day, {bool before = false}) {
    final q = db.select(db.targetHistory)
      ..where(
        (t) => before
            ? t.effectiveFrom.isSmallerThanValue(day)
            : t.effectiveFrom.isSmallerOrEqualValue(day),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.effectiveFrom),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// True when a target row starts exactly on [day].
  Future<bool> hasTargetOn(String day) async {
    final q = db.selectOnly(db.targetHistory)
      ..addColumns([db.targetHistory.id])
      ..where(db.targetHistory.effectiveFrom.equals(day))
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Converts a TargetHistory row to the contract type.
  static DailyTargets toDailyTargets(TargetRecord r) => DailyTargets(
    effectiveFrom: r.effectiveFrom,
    macros: Macros(
      kcal: r.kcal,
      proteinG: r.proteinG,
      fatG: r.fatG,
      carbsG: r.carbsG,
    ),
    maintenanceKcal: r.maintenanceKcal,
    method: TargetMethod.values[r.method],
  );

  /// Stores [rec] as the target from its effectiveFrom day. A target already
  /// stored for that same day is replaced, so there is one row per day.
  Future<void> saveRecommendation(Recommendation rec) => _saveRow(
    effectiveFrom: rec.effectiveFrom,
    macros: rec.macros,
    maintenanceKcal: rec.maintenanceKcal,
    method: rec.method,
    explanationJson: jsonEncode(rec.explanation.toJson()),
  );

  /// Skip at check-in: re-stores the current target for today, which marks
  /// the check-in as done without changing any number.
  ///
  /// The kept target's own explanation is copied forward (tagged `skipped`)
  /// so the next check-in still sees the real phase and Kalman state; the
  /// Kalman variance grows by one week of process noise, like any other week
  /// without a fresh measurement (docs/engine.md §3).
  Future<void> keepCurrentTarget() async {
    final day = today;
    final current = await latestTarget(day);
    if (current == null) return;
    if (current.effectiveFrom == day) return;
    final kept = await _explanationMap(current);
    final variance = (kept?['measuredVarianceKcal2'] as num?)?.toDouble();
    final explanation = <String, Object?>{
      ...?kept,
      if (variance != null)
        'measuredVarianceKcal2': variance + kProcessNoiseVarianceKcal2,
      'skipped': true,
      'keptFrom': current.id,
    };
    await _saveRow(
      effectiveFrom: day,
      macros: Macros(
        kcal: current.kcal,
        proteinG: current.proteinG,
        fatG: current.fatG,
        carbsG: current.carbsG,
      ),
      maintenanceKcal: current.maintenanceKcal,
      method: TargetMethod.values[current.method],
      explanationJson: jsonEncode(explanation),
    );
  }

  /// The stored explanation of [row] as a JSON map. A skip row written
  /// before skips copied the explanation forward holds only
  /// `{'skipped': true, 'keptFrom': id}`; that marker is followed back to the
  /// target it kept. Null when there is no readable explanation.
  Future<Map<String, Object?>?> _explanationMap(TargetRecord? row) async {
    var r = row;
    // Bounded, in case of a (never expected) cycle of markers.
    for (var hops = 0; r != null && hops < 20; hops++) {
      final json = r.explanationJson;
      if (json == null) return null;
      final Map<String, Object?> map;
      try {
        map = jsonDecode(json) as Map<String, Object?>;
      } on Object {
        return null;
      }
      if (map.containsKey('formulaKcal')) return map;
      final keptFrom = map['keptFrom'];
      if (keptFrom is! int) return null;
      r = await (db.select(
        db.targetHistory,
      )..where((t) => t.id.equals(keptFrom))).getSingleOrNull();
    }
    return null;
  }

  // Replaces any row for the same effectiveFrom day in one transaction.
  Future<void> _saveRow({
    required String effectiveFrom,
    required Macros macros,
    required double maintenanceKcal,
    required TargetMethod method,
    required String? explanationJson,
  }) => db.transaction(() async {
    await (db.delete(
      db.targetHistory,
    )..where((t) => t.effectiveFrom.equals(effectiveFrom))).go();
    await db
        .into(db.targetHistory)
        .insert(
          TargetHistoryCompanion.insert(
            effectiveFrom: effectiveFrom,
            kcal: macros.kcal,
            proteinG: macros.proteinG,
            fatG: macros.fatG,
            carbsG: macros.carbsG,
            maintenanceKcal: maintenanceKcal,
            method: method.index,
            explanationJson: Value(explanationJson),
            createdAt: clock(),
          ),
        );
  });

  // ---- Engine input ------------------------------------------------------

  /// Engine input for [day] (default today), or null when there is no profile
  /// or no weigh-in yet.
  Future<EngineInput?> loadInput({String? day}) async {
    final d = day ?? today;
    final profile = await loadProfile();
    if (profile == null) return null;

    final weighRows = await (db.select(
      db.weighIns,
    )..where((w) => w.dayKey.isSmallerOrEqualValue(d))).get();
    if (weighRows.isEmpty) return null;
    final weighIns = {for (final w in weighRows) w.dayKey: w.weightKg};

    final from = addDays(d, -kWindowDays);
    final to = addDays(d, -1);

    final kcalSum = db.foodLogEntries.kcal.sum();
    final dayCol = db.foodLogEntries.dayKey;
    final sums =
        await (db.selectOnly(db.foodLogEntries)
              ..addColumns([dayCol, kcalSum])
              ..where(dayCol.isBetweenValues(from, to))
              ..groupBy([dayCol]))
            .get();
    final kcalByDay = {
      for (final r in sums) r.read(dayCol)!: r.read(kcalSum) ?? 0.0,
    };

    final statuses = await (db.select(
      db.dayStatuses,
    )..where((s) => s.dayKey.isBetweenValues(from, to))).get();
    final fully = {
      for (final s in statuses)
        if (s.fullyLogged) s.dayKey,
    };

    final intake = <String, DayLog>{};
    for (final k in {...kcalByDay.keys, ...fully}) {
      intake[k] = DayLog(
        kcal: kcalByDay[k] ?? 0,
        fullyLogged: fully.contains(k),
      );
    }

    final previous = await latestTarget(d, before: true);
    Explanation? previousExplanation;
    final map = await _explanationMap(previous);
    if (map != null) {
      try {
        previousExplanation = Explanation.fromJson(map);
      } on Object {
        // A row from before this engine version that can't be decoded.
        // Phase/Kalman state falls back to null below (no signal).
      }
    }
    return EngineInput(
      today: d,
      profile: toEngineProfile(profile),
      weighIns: weighIns,
      intake: intake,
      previousMaintenanceKcal: previous?.maintenanceKcal,
      previousPhaseStartDayKey: previousExplanation?.phaseStartDayKey,
      previousWeeklyRatePctRaw: previousExplanation?.weeklyRatePctRaw,
      previousFormulaKcal: previousExplanation?.formulaKcal,
      previousMaintenanceMode: previousExplanation?.maintenanceMode,
      previousSmoothedMeasuredKcal: previousExplanation?.smoothedMeasuredKcal,
      previousMeasuredVarianceKcal2: previousExplanation?.measuredVarianceKcal2,
    );
  }

  /// A fresh recommendation for today, or null (no profile / no weigh-in).
  Future<Recommendation?> recommendToday() async {
    final input = await loadInput();
    return input == null ? null : recommend(input);
  }

  // ---- Provider logic ----------------------------------------------------

  /// Targets in effect today. When a profile exists but no target does yet,
  /// the first formula-based target is created and returned.
  Future<DailyTargets?> currentTargets() async {
    final day = today;
    final existing = await latestTarget(day);
    if (existing != null) return toDailyTargets(existing);
    final anyTarget = await (db.select(db.targetHistory)..limit(1)).get();
    if (anyTarget.isNotEmpty) return null; // only future-dated targets
    final rec = await recommendToday();
    if (rec == null) return null;
    await saveRecommendation(rec);
    return rec.toDailyTargets();
  }

  /// True when there is at least one weigh-in on or before [day].
  Future<bool> hasWeighInBy(String day) async {
    final q = db.selectOnly(db.weighIns)
      ..addColumns([db.weighIns.dayKey])
      ..where(db.weighIns.dayKey.isSmallerOrEqualValue(day))
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Spec §6, with a missed check-in staying due until it is done.
  ///
  /// Never due without a profile or a weigh-in (there is nothing to review).
  /// Otherwise due when no target is in effect yet, or when the current
  /// target started before the most recent check-in weekday on or before
  /// today (see [lastCheckInDay]).
  Future<bool> checkInDue() async {
    final profile = await loadProfile();
    if (profile == null) return false;
    final day = today;
    if (!await hasWeighInBy(day)) return false;
    final current = await latestTarget(day);
    if (current == null) return true;
    return isCheckInDue(
      today: day,
      currentEffectiveFrom: current.effectiveFrom,
      checkInWeekday: profile.checkInWeekday,
    );
  }

  /// Emits [compute] now and again whenever one of [tables] changes or the
  /// day rolls over. Recomputations are coalesced.
  Stream<T> watch<T>(
    List<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() compute,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? sub;
    Timer? dayTimer;
    var running = false;
    var dirty = false;
    var lastDay = today;

    Future<void> run() async {
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      do {
        dirty = false;
        lastDay = today;
        try {
          final value = await compute();
          if (!controller.isClosed) controller.add(value);
        } catch (e, s) {
          if (!controller.isClosed) controller.addError(e, s);
        }
      } while (dirty && !controller.isClosed);
      running = false;
    }

    controller = StreamController<T>(
      onListen: () {
        sub = db
            .tableUpdates(TableUpdateQuery.onAllTables(tables))
            .listen((_) => run());
        dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          if (today != lastDay) run();
        });
        run();
      },
      onCancel: () async {
        dayTimer?.cancel();
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Stream behind `currentTargetsProvider`; see [currentTargets].
  Stream<DailyTargets?> watchCurrentTargets() =>
      watch([db.profiles, db.targetHistory, db.weighIns], currentTargets);

  /// Stream behind `checkInDueProvider`; see [checkInDue].
  Stream<bool> watchCheckInDue() =>
      watch([db.profiles, db.targetHistory, db.weighIns], checkInDue);
}

/// The most recent day on or before [today] that falls on [checkInWeekday]
/// (DateTime.weekday, 7 = Sunday). Pure date logic.
String lastCheckInDay(String today, int checkInWeekday) {
  final back = (startOfDay(today).weekday - checkInWeekday) % 7;
  return addDays(today, -back);
}

/// True when the target in effect ([currentEffectiveFrom]) started before the
/// latest check-in day, i.e. that check-in has not been done (accepted or
/// skipped) yet. A missed check-in day stays due until it is done.
bool isCheckInDue({
  required String today,
  required String currentEffectiveFrom,
  required int checkInWeekday,
}) => currentEffectiveFrom.compareTo(lastCheckInDay(today, checkInWeekday)) < 0;
