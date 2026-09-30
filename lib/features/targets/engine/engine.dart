/// Calorie & macro engine (docs/engine.md). Pure Dart: no Flutter, no DB.
///
/// Entry point: [recommend].
library;

import 'dart:math' as math;

import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../../../domain/trend.dart';

/// kcal stored in one kg of body weight change, when body composition isn't
/// known (see [kcalPerKgLost] for the body-fat-adjusted value normally used).
const double kKcalPerKg = 7700;

/// Adaptive window length in days (ends yesterday).
const int kWindowDays = 28;

/// Maximum change of maintenance per weekly update when a previous target exists.
const double kMaxMaintenanceChangeKcal = 150;

/// Minimum data needed for a measured maintenance estimate.
const int kMinSpanDays = 14;

/// Days the weight trend must run before the adaptive window starts before
/// its difference is used for the weight change (the lag is < 5% by then);
/// until then a regression through the raw weigh-ins is used.
const kTrendWarmupDays = 30;

/// Minimum fully-logged days in the window for a measured estimate to be
/// attempted at all.
const int kMinLoggedDays = 7;

/// Fully-logged days at which the measured estimate gets full weight in the
/// blend with the formula.
const int kFullLoggedDays = 18;

/// Minimum weigh-ins in the window for a measured estimate to be attempted.
const int kMinWeighIns = 6;

/// Weigh-ins at which the measured estimate gets full weight in the blend.
const int kFullWeighIns = 10;

/// Days excluded from the measurement window right after a diet phase starts
/// (glycogen/water shifts overstate the real change for about two weeks).
const int kPhaseSkipDays = 14;

/// A change of the formula estimate bigger than this (kcal/day) between two
/// check-ins counts as a new diet phase, resetting the [kPhaseSkipDays] skip.
const double kPhaseChangeThresholdKcal = 300;

/// Week-to-week drift variance (kcal²) added to the Kalman prior before each
/// update — how much the true maintenance is expected to wander on its own.
const double kProcessNoiseVarianceKcal2 = 50 * 50;

/// Fallback measurement variance (kcal²) when a proper standard error can't
/// be computed (e.g. the trend-difference method, which has no residuals).
/// SD ~130 kcal/day, the rough midpoint of the warmed-up trend-diff noise
/// found while fixing the early-weeks bias (see docs/engine.md).
const double kDefaultMeasurementVarianceKcal2 = 130 * 130;

