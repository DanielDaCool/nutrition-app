import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/engine/engine.dart';
import 'package:nutrition_app/features/targets/engine/explain.dart';

const today = '2026-09-25';

EngineProfile profile({
  Sex sex = Sex.male,
  DateTime? birthDate,
  double heightCm = 180,
  ActivityLevel activity = ActivityLevel.moderate,
  double goalWeightKg = 80,
  double weeklyRatePct = 0.5,
  double proteinPerKg = 2.0,
}) => EngineProfile(
  sex: sex,
  birthDate: birthDate ?? DateTime(1996, 9, 25),
  heightCm: heightCm,
  activityLevel: activity,
  goalWeightKg: goalWeightKg,
  weeklyRatePct: weeklyRatePct,
  proteinPerKg: proteinPerKg,
);

/// kcal per kg the engine will use for the default test profile (male, 30 y,
/// 180 cm) around 90 kg, from the same body-fat estimate `recommend()` uses.
/// Synthetic histories below convert intake/maintenance gaps to kg/day with
/// this, so they stay internally consistent with what the engine recovers
/// (the flat 7,700 rule no longer applies once body fat is estimated).
double _testKcalPerKg({double kg = 90, int ageYears = 30, Sex sex = Sex.male}) {
  final bmi = kg / pow(1.80, 2);
  final bodyFat = deurenbergBodyFatPercent(
    bmi: bmi,
    ageYears: ageYears,
    sex: sex,
  ).clamp(5.0, 50.0);
  return kcalPerKgLost(bodyFat / 100 * kg);
}

final testKcalPerKg = _testKcalPerKg();

/// Synthetic history: the person eats [intakeKcal] every day and has a true
/// maintenance of [maintenanceKcal], so the scale moves by
/// (intake - maintenance) / [kcalPerKg] kg per day, plus uniform noise of
/// ±[noiseKg]. Covers the [historyDays] days before today (today itself has
/// no data). [logged]/[weighed] take the day key, not an index, so windows
/// can be picked out directly with [addDays].
({Map<String, double> weighIns, Map<String, DayLog> intake}) history({
  required double maintenanceKcal,
  required double intakeKcal,
  double startKg = 90,
  int historyDays = 60,
  double noiseKg = 0,
  int seed = 1,
  double? kcalPerKg,
  bool Function(String day)? logged,
  bool Function(String day)? weighed,
}) {
  final rnd = Random(seed);
  final perDayKg =
      (intakeKcal - maintenanceKcal) / (kcalPerKg ?? testKcalPerKg);
  final weighIns = <String, double>{};
  final intake = <String, DayLog>{};
  for (var i = 0; i < historyDays; i++) {
    final day = addDays(today, -historyDays + i);
    final trueKg = startKg + perDayKg * i;
    final noise = noiseKg == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * noiseKg;
    if (weighed?.call(day) ?? true) weighIns[day] = trueKg + noise;
    intake[day] = DayLog(
      kcal: intakeKcal,
      fullyLogged: logged?.call(day) ?? true,
    );
  }
  return (weighIns: weighIns, intake: intake);
}

