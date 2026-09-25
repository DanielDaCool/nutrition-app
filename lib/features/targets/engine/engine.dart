/// Calorie & macro engine (docs/engine.md). Pure Dart: no Flutter, no DB.
///
/// Entry point: [recommend].
library;

import 'dart:math' as math;

import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../../../domain/trend.dart';

/// kcal stored in one kg of body weight change.
const double kKcalPerKg = 7700;

/// Adaptive window length in days (ends yesterday).
const int kWindowDays = 21;

/// Maximum change of maintenance per weekly update when a previous target exists.
const double kMaxMaintenanceChangeKcal = 150;

/// Minimum data needed for a measured maintenance estimate.
const int kMinSpanDays = 10;
/// Minimum fully-logged days in the window for a measured estimate.
const int kMinLoggedDays = 7;
/// Minimum weigh-ins in the window for a measured estimate.
const int kMinWeighIns = 6;

/// Carb floor (g) kept by lowering fat toward [kMinFatPerKg].
const double kMinCarbsG = 50;
/// Lowest fat (g per kg of trend weight) when protecting the carb floor.
const double kMinFatPerKg = 0.6;
/// Default fat (g per kg of trend weight), unless 25% of kcal is more.
const double kFatPerKg = 0.8;

/// Profile fields the engine needs.
class EngineProfile {
  const EngineProfile({
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.activityLevel,
    required this.goalWeightKg,
    required this.weeklyRatePct,
    required this.proteinPerKg,
  });

  final Sex sex;
  final DateTime birthDate;
  final double heightCm;
  final ActivityLevel activityLevel;
  final double goalWeightKg;

  /// Desired loss per week as % of body weight (0.25–1.0).
  final double weeklyRatePct;

  /// Protein grams per kg of reference weight (1.6–2.2).
  final double proteinPerKg;
}

/// Intake for one day.
class DayLog {
  const DayLog({required this.kcal, required this.fullyLogged});

  final double kcal;
  final bool fullyLogged;
}

/// Everything [recommend] needs, already loaded from the DB.
class EngineInput {
  const EngineInput({
    required this.today,
    required this.profile,
    required this.weighIns,
    required this.intake,
    this.previousMaintenanceKcal,
  });

  /// Day key of "today" (the day the recommendation takes effect).
  final String today;
  final EngineProfile profile;

  /// dayKey -> scale weight in kg. Must contain at least one weigh-in on or
  /// before [today].
  final Map<String, double> weighIns;

  /// dayKey -> intake. Days that are missing count as not fully logged.
  final Map<String, DayLog> intake;

  /// Maintenance of the previously accepted target (null for the first one).
  final double? previousMaintenanceKcal;
}

/// The numbers behind a recommendation, stored as JSON with the target.
class Explanation {
  const Explanation({
    required this.trendKg,
    required this.ageYears,
    required this.bmrKcal,
    required this.formulaKcal,
    required this.measuredKcal,
    required this.measuredClamped,
    required this.measuredMissingReason,
    required this.weight,
    required this.avgIntakeKcal,
    required this.trendDeltaKg,
    required this.days,
    required this.loggedDays,
    required this.weighInsInWindow,
    required this.windowStart,
    required this.windowEnd,
    required this.unlimitedMaintenanceKcal,
    required this.previousMaintenanceKcal,
    required this.changeLimited,
    required this.maintenanceKcal,
    required this.deficitKcal,
    required this.floorKcal,
    required this.floorApplied,
    required this.maintenanceMode,
  });

  /// Smoothed trend weight today (kg); used instead of the raw scale weight.
  final double trendKg;
  final int ageYears;
  final double bmrKcal;
  /// Formula maintenance: BMR × activity factor.
  final double formulaKcal;

  /// Measured maintenance after clamping, or null when data was insufficient.
  final double? measuredKcal;

  /// True when the raw measured value was outside [0.6, 1.6] × formula.
  final bool measuredClamped;

  /// Why [measuredKcal] is null (plain English), else null.
  final String? measuredMissingReason;

  /// Weight of the measured estimate in the blend (0–1).
  final double weight;
  final double? avgIntakeKcal;
  final double? trendDeltaKg;