/// Highest daily deficit below maintenance, regardless of weekly rate.
const double kMaxDeficitKcal = 750;

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

  /// Desired loss per week as % of body weight (0.25–1.0), before the
  /// body-fat-based cap in [maxWeeklyRatePct].
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
    this.previousPhaseStartDayKey,
    this.previousWeeklyRatePctRaw,
    this.previousFormulaKcal,
    this.previousMaintenanceMode,
    this.previousSmoothedMeasuredKcal,
    this.previousMeasuredVarianceKcal2,
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

  /// Day the current diet phase started, from the previous target's
  /// explanation (null for the first one, or if that explanation couldn't be
  /// read — either way a new phase starts today).
  final String? previousPhaseStartDayKey;

  /// The profile's weekly rate as of the previous target, before any
  /// body-fat cap. Used to detect a user-driven rate change (a new phase).
  final double? previousWeeklyRatePctRaw;

  /// Formula maintenance as of the previous target. Used to detect a big
  /// weight-driven change (a new phase).
  final double? previousFormulaKcal;

  /// Whether the previous target was in maintenance mode. Used to detect a
  /// diet pause/resume (a new phase).
  final bool? previousMaintenanceMode;

  /// The Kalman-smoothed measured maintenance carried from the previous
  /// target (null for the first one, or after a gap with no measurement).
  final double? previousSmoothedMeasuredKcal;

  /// Variance (kcal²) behind [previousSmoothedMeasuredKcal].
  final double? previousMeasuredVarianceKcal2;
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
    required this.measurementStart,
    required this.phaseStartDayKey,
    required this.bodyFatPercent,
    required this.kcalPerKgUsed,
    required this.weeklyRatePctRaw,
    required this.rateCapped,
    required this.smoothedMeasuredKcal,
    required this.measuredVarianceKcal2,
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

  /// This week's measured maintenance (after Kalman smoothing and clamping),
  /// or null when data was insufficient this week.
  final double? measuredKcal;

  /// True when the raw measured value was outside [0.6, 1.6] × formula.
  final bool measuredClamped;

  /// Why [measuredKcal] is null (plain English), else null.
  final String? measuredMissingReason;

  /// Weight of the measured estimate in the blend (0–1).
  final double weight;
  final double? avgIntakeKcal;
  final double? trendDeltaKg;

  /// Days the weight change was measured over.
  final int? days;

  /// Fully-logged days in the measurement window (n).
  final int loggedDays;
  final int weighInsInWindow;

  /// First and last day keys of the nominal adaptive window (inclusive).
  final String windowStart;
  final String windowEnd;

  /// First day key actually used for measurement, after skipping
  /// [kPhaseSkipDays] days from [phaseStartDayKey] (>= windowStart).
  final String measurementStart;

  /// Day the current diet phase started (a rate change, a maintenance
  /// pause/resume, or a big weight-driven change in the formula estimate).
  /// Always set by [recommend]; null only when decoded from an older saved
  /// target that didn't record it (read as "no signal", not a phase start).
  final String? phaseStartDayKey;

  /// Estimated body fat % (Deurenberg), used for [kcalPerKgUsed] and the
  /// rate cap.
  final double bodyFatPercent;

  /// kcal per kg of body-mass change used this time, from estimated body
  /// composition (falls back to the flat [kKcalPerKg]).
  final double kcalPerKgUsed;

  /// The profile's weekly rate before the body-fat cap. Always set by
  /// [recommend]; null only when decoded from an older saved target that
  /// didn't record it (so it can't look like a rate change).
  final double? weeklyRatePctRaw;

  /// True when [weeklyRatePctRaw] was reduced by the body-fat-based cap.
  final bool rateCapped;

  /// The Kalman-smoothed measured maintenance, carried to the next check-in
  /// even when [measuredKcal] is null this week (a stale prior beats none).
  final double? smoothedMeasuredKcal;

  /// Variance (kcal²) behind [smoothedMeasuredKcal].
  final double? measuredVarianceKcal2;

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

  /// True when trend weight is at or below goal, so target = maintenance
  /// (still held at [floorKcal] or above).
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
    'measurementStart': measurementStart,
    'phaseStartDayKey': phaseStartDayKey,
    'bodyFatPercent': bodyFatPercent,
    'kcalPerKgUsed': kcalPerKgUsed,
    'weeklyRatePctRaw': weeklyRatePctRaw,
    'rateCapped': rateCapped,
    'smoothedMeasuredKcal': smoothedMeasuredKcal,
    'measuredVarianceKcal2': measuredVarianceKcal2,
    'unlimitedMaintenanceKcal': unlimitedMaintenanceKcal,
    'previousMaintenanceKcal': previousMaintenanceKcal,
    'changeLimited': changeLimited,
    'maintenanceKcal': maintenanceKcal,
    'deficitKcal': deficitKcal,
    'floorKcal': floorKcal,
    'floorApplied': floorApplied,
    'maintenanceMode': maintenanceMode,
  };

  /// Inverse of [toJson]. Missing bool fields default to false, and fields
  /// added after the first release default to null/unknown so old rows
  /// still decode. The fields fed back into the next check-in
  /// ([phaseStartDayKey], [weeklyRatePctRaw]) stay null when missing, so no
  /// data reads as no signal rather than as a made-up value. Throws on JSON that isn't an explanation (e.g. the
  /// `{'skipped': true}` marker).
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
      measurementStart:
          j['measurementStart'] as String? ?? j['windowStart'] as String,
      phaseStartDayKey: j['phaseStartDayKey'] as String?,
      bodyFatPercent: nd('bodyFatPercent') ?? 20,
      kcalPerKgUsed: nd('kcalPerKgUsed') ?? kKcalPerKg,
      weeklyRatePctRaw: nd('weeklyRatePctRaw'),
      rateCapped: j['rateCapped'] as bool? ?? false,
      smoothedMeasuredKcal: nd('smoothedMeasuredKcal'),
      measuredVarianceKcal2: nd('measuredVarianceKcal2'),
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

/// Deurenberg body-fat % estimate from BMI, age and sex. Callers should
/// clamp the result to a plausible range before using it — the formula can
/// go outside one at extreme inputs.
double deurenbergBodyFatPercent({
  required double bmi,
  required int ageYears,
  required Sex sex,
}) => 1.20 * bmi + 0.23 * ageYears - (sex == Sex.male ? 10.8 : 0) - 5.4;

