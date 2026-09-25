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

/// Synthetic history: the person eats [intakeKcal] every day and has a true
/// maintenance of [maintenanceKcal], so the scale moves by
/// (intake - maintenance) / 7700 kg per day, plus uniform noise of ±[noiseKg].
/// Covers the [historyDays] days before today (today itself has no data).
({Map<String, double> weighIns, Map<String, DayLog> intake}) history({
  required double maintenanceKcal,
  required double intakeKcal,
  double startKg = 90,
  int historyDays = 60,
  double noiseKg = 0,
  int seed = 1,
  bool Function(int dayIndex)? logged,
  bool Function(int dayIndex)? weighed,
}) {
  final rnd = Random(seed);
  final perDayKg = (intakeKcal - maintenanceKcal) / 7700;
  final weighIns = <String, double>{};
  final intake = <String, DayLog>{};
  for (var i = 0; i < historyDays; i++) {
    final day = addDays(today, -historyDays + i);
    final trueKg = startKg + perDayKg * i;
    final noise = noiseKg == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * noiseKg;
    if (weighed?.call(i) ?? true) weighIns[day] = trueKg + noise;
    intake[day] = DayLog(
      kcal: intakeKcal,
      fullyLogged: logged?.call(i) ?? true,
    );
  }
  return (weighIns: weighIns, intake: intake);
}

void main() {
  group('formula', () {
    test('hand-checked formula-only recommendation', () {
      // Male, 30 years (born 1996-09-25, today 2026-09-25), 180 cm, one
      // weigh-in of 90 kg -> trend 90 kg.
      // BMR = 10*90 + 6.25*180 - 5*30 + 5 = 900 + 1125 - 150 + 5 = 1880
      // formula = 1880 * 1.55 (moderate) = 2914
      // deficit = 0.5/100 * 90 * 7700 / 7 = 495 (cap 25% = 728.5, 1000) -> 495
      // target = 2914 - 495 = 2419 -> 2420 (nearest 10); floor 1880 not hit.
      // protein = 2.0 * min(90, 80*1.15=92) = 180 g
      // fat = max(0.8*90=72, 2420*0.25/9=67.2) = 72 -> 70 g
      // carbs = (2420 - 180*4 - 70*9) / 4 = (2420-720-630)/4 = 267.5 -> 270 g
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
      expect(e.deficitKcal, closeTo(495, 1e-9));
      expect(r.macros.kcal, 2420);
      expect(r.macros.proteinG, 180);
      expect(r.macros.fatG, 70);
      expect(r.macros.carbsG, 270);
      expect(e.floorApplied, isFalse);
      expect(e.maintenanceMode, isFalse);
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

  group('adaptive maintenance', () {
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
      expect(e.loggedDays, 21);
      expect(e.weight, 1);
      expect(r.method, TargetMethod.adaptive);
      expect(e.avgIntakeKcal, 2000);
      expect(e.days, 20);
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
      // Log 14 of the 21 window days -> w = (14 - 7) / 14 = 0.5.
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        // Window = day indexes 39..59 (today-21 .. today-1); log 46..59.
        logged: (i) => i >= 46,
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
      final n = e.loggedDays;
      expect(n, 14);
      const w = 0.5;
      expect(e.weight, closeTo(w, 1e-9));
      expect(r.method, TargetMethod.blended);
      expect(
        r.maintenanceKcal,
        closeTo((1 - w) * e.formulaKcal + w * e.measuredKcal!, 1e-6),
      );
    });

    test('shortened span when weigh-ins start inside the window', () {
      // 14 days of history: first trend point is today-14, span = 13 days.
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        historyDays: 14,
      );
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: h.intake,
        ),
      );
      expect(r.explanation.days, 13);
      expect(r.explanation.measuredKcal, isNotNull);
      expect(r.explanation.loggedDays, 14);
    });

    test('measured value is clamped to 0.6–1.6 × formula', () {
      // Logged 500 kcal/day but weight goes up: garbage logging.
      final h = history(maintenanceKcal: 500, intakeKcal: 500);
      final bad = {
        for (final k in h.intake.keys)
          k: const DayLog(kcal: 500, fullyLogged: true),
      };
      final r = recommend(
        EngineInput(
          today: today,
          profile: profile(),
          weighIns: h.weighIns,
          intake: bad,
        ),
      );
      final e = r.explanation;
      expect(e.measuredClamped, isTrue);
      expect(e.measuredKcal, closeTo(0.6 * e.formulaKcal, 1e-6));
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
        logged: (i) => i >= 54, // 6 days
      );
      final r = recommend(input(h));
      expect(r.explanation.loggedDays, 6);
      expect(r.explanation.measuredKcal, isNull);
      expect(r.method, TargetMethod.formula);
      expect(r.maintenanceKcal, r.explanation.formulaKcal);
    });

    test('fewer than 6 weigh-ins in the window', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        weighed: (i) => i < 39 || i % 5 == 0, // 40,45,50,55 in window
      );
      final r = recommend(input(h));
      expect(r.explanation.weighInsInWindow, lessThan(6));
      expect(r.method, TargetMethod.formula);
      expect(r.explanation.measuredMissingReason, contains('weigh-ins'));
    });

    test('span shorter than 10 days', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        historyDays: 9,
      );
      final r = recommend(input(h));
      expect(r.method, TargetMethod.formula);
      expect(r.explanation.measuredMissingReason, contains('days'));
    });

    test('exactly 7 logged days -> measured exists but w = 0', () {
      final h = history(
        maintenanceKcal: 2500,
        intakeKcal: 2000,
        logged: (i) => i >= 53,
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
      // Female, 50 y, 155 cm, 60 kg, sedentary, 1 %/week:
      // BMR = 600 + 968.75 - 250 - 161 = 1157.75; formula = 1389.3
      // deficit = 0.01*60*7700/7 = 660, capped at 25% -> 347.3
      // 1389.3 - 347.3 = 1042 < floor max(1157.75, 1200) = 1200.
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
      expect(r.explanation.deficitKcal, closeTo(0.25 * 1157.75 * 1.2, 1e-6));
      expect(r.explanation.floorApplied, isTrue);
      expect(r.macros.kcal, 1200);
    });

    test('deficit capped at 1000 kcal', () {
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
      // 0.01*160*7700/7 = 1760; 25% of maintenance ~ 1070 -> 1000 cap.
      expect(r.explanation.deficitKcal, 1000);
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
      expect(text, contains('You averaged 2,150 kcal on 21 fully logged days'));
      expect(text, contains('your trend dropped'));
      expect(text, contains('so your maintenance is about 2,'));
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