  /// Span in days between the two trend points used.
  final int? days;

  /// Fully-logged days in the window (n).
  final int loggedDays;
  final int weighInsInWindow;
  /// First and last day keys of the adaptive window (inclusive).
  final String windowStart;
  final String windowEnd;

  /// Blended maintenance before the ±150 kcal change limit.
  final double unlimitedMaintenanceKcal;
  final double? previousMaintenanceKcal;
  /// True when the ±[kMaxMaintenanceChangeKcal] limit changed the result.
  final bool changeLimited;
  final double maintenanceKcal;
  /// Daily deficit from the weekly loss rate (0 in maintenance mode).
  final double deficitKcal;
  /// Minimum target: max(BMR, 1500 men / 1200 women).
  final double floorKcal;
  final bool floorApplied;
  /// True when trend weight is at or below goal, so target = maintenance.
  final bool maintenanceMode;

  /// Serialised into `TargetHistory.explanationJson`.
  Map<String, Object?> toJson() => {
    'trendKg': trendKg,
    'ageYears': ageYears,
    'bmrKcal': bmrKcal,
    'formulaKcal': formulaKcal,
    'measuredKcal': measuredKcal,
    'measuredClamped': measuredClamped,
    'measuredMissingReason': measuredMissingReason,
    'weight': weight,
    'avgIntakeKcal': avgIntakeKcal,
    'trendDeltaKg': trendDeltaKg,
    'days': days,
    'loggedDays': loggedDays,
    'weighInsInWindow': weighInsInWindow,
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    'unlimitedMaintenanceKcal': unlimitedMaintenanceKcal,
    'previousMaintenanceKcal': previousMaintenanceKcal,
    'changeLimited': changeLimited,
    'maintenanceKcal': maintenanceKcal,
    'deficitKcal': deficitKcal,
    'floorKcal': floorKcal,
    'floorApplied': floorApplied,
    'maintenanceMode': maintenanceMode,
  };

  /// Inverse of [toJson]. Missing bool fields default to false. Throws on
  /// JSON that isn't an explanation (e.g. the `{'skipped': true}` marker).
  static Explanation fromJson(Map<String, Object?> j) {
    double d(String k) => (j[k] as num).toDouble();
    double? nd(String k) => (j[k] as num?)?.toDouble();
    return Explanation(
      trendKg: d('trendKg'),
      ageYears: (j['ageYears'] as num).toInt(),
      bmrKcal: d('bmrKcal'),
      formulaKcal: d('formulaKcal'),
      measuredKcal: nd('measuredKcal'),
      measuredClamped: j['measuredClamped'] as bool? ?? false,
      measuredMissingReason: j['measuredMissingReason'] as String?,
      weight: d('weight'),
      avgIntakeKcal: nd('avgIntakeKcal'),
      trendDeltaKg: nd('trendDeltaKg'),
      days: (j['days'] as num?)?.toInt(),
      loggedDays: (j['loggedDays'] as num).toInt(),
      weighInsInWindow: (j['weighInsInWindow'] as num).toInt(),
      windowStart: j['windowStart'] as String,
      windowEnd: j['windowEnd'] as String,
      unlimitedMaintenanceKcal: d('unlimitedMaintenanceKcal'),
      previousMaintenanceKcal: nd('previousMaintenanceKcal'),
      changeLimited: j['changeLimited'] as bool? ?? false,
      maintenanceKcal: d('maintenanceKcal'),
      deficitKcal: d('deficitKcal'),
      floorKcal: d('floorKcal'),
      floorApplied: j['floorApplied'] as bool? ?? false,
      maintenanceMode: j['maintenanceMode'] as bool? ?? false,
    );
  }
}

/// Targets proposed by [recommend], plus the numbers behind them.
class Recommendation {
  const Recommendation({
    required this.effectiveFrom,
    required this.macros,
    required this.maintenanceKcal,
    required this.method,
    required this.explanation,
  });

  final String effectiveFrom;

  /// kcal is the calorie target (rounded to 10); grams rounded to 5.
  final Macros macros;
  final double maintenanceKcal;
  final TargetMethod method;
  final Explanation explanation;