/// Energy per kg of body-mass change, given [fatMassKg] of estimated fat
/// mass: a smaller fat reserve means more of any given loss is lean tissue,
/// which stores less energy per kg than fat. Uses Hall's energy densities
/// (9,440 kcal/kg fat, 1,816 kcal/kg lean) and Forbes's lean/fat partition
/// (ΔLean/ΔFat ≈ 10.4 / fat mass in kg). Falls back to the flat
/// [kKcalPerKg] when fat mass is unknown.
double kcalPerKgLost(double? fatMassKg) {
  if (fatMassKg == null || fatMassKg <= 0) return kKcalPerKg;
  final fatFraction = fatMassKg / (fatMassKg + 10.4);
  return fatFraction * 9440 + (1 - fatFraction) * 1816;
}

/// Highest selectable weekly loss rate (% body weight) for someone with
/// [bmi] / [bodyFatPercent]: more stored fat tolerates faster loss without
/// as much lean-mass cost.
double maxWeeklyRatePct({required double bmi, required double bodyFatPercent}) {
  if (bmi >= 30 || bodyFatPercent >= 30) return 1.0;
  if (bmi >= 25 || bodyFatPercent >= 20) return 0.75;
  return 0.5;
}

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
    this.varianceKcal2,
  });
  final double? value;
  final bool clamped;
  final String? reason;
  final double? avgIntake;
  final double? deltaKg;
  final int? days;

  /// Variance (kcal²) behind [value], for the Kalman weighting in Fix 3.
  final double? varianceKcal2;
}

/// Least-squares slope (kg per day) through [points] of (day, kg). Needs at
/// least two distinct days.
double weightSlopeKgPerDay(List<(double, double)> points) {
  final n = points.length;
  final meanX = points.map((p) => p.$1).reduce((a, b) => a + b) / n;
  final meanY = points.map((p) => p.$2).reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0;
  for (final (x, y) in points) {
    sxy += (x - meanX) * (y - meanY);
    sxx += (x - meanX) * (x - meanX);
  }
  return sxx == 0 ? 0 : sxy / sxx;
}

/// Standard error (kg/day) of a least-squares [slope] through [points], from
/// the residuals around that slope. Null when there are too few points (< 3)
/// or they're all on the same day, and residual variance can't be estimated.
double? weightSlopeStdErrKgPerDay(List<(double, double)> points, double slope) {
  final n = points.length;
  if (n < 3) return null;
  final meanX = points.map((p) => p.$1).reduce((a, b) => a + b) / n;
  final meanY = points.map((p) => p.$2).reduce((a, b) => a + b) / n;
  var sxx = 0.0, sse = 0.0;
  for (final (x, y) in points) {
    sxx += (x - meanX) * (x - meanX);
    final predicted = meanY + slope * (x - meanX);
    final resid = y - predicted;
    sse += resid * resid;
  }
  if (sxx == 0) return null;
  final residualVariance = sse / (n - 2);
  return math.sqrt(residualVariance / sxx);
}