void main() {
  group('formula', () {
    test('formula-only recommendation matches the formulas directly', () {
      // Male, 30 years (born 1996-09-25, today 2026-09-25), 180 cm, one
      // weigh-in of 90 kg -> trend 90 kg.
      // BMR = 10*90 + 6.25*180 - 5*30 + 5 = 900 + 1125 - 150 + 5 = 1880
      // formula = 1880 * 1.55 (moderate) = 2914
      final bmi = 90 / pow(1.8, 2);
      final bodyFat = deurenbergBodyFatPercent(
        bmi: bmi,
        ageYears: 30,
        sex: Sex.male,
      ).clamp(5.0, 50.0);
      final kcalPerKg = kcalPerKgLost(bodyFat / 100 * 90);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: {today: 90},
          intake: const {},
        ),
      );
      final e = r.explanation;
      expect(e.ageYears, 30);
      expect(e.bmrKcal, closeTo(1880, 1e-9));
      expect(e.formulaKcal, closeTo(2914, 1e-9));
      expect(r.maintenanceKcal, closeTo(2914, 1e-9));
      expect(r.method, TargetMethod.formula);
      expect(e.bodyFatPercent, closeTo(bodyFat, 1e-9));
      expect(e.kcalPerKgUsed, closeTo(kcalPerKg, 1e-9));
      expect(e.rateCapped, isFalse); // 0.5%/week is under any body-fat cap.
      final expectedDeficit = 0.5 / 100 * 90 * kcalPerKg / 7;
      expect(e.deficitKcal, closeTo(expectedDeficit, 1e-6));
      final expectedTarget = roundTo(2914 - expectedDeficit, 10);
      expect(r.macros.kcal, expectedTarget);
      final m = computeMacros(
        targetKcal: expectedTarget,
        trendKg: 90,
        goalWeightKg: 80,
        proteinPerKg: 2.0,
      );
      expect(r.macros.proteinG, m.proteinG);
      expect(r.macros.fatG, m.fatG);
      expect(r.macros.carbsG, m.carbsG);
      expect(e.floorApplied, isFalse);
      expect(e.maintenanceMode, isFalse);
      // No previous target to compare against -> no phase skip is applied.
      expect(e.phaseStartDayKey, addDays(today, -kWindowDays - kPhaseSkipDays));
    });

    test('age counts whole years only', () {
      expect(ageOn(DateTime(1996, 9, 26), today), 29);
      expect(ageOn(DateTime(1996, 9, 25), today), 30);
    });

    test('needs a weigh-in', () {
      expect(
        () => recommend(
          EngineInput(
            today: today,
            profile: profile(),
            weighIns: const {},
            intake: const {},
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('body composition', () {
    test('deurenbergBodyFatPercent: more BMI and age raise the estimate', () {
      final lean = deurenbergBodyFatPercent(
        bmi: 22,
        ageYears: 25,
        sex: Sex.male,
      );
      final higher = deurenbergBodyFatPercent(
        bmi: 30,
        ageYears: 50,
        sex: Sex.male,
      );
      expect(higher, greaterThan(lean));
      // Same BMI/age, women read higher (no -10.8 male term).
      final female = deurenbergBodyFatPercent(
        bmi: 22,
        ageYears: 25,
        sex: Sex.female,
      );
      expect(female, greaterThan(lean));
    });

    test('kcalPerKgLost: less fat mass means less energy per kg lost', () {
      final lean = kcalPerKgLost(10);
      final fat = kcalPerKgLost(30);
      expect(lean, lessThan(fat));
      expect(lean, lessThan(kKcalPerKg)); // both below the flat 7,700 rule
      expect(fat, lessThan(kKcalPerKg));
      expect(kcalPerKgLost(null), kKcalPerKg); // unknown -> flat fallback
      expect(kcalPerKgLost(0), kKcalPerKg);
    });

    test('maxWeeklyRatePct: more stored fat allows a faster rate', () {
      expect(maxWeeklyRatePct(bmi: 22, bodyFatPercent: 15), 0.5);
      expect(maxWeeklyRatePct(bmi: 26, bodyFatPercent: 22), 0.75);
      expect(maxWeeklyRatePct(bmi: 32, bodyFatPercent: 22), 1.0);
      expect(maxWeeklyRatePct(bmi: 22, bodyFatPercent: 32), 1.0);
    });

    test('a lean profile has its requested rate capped', () {
      // 25 y, 180 cm, 65 kg male: BMI ~20, low body fat -> capped to 0.5%.
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(
            heightCm: 180,
            birthDate: DateTime(2001, 9, 25),
            goalWeightKg: 60,
            weeklyRatePct: 1.0,
          ),
          weighIns: {today: 65},
          intake: const {},
        ),
      );
      expect(r.explanation.rateCapped, isTrue);
      expect(r.explanation.weeklyRatePctRaw, 1.0);
      // deficit uses the capped 0.5%, not the requested 1.0%.
      final capped = maxWeeklyRatePct(
        bmi: 65 / pow(1.8, 2),
        bodyFatPercent: r.explanation.bodyFatPercent,
      );
      expect(
        r.explanation.deficitKcal,
        closeTo(capped / 100 * 65 * r.explanation.kcalPerKgUsed / 7, 1e-6),
      );
    });
  });

  group('adaptive maintenance', () {
    test('no lag in the first weeks: 28 days of data measure the real '
        'maintenance', () {
      // True maintenance 2500, eating 1950 -> losing weight from day one. A
      // smoothed trend that starts at the first weigh-in hasn't caught up
      // with that slope after only 4 weeks, so the raw-weigh-in regression
      // is used instead (see docs/engine.md).
      for (final noise in [0.0, 0.4]) {
        final h = history(
          maintenanceKcal: 2500,
          intakeKcal: 1950,
          historyDays: kWindowDays,
          noiseKg: noise,
        );
        final r = recommend(
          EngineInput(
            today: today,
            profile: profile(),
            weighIns: h.weighIns,
            intake: h.intake,
          ),
        );
        final measured = r.explanation.measuredKcal!;
        // Even without noise, kcal/kg is re-estimated from the trend weight
        // at the end of the window, which has moved a little from the 90 kg
        // the synthetic history was generated at — a few kcal of drift, not
        // the ~200+ kcal/day bias this test guards against.
        expect(
          measured,
          closeTo(2500, noise == 0 ? 10 : 150),
          reason: 'noise $noise',
        );
      }
    });

    test('steady loss at known intake recovers maintenance (±50 kcal)', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final e = r.explanation;
      expect(e.loggedDays, kWindowDays);
      expect(e.weight, 1);
      expect(r.method, TargetMethod.adaptive);
      expect(e.avgIntakeKcal, 2000);
      expect(e.days, kWindowDays - 1);
      expect(e.measuredKcal, closeTo(2500, 50));
      expect(r.maintenanceKcal, closeTo(2500, 50));
    });

    test('steady gain is recovered too', () {
      final h = history(maintenanceKcal: 2300, intakeKcal: 2700);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.maintenanceKcal, closeTo(2300, 50));
    });

    test('noisy weights (±1 kg, fixed seed) stay within ±150 kcal', () {
      for (final seed in [7, 42, 2026]) {
        final h = history(
          maintenanceKcal: 2500,
          intakeKcal: 2000,
          noiseKg: 1,
          seed: seed,
        );
        final r = recommend(
          EngineInput(
            today: today,
            profile: profile(),
            weighIns: h.weighIns,
            intake: h.intake,
          ),
        );
        expect(r.maintenanceKcal, closeTo(2500, 150), reason: 'seed $seed');
      }
    });

    test('blends by number of logged days', () {
      // Log only the last 12 of the 28 window days:
      // loggedWeight = (12-7)/(18-7) = 5/11; weigh-ins stay full (28) so
      // weighInsWeight clamps to 1 and doesn't bind.
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -12)) >= 0,
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final e = r.explanation;
      expect(e.loggedDays, 12);
      const w = 5 / 11;
      expect(e.weight, closeTo(w, 1e-9));
      expect(r.method, TargetMethod.blended);
      expect(
        r.maintenanceKcal,
        closeTo((1 - w) * e.formulaKcal + w * e.measuredKcal!, 1e-6),
      );
    });

    test('shortened span when weigh-ins start inside the window', () {
      // 15 days of history: the regression's raw-weigh-in points span
      // 27 - 13 = 14 days (>= kMinSpanDays).
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        historyDays: 15,
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.days, 14);
      expect(r.explanation.measuredKcal, isNotNull);
      expect(r.explanation.loggedDays, 15);
    });

    test('measured value is clamped to 0.6–1.6 × formula', () {
      // Flat weight (maintenance == intake) but logging only 500 kcal/day:
      // way under what the flat trend implies, so it gets clamped.
      final h = history(maintenanceKcal: 500, intakeKcal: 500);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final e = r.explanation;
      expect(e.measuredClamped, isTrue);
      expect(e.measuredKcal, closeTo(0.6 * e.formulaKcal, 1e-6));
    });
  });

  group('diet phase', () {
    test('a rate change starts a new phase and skips 14 days', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final first = recommend(
        EngineInput(
          today: today,
          profile: profile(weeklyRatePct: 0.5),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(
        first.explanation.phaseStartDayKey,
        addDays(today, -kWindowDays - kPhaseSkipDays),
      );

      // Same data, but the rate changed since the last target: the phase
      // resets to today, so the (still-unlogged) next 14 days aren't
      // measurable yet.
      final changed = recommend(
        EngineInput(
          today: today,
          profile: profile(weeklyRatePct: 0.8),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: first.maintenanceKcal,
          previousPhaseStartDayKey: first.explanation.phaseStartDayKey,
          previousWeeklyRatePctRaw: 0.5,
          previousFormulaKcal: first.explanation.formulaKcal,
          previousMaintenanceMode: first.explanation.maintenanceMode,
        ),
      );
      expect(changed.explanation.phaseStartDayKey, today);
      expect(changed.explanation.measuredKcal, isNull);
      expect(
        changed.explanation.measuredMissingReason,
        contains('settling in'),
      );
      expect(changed.method, TargetMethod.formula);
    });

    test('an unchanged rate keeps the phase and measures normally', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(weeklyRatePct: 0.5),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 2500,
          previousPhaseStartDayKey: addDays(today, -40),
          previousWeeklyRatePctRaw: 0.5,
          previousFormulaKcal: 2914,
          previousMaintenanceMode: false,
        ),
      );
      expect(r.explanation.phaseStartDayKey, addDays(today, -40));
      expect(r.explanation.measuredKcal, isNotNull);
    });
  });

  group('too little data -> formula', () {
    EngineInput input(
      ({Map<String, double> weighIns, Map<String, DayLog> intake}) h,
    ) => EngineInput(
      today: today,
      profile: profile(),
      weighIns: h.weighIns,
      intake: h.intake,
    );

    test('fewer than 7 fully logged days', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -6)) >= 0, // 6 days
      );
      final r = recommend(input(h));
      expect(r.explanation.loggedDays, 6);
      expect(r.explanation.measuredKcal, isNull);
      expect(r.method, TargetMethod.formula);
      expect(r.maintenanceKcal, r.explanation.formulaKcal);
    });

    test('fewer than 6 weigh-ins in the window', () {
      final recentWeighed = {
        for (final d in [27, 20, 15, 10, 5]) addDays(today, -d),
      };
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        weighed: (day) =>
            day.compareTo(addDays(today, -kWindowDays)) < 0 ||
            recentWeighed.contains(day),
      );
      final r = recommend(input(h));
      expect(r.explanation.weighInsInWindow, lessThan(6));
      expect(r.method, TargetMethod.formula);
      expect(r.explanation.measuredMissingReason, contains('weigh-ins'));
    });

    test('span shorter than 14 days', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        historyDays: 13,
      );
      final r = recommend(input(h));
      expect(r.method, TargetMethod.formula);
      expect(r.explanation.measuredMissingReason, contains('days'));
    });

    test('exactly 7 logged days -> measured exists but w = 0', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -7)) >= 0,
      );
      final r = recommend(input(h));
      expect(r.explanation.measuredKcal, isNotNull);
      expect(r.explanation.weight, 0);
      expect(r.method, TargetMethod.formula);
    });
  });

  group('target', () {
    test('goal reached -> maintenance mode', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(goalWeightKg: 90),
          weighIns: {today: 89},
          intake: const {},
        ),
      );
      expect(r.explanation.maintenanceMode, isTrue);
      expect(r.explanation.deficitKcal, 0);
      expect(r.macros.kcal, roundTo(r.maintenanceKcal, 10));
    });

    test('floor applies', () {
      // Female, 50 y, 155 cm, 60 kg, sedentary, 1 %/week (her body fat
      // estimate is high enough that 1% isn't capped):
      // BMR = 600 + 968.75 - 250 - 161 = 1157.75; formula = 1389.3
      // deficit = min(raw, 25% of maintenance, 750) = 0.25*1389.3 = 347.325
      // 1389.3 - 347.325 = 1041.975 < floor max(1157.75, 1200) = 1200.
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(
            sex: Sex.female,
            birthDate: DateTime(1976, 1, 1),
            heightCm: 155,
            activity: ActivityLevel.sedentary,
            goalWeightKg: 52,
            weeklyRatePct: 1.0,
          ),
          weighIns: {today: 60},
          intake: const {},
        ),
      );
      expect(r.explanation.bmrKcal, closeTo(1157.75, 1e-9));
      expect(r.explanation.rateCapped, isFalse);
      expect(r.explanation.deficitKcal, closeTo(0.25 * 1157.75 * 1.2, 1e-6));
      expect(r.explanation.floorApplied, isTrue);
      expect(r.macros.kcal, 1200);
    });

    test('floor applies in maintenance mode too', () {
      // Female, 50 y, 155 cm, at goal (52 kg), sedentary: formula
      // maintenance ~1,290, BMR ~1,075, floor 1,200. Heavy under-logging
      // (intake 700 with a stable weight) drags measured maintenance to the
      // 0.6 x formula clamp (~775).
      final p = profile(
        sex: Sex.female,
        birthDate: DateTime(1976, 1, 1),
        heightCm: 155,
        activity: ActivityLevel.sedentary,
        goalWeightKg: 52,
      );
      final h = history(maintenanceKcal: 700, intakeKcal: 700, startKg: 52);
      final r = recommend(
        EngineInput(
          today: today,
          profile: p,
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.maintenanceMode, isTrue);
      expect(r.maintenanceKcal, lessThan(1000));
      expect(r.explanation.floorApplied, isTrue);
      expect(r.macros.kcal, 1200);
      expect(
        explainLines(r.explanation).join(' '),
        contains('held at the minimum of 1,200 kcal'),
      );
    });

    test('maintenance mode above the floor is not floored', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(goalWeightKg: 90),
          weighIns: {today: 89},
          intake: const {},
        ),
      );
      expect(r.explanation.floorApplied, isFalse);
      expect(r.macros.kcal, roundTo(r.maintenanceKcal, 10));
    });

    test('deficit capped at 750 kcal', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(
            activity: ActivityLevel.active,
            weeklyRatePct: 1.0,
            goalWeightKg: 100,
          ),
          weighIns: {today: 160},
          intake: const {},
        ),
      );
      // High body weight -> high estimated fat mass -> no rate cap, but the
      // raw rate*kcalPerKg deficit and 25% of maintenance both exceed the
      // flat 750 kcal cap, so that's what binds.
      expect(r.explanation.rateCapped, isFalse);
      expect(r.explanation.deficitKcal, 750);
    });
  });

  group('macros', () {
    test('rounding to 5 g', () {
      // protein 1.8 * min(83.3, 86.25) = 149.94 -> 150
      // fat max(66.64, 55.6) -> 65; carbs (2000 - 600 - 585)/4 = 203.75 -> 205
      final m = computeMacros(
        targetKcal: 2000,
        trendKg: 83.3,
        goalWeightKg: 75,
        proteinPerKg: 1.8,
      );
      expect(m.kcal, 2000);
      expect(m.proteinG, 150);
      expect(m.fatG, 65);
      expect(m.carbsG, 205);
    });

    test('protein uses goal × 1.15 at high body weight', () {
      final m = computeMacros(
        targetKcal: 2400,
        trendKg: 130,
        goalWeightKg: 90,
        proteinPerKg: 2.0,
      );
      expect(m.proteinG, 205); // 2.0 * 103.5 = 207 -> 205
    });

    test('carb floor lowers fat to restore 50 g carbs', () {
      // P = 220 g (880 kcal), fat 80 g -> carbs (1750-880-720)/4 = 37.5 < 50.
      // fat for 50 g carbs = (1750-880-200)/9 = 74.4 -> 70 (>= 0.6*100 = 60)
      // carbs = (1750-880-630)/4 = 60.
      final m = computeMacros(
        targetKcal: 1750,
        trendKg: 100,
        goalWeightKg: 95,
        proteinPerKg: 2.2,
      );
      expect(m.fatG, 70);
      expect(m.carbsG, 60);
      expect(m.carbsG, greaterThanOrEqualTo(50));
    });

    test('fat never below 0.6 g/kg even if carbs stay under 50 g', () {
      // fat for 50 g carbs = (1500-880-200)/9 = 46.7 -> below 60 -> 60.
      // carbs = (1500-880-540)/4 = 20.
      final m = computeMacros(
        targetKcal: 1500,
        trendKg: 100,
        goalWeightKg: 95,
        proteinPerKg: 2.2,
      );
      expect(m.fatG, 60);
      expect(m.carbsG, 20);
    });
  });

  group('±150 kcal change limit', () {
    final h = history(maintenanceKcal: 2500, intakeKcal: 2000);

    test('limits increases', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 2000,
        ),
      );
      expect(r.maintenanceKcal, 2150);
      expect(r.explanation.changeLimited, isTrue);
      expect(r.explanation.unlimitedMaintenanceKcal, closeTo(2500, 50));
    });

    test('limits decreases', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 3000,
        ),
      );
      expect(r.maintenanceKcal, 2850);
      expect(r.explanation.changeLimited, isTrue);
    });

    test('small changes pass through', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 2450,
        ),
      );
      expect(r.explanation.changeLimited, isFalse);
      expect(r.maintenanceKcal, r.explanation.unlimitedMaintenanceKcal);
    });
  });

  group('noise-weighted (Kalman) update', () {
    test('a second measurement blends toward the prior instead of jumping '
        'straight to the new raw reading', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      // A generous prior, as if the last few weeks had settled near 2300
      // with reasonable confidence.
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 2350,
          previousSmoothedMeasuredKcal: 2300,
          previousMeasuredVarianceKcal2: 100 * 100,
        ),
      );
      // This week's raw reading is near 2500; the smoothed figure should
      // land strictly between the 2300 prior and the ~2500 raw reading.
      expect(r.explanation.smoothedMeasuredKcal, greaterThan(2300));
      expect(r.explanation.smoothedMeasuredKcal, lessThan(2520));
      // The ±150 guardrail still applies on top, against the previous
      // maintenance (2350), regardless of the smoothed measured value.
      expect(r.maintenanceKcal, lessThanOrEqualTo(2500));
      expect(r.maintenanceKcal, greaterThanOrEqualTo(2200));
    });

    test('a week with no fresh measurement carries the prior forward', () {
      // Fewer than 7 logged days this week -> no fresh measurement, but the
      // prior should still be visible for the next check-in to build on.
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -3)) >= 0, // 3 days
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: 2450,
          previousSmoothedMeasuredKcal: 2480,
          previousMeasuredVarianceKcal2: 90 * 90,
        ),
      );
      expect(r.explanation.measuredKcal, isNull); // nothing fresh this week
      expect(r.explanation.smoothedMeasuredKcal, 2480); // carried forward
      expect(
        r.explanation.measuredVarianceKcal2,
        greaterThan(90 * 90), // grew by the process noise
      );
      expect(r.method, TargetMethod.formula); // w = 0, doesn't use the prior
    });
  });

  group('simulation (Fix 1-3 combined)', () {
    test('weekly updates settle within ±100 kcal of the true maintenance by '
        'day 28, and no single update moves more than 150 kcal', () {
      const trueMaintenance = 2500.0;
      const trueIntake = 1950.0;
      final kcalPerKg = testKcalPerKg;
      final perDayKg = (trueIntake - trueMaintenance) / kcalPerKg;
      final rnd = Random(123);
      const anchor = '2026-01-01';
      const totalDays = 63;

      final allWeighIns = <String, double>{};
      final allIntake = <String, DayLog>{};
      var trueKg = 90.0;
      for (var d = 0; d < totalDays; d++) {
        final day = addDays(anchor, d);
        trueKg += perDayKg;
        final noise = (rnd.nextDouble() * 2 - 1) * 0.4; // ±0.4 kg noise
        if (rnd.nextDouble() > 0.2) {
          allWeighIns[day] = trueKg + noise; // 20% missed
        }
        final logged = rnd.nextDouble() > 0.1; // 10% missed
        allIntake[day] = DayLog(kcal: trueIntake, fullyLogged: logged);
      }

      double? prevMaintenance;
      String? prevPhaseStart;
      double? prevRateRaw;
      double? prevFormula;
      bool? prevMaintenanceMode;
      double? prevSmoothed;
      double? prevVariance;
      double? maintenanceAtDay28;

      for (var checkDay = 21; checkDay < totalDays; checkDay += 7) {
        final checkToday = addDays(anchor, checkDay);
        final weighIns = {
          for (final e in allWeighIns.entries)
            if (e.key.compareTo(checkToday) <= 0) e.key: e.value,
        };
        final intake = {
          for (final e in allIntake.entries)
            if (e.key.compareTo(checkToday) < 0) e.key: e.value,
        };
        final r = recommend(
          EngineInput(
            today: checkToday,
            profile: profile(),
            weighIns: weighIns,
            intake: intake,
            previousMaintenanceKcal: prevMaintenance,
            previousPhaseStartDayKey: prevPhaseStart,
            previousWeeklyRatePctRaw: prevRateRaw,
            previousFormulaKcal: prevFormula,
            previousMaintenanceMode: prevMaintenanceMode,
            previousSmoothedMeasuredKcal: prevSmoothed,
            previousMeasuredVarianceKcal2: prevVariance,
          ),
        );
        if (prevMaintenance != null) {
          expect(
            (r.maintenanceKcal - prevMaintenance).abs(),
            lessThanOrEqualTo(150.01),
            reason: 'day $checkDay',
          );
        }
        if (checkDay == 28) maintenanceAtDay28 = r.maintenanceKcal;
        prevMaintenance = r.maintenanceKcal;
        prevPhaseStart = r.explanation.phaseStartDayKey;
        prevRateRaw = r.explanation.weeklyRatePctRaw;
        prevFormula = r.explanation.formulaKcal;
        prevMaintenanceMode = r.explanation.maintenanceMode;
        prevSmoothed = r.explanation.smoothedMeasuredKcal;
        prevVariance = r.explanation.measuredVarianceKcal2;
      }

      expect(maintenanceAtDay28, isNotNull);
      expect(maintenanceAtDay28!, closeTo(trueMaintenance, 100));
    });
  });

  group('explanation', () {
    test('JSON round trip', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final json = jsonEncode(r.explanation.toJson());
      final back = Explanation.fromJson(
        jsonDecode(json) as Map<String, Object?>,
      );
      expect(back.toJson(), r.explanation.toJson());
    });

    test('an old row without the new fields still decodes', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final legacyJson = r.explanation.toJson()
        ..remove('phaseStartDayKey')
        ..remove('measurementStart')
        ..remove('bodyFatPercent')
        ..remove('kcalPerKgUsed')
        ..remove('weeklyRatePctRaw')
        ..remove('rateCapped')
        ..remove('smoothedMeasuredKcal')
        ..remove('measuredVarianceKcal2');
      final back = Explanation.fromJson(legacyJson);
      // Missing fields that feed the next check-in read as "no data".
      expect(back.phaseStartDayKey, isNull);
      expect(back.weeklyRatePctRaw, isNull);
      expect(back.smoothedMeasuredKcal, isNull);
    });

    test('a legacy previous target does not fake a new phase', () {
      // 1 %/week profile after a legacy target: a made-up 0.5 default would
      // look like a rate change and skip the first 14 days of the window.
      final h = history(maintenanceKcal: 2500, intakeKcal: 2000);
      final legacy =
          recommend(
              EngineInput(
                today: today,
                profile: profile(),
                weighIns: h.weighIns,
                intake: h.intake,
              ),
            ).explanation.toJson()
            ..remove('phaseStartDayKey')
            ..remove('weeklyRatePctRaw');
      final prev = Explanation.fromJson(legacy);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(weeklyRatePct: 0.75),
          weighIns: h.weighIns,
          intake: h.intake,
          previousMaintenanceKcal: prev.maintenanceKcal,
          previousPhaseStartDayKey: prev.phaseStartDayKey,
          previousWeeklyRatePctRaw: prev.weeklyRatePctRaw,
          previousFormulaKcal: prev.formulaKcal,
          previousMaintenanceMode: prev.maintenanceMode,
        ),
      );
      expect(r.explanation.phaseStartDayKey, isNot(today));
      expect(r.explanation.measurementStart, addDays(today, -kWindowDays));
      expect(r.explanation.measuredKcal, isNotNull);
    });

    test('plain-English why mentions intake, trend and maintenance', () {
      final h = history(maintenanceKcal: 2500, intakeKcal: 2150);
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      final text = explainLines(r.explanation).join(' ');
      expect(
        text,
        contains('You averaged 2,150 kcal on $kWindowDays fully logged days'),
      );
      expect(text, contains('your weight went down'));
      expect(text, contains('so your maintenance is about 2,'));
    });

    test('partial weight names weigh-ins when they limit it', () {
      // Logged every day, but only 8 weigh-ins spread over the window:
      // weigh-ins (not logged days) limit w to (8-6)/4 = 50%.
      final start = addDays(today, -kWindowDays);
      final weighDays = {for (var i = 0; i < 8; i++) addDays(start, i * 3)};
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        weighed: weighDays.contains,
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.weight, closeTo(0.5, 1e-9));
      final text = explainLines(r.explanation).join(' ');
      expect(text, contains('With 8 weigh-ins that counts 50%'));
      expect(text, isNot(contains('With $kWindowDays fully logged days')));
    });

    test('partial weight names logged days when they limit it', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -10)) >= 0, // 10 days
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.weight, greaterThan(0));
      expect(r.explanation.weight, lessThan(1));
      final text = explainLines(r.explanation).join(' ');
      expect(text, contains('With 10 fully logged days that counts'));
    });

    test('w = 0 with a measured value still gives a reason', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (day) => day.compareTo(addDays(today, -7)) >= 0, // exactly 7
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.measuredKcal, isNotNull);
      expect(r.explanation.weight, 0);
      final text = explainLines(r.explanation).join(' ');
      expect(
        text,
        contains(
          '(only 7 fully logged days so far, not yet enough for your '
          'own data to count)',
        ),
      );
    });

    test('formula-only why gives the reason', () {
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: {today: 90},
          intake: const {},
        ),
      );
      final text = explainLines(r.explanation).join(' ');
      expect(text, contains('estimated from your body stats'));
    });
  });
}