  /// The contract type the rest of the app uses.
  DailyTargets toDailyTargets() => DailyTargets(
    effectiveFrom: effectiveFrom,
    macros: macros,
    maintenanceKcal: maintenanceKcal,
    method: method,
  );
}

/// Whole years between [birthDate] and [today] (a day key).
int ageOn(DateTime birthDate, String today) {
  final t = startOfDay(today);
  var age = t.year - birthDate.year;
  if (t.month < birthDate.month ||
      (t.month == birthDate.month && t.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// Mifflin-St Jeor BMR in kcal/day.
double mifflinStJeorBmr({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int ageYears,
}) =>
    10 * weightKg +
    6.25 * heightCm -
    5 * ageYears +
    (sex == Sex.male ? 5 : -161);

/// [value] rounded to the nearest multiple of [step].
double roundTo(double value, double step) => (value / step).round() * step;

/// Protein / fat / carbs for [targetKcal] (spec §5). kcal is kept as given.
Macros computeMacros({
  required double targetKcal,
  required double trendKg,
  required double goalWeightKg,
  required double proteinPerKg,
}) {
  final referenceKg = math.min(trendKg, goalWeightKg * 1.15);
  final proteinG = roundTo(proteinPerKg * referenceKg, 5);
  var fatG = roundTo(math.max(kFatPerKg * trendKg, 0.25 * targetKcal / 9), 5);
  var carbsG = (targetKcal - proteinG * 4 - fatG * 9) / 4;
  if (carbsG < kMinCarbsG) {
    // Lower fat just enough to restore the carb floor, never below 0.6 g/kg.
    // Fat is rounded down (to keep >= 50 g carbs) but the 0.6 g/kg minimum is
    // rounded up (so it is never undercut).
    final fatForCarbFloor = (targetKcal - proteinG * 4 - kMinCarbsG * 4) / 9;
    final minFatG = (kMinFatPerKg * trendKg / 5).ceil() * 5.0;
    final loweredFat = math.max((fatForCarbFloor / 5).floor() * 5.0, minFatG);
    fatG = math.min(fatG, loweredFat);
    carbsG = (targetKcal - proteinG * 4 - fatG * 9) / 4;
  }
  carbsG = math.max(0, roundTo(carbsG, 5));
  return Macros(
    kcal: targetKcal,
    proteinG: proteinG,
    fatG: fatG,
    carbsG: carbsG,
  );
}

class _Measured {
  _Measured({
    this.value,
    this.clamped = false,
    this.reason,
    this.avgIntake,
    this.deltaKg,
    this.days,
  });
  final double? value;
  final bool clamped;
  final String? reason;
  final double? avgIntake;
  final double? deltaKg;
  final int? days;
}

/// Computes the recommended daily targets for [EngineInput.today].
///
/// Throws [ArgumentError] when there is no weigh-in on or before today.
Recommendation recommend(EngineInput input) {
  final today = input.today;
  final p = input.profile;

  final weighIns = {
    for (final e in input.weighIns.entries)
      if (e.key.compareTo(today) <= 0) e.key: e.value,
  };
  if (weighIns.isEmpty) {
    throw ArgumentError('recommend() needs at least one weigh-in');
  }

  final windowEnd = addDays(today, -1);
  final windowStart = addDays(today, -kWindowDays);
  final trend = computeTrend(weighIns, until: today);
  final trendByDay = {for (final t in trend) t.dayKey: t.trendKg};
  final trendKg = trend.last.trendKg;

  // 1. Formula.
  final age = ageOn(p.birthDate, today);
  final bmr = mifflinStJeorBmr(
    sex: p.sex,
    weightKg: trendKg,
    heightCm: p.heightCm,
    ageYears: age,
  );
  final formula = bmr * p.activityLevel.factor;

  // 2. Measured.
  final loggedKcal = <double>[];
  for (var d = windowStart; d.compareTo(windowEnd) <= 0; d = addDays(d, 1)) {
    final log = input.intake[d];
    if (log != null && log.fullyLogged) loggedKcal.add(log.kcal);
  }
  final n = loggedKcal.length;
  final weighInsInWindow = weighIns.keys
      .where(
        (k) => k.compareTo(windowStart) >= 0 && k.compareTo(windowEnd) <= 0,
      )
      .length;

  _Measured measure() {
    final endTrend = trendByDay[windowEnd];
    if (endTrend == null) {
      return _Measured(reason: 'no weigh-ins before yesterday');
    }
    String startDay;
    if (trendByDay.containsKey(windowStart)) {
      startDay = windowStart;
    } else {
      // Trend starts inside the window: use its first point.
      startDay = trend.first.dayKey;
    }
    final span = daysBetween(startDay, windowEnd);
    if (span < kMinSpanDays) {
      return _Measured(
        reason: 'weight trend covers only $span days (need $kMinSpanDays)',
      );
    }
    if (n < kMinLoggedDays) {
      return _Measured(
        reason:
            'only $n fully logged days in the last $kWindowDays '
            '(need $kMinLoggedDays)',
      );
    }
    if (weighInsInWindow < kMinWeighIns) {
      return _Measured(
        reason:
            'only $weighInsInWindow weigh-ins in the last $kWindowDays '
            'days (need $kMinWeighIns)',
      );
    }
    final avgIntake = loggedKcal.reduce((a, b) => a + b) / n;
    final delta = endTrend - trendByDay[startDay]!;
    final raw = avgIntake - delta * kKcalPerKg / span;
    final lo = 0.6 * formula, hi = 1.6 * formula;
    final value = raw.clamp(lo, hi).toDouble();
    return _Measured(
      value: value,
      clamped: value != raw,
      avgIntake: avgIntake,
      deltaKg: delta,
      days: span,
    );
  }

  final m = measure();

  // 3. Blend.
  final w = m.value == null ? 0.0 : ((n - 7) / 14).clamp(0.0, 1.0).toDouble();
  final blended = (1 - w) * formula + w * (m.value ?? 0);
  final method = w == 0
      ? TargetMethod.formula
      : w == 1
      ? TargetMethod.adaptive
      : TargetMethod.blended;

  var maintenance = blended;
  var changeLimited = false;
  final prev = input.previousMaintenanceKcal;
  if (prev != null) {
    maintenance = blended
        .clamp(
          prev - kMaxMaintenanceChangeKcal,
          prev + kMaxMaintenanceChangeKcal,
        )
        .toDouble();
    changeLimited = maintenance != blended;
  }

  // 4. Target.
  final floor = math.max(bmr, p.sex == Sex.male ? 1500.0 : 1200.0);
  final maintenanceMode = trendKg <= p.goalWeightKg;
  var deficit = 0.0;
  var floorApplied = false;
  double target;
  if (maintenanceMode) {
    target = maintenance;
  } else {
    deficit = p.weeklyRatePct / 100 * trendKg * kKcalPerKg / 7;
    deficit = math.min(deficit, math.min(0.25 * maintenance, 1000));
    target = maintenance - deficit;
    if (target < floor) {
      target = floor;
      floorApplied = true;
    }
  }
  target = roundTo(target, 10);

  // 5. Macros.
  final macros = computeMacros(
    targetKcal: target,
    trendKg: trendKg,
    goalWeightKg: p.goalWeightKg,
    proteinPerKg: p.proteinPerKg,
  );

  return Recommendation(
    effectiveFrom: today,
    macros: macros,
    maintenanceKcal: maintenance,
    method: method,
    explanation: Explanation(
      trendKg: trendKg,
      ageYears: age,
      bmrKcal: bmr,
      formulaKcal: formula,
      measuredKcal: m.value,
      measuredClamped: m.clamped,
      measuredMissingReason: m.reason,
      weight: w,
      avgIntakeKcal: m.avgIntake,
      trendDeltaKg: m.deltaKg,
      days: m.days,
      loggedDays: n,
      weighInsInWindow: weighInsInWindow,
      windowStart: windowStart,
      windowEnd: windowEnd,
      unlimitedMaintenanceKcal: blended,
      previousMaintenanceKcal: prev,
      changeLimited: changeLimited,
      maintenanceKcal: maintenance,
      deficitKcal: deficit,
      floorKcal: floor,
      floorApplied: floorApplied,
      maintenanceMode: maintenanceMode,
    ),
  );
}