/// The later of two day keys (string order matches calendar order for
/// `YYYY-MM-DD`).
String _laterDay(String a, String b) => a.compareTo(b) >= 0 ? a : b;

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

  // 2. Body composition (Fix 4/5): estimated once from current trend
  // weight/height/age/sex, used for the energy density below and the rate
  // cap.
  final bmi = trendKg / math.pow(p.heightCm / 100, 2);
  final bodyFatPercent = deurenbergBodyFatPercent(
    bmi: bmi,
    ageYears: age,
    sex: p.sex,
  ).clamp(5.0, 50.0);
  final fatMassKg = bodyFatPercent / 100 * trendKg;
  final kcalPerKgUsed = kcalPerKgLost(fatMassKg);
  final maxRatePct = maxWeeklyRatePct(bmi: bmi, bodyFatPercent: bodyFatPercent);

  final maintenanceMode = trendKg <= p.goalWeightKg;

  // 3. Diet phase (Fix 1): a new phase starts today when the rate changed,
  // maintenance mode was entered/left, or the formula moved a lot since the
  // last target; otherwise it continues from the previous target. With no
  // previous target to compare against (the very first recommendation, or
  // one whose explanation couldn't be read), there's no signal that a phase
  // just changed, so nothing is skipped — this also covers someone who had
  // real weigh-ins and logs before ever opening this feature, where treating
  // that history as a fresh diet start would be wrong.
  final newPhase =
      (input.previousWeeklyRatePctRaw != null &&
          (input.previousWeeklyRatePctRaw! - p.weeklyRatePct).abs() > 0.01) ||
      (input.previousFormulaKcal != null &&
          (formula - input.previousFormulaKcal!).abs() >
              kPhaseChangeThresholdKcal) ||
      (input.previousMaintenanceMode != null &&
          input.previousMaintenanceMode != maintenanceMode);
  // The "no signal" default must make the skip below a no-op (not skip the
  // first 14 days of the window itself), so it sits [kPhaseSkipDays] before
  // windowStart rather than at windowStart.
  final phaseStartDayKey = newPhase
      ? today
      : (input.previousPhaseStartDayKey ??
            addDays(windowStart, -kPhaseSkipDays));
  final measurementStart = _laterDay(
    windowStart,
    addDays(phaseStartDayKey, kPhaseSkipDays),
  );

  // 4. Measured, over [measurementStart]..[windowEnd] (Fix 1 + Fix 2).
  final loggedKcal = <double>[];
  for (
    var d = measurementStart;
    d.compareTo(windowEnd) <= 0;
    d = addDays(d, 1)
  ) {
    final log = input.intake[d];
    if (log != null && log.fullyLogged) loggedKcal.add(log.kcal);
  }
  final n = loggedKcal.length;
  final weighInsInWindow = weighIns.keys
      .where(
        (k) =>
            k.compareTo(measurementStart) >= 0 && k.compareTo(windowEnd) <= 0,
      )
      .length;

  _Measured measure() {
    if (measurementStart.compareTo(windowEnd) > 0) {
      final needed = daysBetween(windowEnd, measurementStart);
      return _Measured(
        reason:
            'still settling in after a diet change ($needed more day'
            '${needed == 1 ? '' : 's'} to go)',
      );
    }
    // The smoothed trend lags ~10 days behind a steady loss and needs about a
    // month to catch up, so in the first weeks a trend difference makes the
    // measured maintenance far too low. Until the trend has run for
    // [kTrendWarmupDays] before the measurement window, the weight change is
    // the least-squares slope through the raw weigh-ins (unbiased, a bit
    // noisier); after that, the trend difference (unbiased by then and
    // steadier — see docs/engine.md).
    final firstWeighIn = weighIns.keys.reduce(
      (a, b) => a.compareTo(b) < 0 ? a : b,
    );
    final useTrend =
        daysBetween(firstWeighIn, measurementStart) >= kTrendWarmupDays;

    final double kgPerDay;
    final int span;
    double? varianceKcal2;
    if (useTrend) {
      if (!trendByDay.containsKey(measurementStart) ||
          !trendByDay.containsKey(windowEnd)) {
        return _Measured(reason: 'no weigh-ins in the last $kWindowDays days');
      }
      span = daysBetween(measurementStart, windowEnd);
      kgPerDay =
          (trendByDay[windowEnd]! - trendByDay[measurementStart]!) / span;
      varianceKcal2 = kDefaultMeasurementVarianceKcal2;
    } else {
      final points = [
        for (final e in weighIns.entries)
          if (e.key.compareTo(measurementStart) >= 0 &&
              e.key.compareTo(windowEnd) <= 0)
            (daysBetween(measurementStart, e.key).toDouble(), e.value),
      ];
      if (points.isEmpty) {
        return _Measured(reason: 'no weigh-ins in the last $kWindowDays days');
      }
      final xs = points.map((p) => p.$1);
      span = (xs.reduce(math.max) - xs.reduce(math.min)).round();
      if (span < kMinSpanDays) {
        return _Measured(
          reason: 'weigh-ins cover only $span days (need $kMinSpanDays)',
        );
      }
      kgPerDay = weightSlopeKgPerDay(points);
      final se = weightSlopeStdErrKgPerDay(points, kgPerDay);
      varianceKcal2 = se == null
          ? kDefaultMeasurementVarianceKcal2
          : math.pow(se * kcalPerKgUsed, 2).toDouble();
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
    final raw = avgIntake - kgPerDay * kcalPerKgUsed;
    final lo = 0.6 * formula, hi = 1.6 * formula;
    final value = raw.clamp(lo, hi).toDouble();
    return _Measured(
      value: value,
      clamped: value != raw,
      avgIntake: avgIntake,
      deltaKg: kgPerDay * span,
      days: span,
      varianceKcal2: varianceKcal2,
    );
  }

  final m = measure();

  // 5. Noise-weighted update (Fix 3): a 1-variable Kalman filter smooths
  // this week's measured value against the last accepted one, so a noisy
  // week counts for less than a clean one. Carried forward even on a week
  // with no fresh measurement, so a later one still has a real prior.
  double? smoothedMeasuredKcal;
  double? measuredVarianceKcal2;
  if (m.value != null) {
    if (input.previousSmoothedMeasuredKcal == null) {
      smoothedMeasuredKcal = m.value;
      measuredVarianceKcal2 =
          m.varianceKcal2 ?? kDefaultMeasurementVarianceKcal2;
    } else {
      final priorVar =
          (input.previousMeasuredVarianceKcal2 ??
              kDefaultMeasurementVarianceKcal2) +
          kProcessNoiseVarianceKcal2;
      final measVar = m.varianceKcal2 ?? kDefaultMeasurementVarianceKcal2;
      final k = priorVar / (priorVar + measVar);
      smoothedMeasuredKcal =
          (input.previousSmoothedMeasuredKcal! +
                  k * (m.value! - input.previousSmoothedMeasuredKcal!))
              .clamp(0.6 * formula, 1.6 * formula);
      measuredVarianceKcal2 = (1 - k) * priorVar;
    }
  } else {
    // No fresh measurement: carry the old smoothed value/variance forward
    // (growing), so a resumed later measurement still blends against a real
    // prior instead of starting cold.
    smoothedMeasuredKcal = input.previousSmoothedMeasuredKcal;
    measuredVarianceKcal2 = input.previousMeasuredVarianceKcal2 == null
        ? null
        : input.previousMeasuredVarianceKcal2! + kProcessNoiseVarianceKcal2;
  }
  // Publicly reported "this week's measured value" stays null exactly when
  // there was no fresh measurement, regardless of the carried-forward state.
  final measuredKcalForReport = m.value == null ? null : smoothedMeasuredKcal;

  // 6. Blend, scaled by how much of the window is covered (Fix 2).
  final loggedWeight =
      ((n - kMinLoggedDays) / (kFullLoggedDays - kMinLoggedDays)).clamp(
        0.0,
        1.0,
      );
  final weighInsWeight =
      ((weighInsInWindow - kMinWeighIns) / (kFullWeighIns - kMinWeighIns))
          .clamp(0.0, 1.0);
  final w = measuredKcalForReport == null
      ? 0.0
      : math.min(loggedWeight, weighInsWeight);
  final blended = (1 - w) * formula + w * (measuredKcalForReport ?? 0);
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

  // 7. Target (Fix 5: rate capped by body fat, deficit capped at 750 kcal).
  final floor = math.max(bmr, p.sex == Sex.male ? 1500.0 : 1200.0);
  final effectiveRatePct = math.min(p.weeklyRatePct, maxRatePct);
  final rateCapped = effectiveRatePct < p.weeklyRatePct;
  var deficit = 0.0;
  var floorApplied = false;
  double target;
  if (maintenanceMode) {
    target = maintenance;
  } else {
    deficit = effectiveRatePct / 100 * trendKg * kcalPerKgUsed / 7;
    deficit = math.min(deficit, math.min(0.25 * maintenance, kMaxDeficitKcal));
    target = maintenance - deficit;
  }
  // The floor applies in maintenance mode too (a deliberate safety departure
  // from the original spec): a maintenance estimate dragged down by
  // under-logging must not produce an implausibly low target. When the
  // maintenance itself is below the floor, both modes give the floor.
  if (target < floor) {
    target = floor;
    floorApplied = true;
  }
  target = roundTo(target, 10);

  // 8. Macros.
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
      measuredKcal: measuredKcalForReport,
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
      measurementStart: measurementStart,
      phaseStartDayKey: phaseStartDayKey,
      bodyFatPercent: bodyFatPercent,
      kcalPerKgUsed: kcalPerKgUsed,
      weeklyRatePctRaw: p.weeklyRatePct,
      rateCapped: rateCapped,
      smoothedMeasuredKcal: smoothedMeasuredKcal,
      measuredVarianceKcal2: measuredVarianceKcal2,
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
