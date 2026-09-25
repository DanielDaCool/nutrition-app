// OWNER: engine agent (A).
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

  String get today => dayKeyOf(clock());

  // ---- Profile -----------------------------------------------------------

  Future<Profile?> loadProfile() =>
      (db.select(db.profiles)..where((p) => p.id.equals(1))).getSingleOrNull();

  /// Uses [watch] (table-update based) rather than a drift query stream:
  /// drift query streams leave a zero-duration timer behind on cancel, which
  /// fails widget tests that end right after unmounting.
  Stream<Profile?> watchProfile() => watch([db.profiles], loadProfile);

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

  Future<bool> hasTargetOn(String day) async {
    final q = db.selectOnly(db.targetHistory)
      ..addColumns([db.targetHistory.id])
      ..where(db.targetHistory.effectiveFrom.equals(day))
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

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
  Future<void> keepCurrentTarget() async {
    final day = today;
    final current = await latestTarget(day);
    if (current == null) return;
    if (current.effectiveFrom == day) return;
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
      explanationJson: jsonEncode({'skipped': true, 'keptFrom': current.id}),
    );
  }

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
    return EngineInput(
      today: d,
      profile: toEngineProfile(profile),
      weighIns: weighIns,
      intake: intake,
      previousMaintenanceKcal: previous?.maintenanceKcal,
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

  /// Spec §6: due on the check-in weekday when no target starts today, or
  /// when a profile exists but no target yet.
  Future<bool> checkInDue() async {
    final profile = await loadProfile();
    if (profile == null) return false;
    final day = today;
    if (await latestTarget(day) == null) return true;
    return startOfDay(day).weekday == profile.checkInWeekday &&
        !await hasTargetOn(day);
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

  Stream<DailyTargets?> watchCurrentTargets() =>
      watch([db.profiles, db.targetHistory, db.weighIns], currentTargets);

  Stream<bool> watchCheckInDue() =>
      watch([db.profiles, db.targetHistory], checkInDue);
}
