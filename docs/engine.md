# Calorie & macro engine (spec)

Pure Dart in `lib/features/targets/engine/`. No Flutter or DB imports. All numbers kg / kcal / g.

## Inputs
- Profile: sex, age (from birthDate at `today`), heightCm, activityLevel, goalWeightKg,
  weeklyRatePct (0.25–1.0, % of body weight per week), proteinPerKg (1.6–2.2), checkInWeekday.
- Weigh-ins: `Map<dayKey, kg>`. Trend via `computeTrend()` (`lib/domain/trend.dart`, EMA alpha 0.1).
- Intake per day with a `fullyLogged` flag. Only fully-logged days count.
- Previous accepted target (may be null).

## 1. Formula estimate
Mifflin-St Jeor BMR = 10·kg + 6.25·cm − 5·age + (male ? 5 : −161), kg = latest trend weight.
formulaMaintenance = BMR × activityLevel.factor.

## 2. Measured (adaptive) maintenance
Window = the 21 days ending yesterday (today is incomplete).
- Needs trend values at both window ends (at least one weigh-in on/before window start, or use the first
  trend point inside the window as start and shorten the span), span ≥ 10 days, ≥ 7 fully-logged days,
  and ≥ 6 weigh-ins inside the window. Otherwise measured = null.
- avgIntake = mean kcal over fully-logged days in the window.
- trendDeltaKg = trend(end) − trend(start); days = span in days.
- measured = avgIntake − trendDeltaKg × 7700 / days.
- Clamp measured to [0.6, 1.6] × formulaMaintenance (guards against bad logging).

## 3. Blend
n = fully-logged days in window. w = clamp((n − 7) / 14, 0, 1) when measured != null, else 0.
maintenance = (1 − w)·formula + w·measured. method = formula (w = 0), adaptive (w = 1), blended otherwise.
If a previous target exists, limit the change of maintenance to ±150 kcal per weekly update.

## 4. Calorie target
- If trend weight ≤ goalWeightKg: target = maintenance (maintenance mode).
- Else deficit = weeklyRatePct/100 × trendKg × 7700 / 7, capped at 25% of maintenance and 1000 kcal.
- target = maintenance − deficit, floored at max(BMR × 1.0, male ? 1500 : 1200).
- Round kcal to nearest 10.

## 5. Macros
- protein = proteinPerKg × referenceKg, where referenceKg = min(trendKg, goalWeightKg × 1.15)
  (avoids huge protein at high body fat). Round to nearest 5 g.
- fat = max(0.8 g × trendKg, 25% of target kcal / 9). Round to 5 g.
- carbs = (target − protein·4 − fat·9) / 4. If carbs < 50 g, lower fat toward 0.6 g/kg to restore 50 g carbs
  (never below 0.6 g/kg). Round to 5 g.

## 6. Weekly check-in
- Due when today's weekday == checkInWeekday and no target has effectiveFrom == today, or when no target
  exists yet but a profile does (first target is created right away from the formula).
- Recommendation carries an explanation: formula, measured, weight w, avgIntake, trendDeltaKg, days,
  n logged days, deficit, floor applied?, maintenance mode?.
- Accepting stores a TargetHistory row with effectiveFrom = today and the explanation as JSON.

## Tests (required)
Synthetic histories: steady loss at known intake recovers known maintenance (±50 kcal); noisy weights
(±1 kg daily noise, fixed seed) stay within ±150 kcal; too little data → formula; goal reached →
maintenance; floor applies; macro rounding and carb floor; ±150 kcal change limit.
