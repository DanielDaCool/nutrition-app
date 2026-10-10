# Calorie & macro engine (spec)

Pure Dart in `lib/features/targets/engine/`. No Flutter or DB imports. All numbers kg / kcal / g.

## Inputs
- Profile: sex, age (from birthDate at `today`), heightCm, activityLevel, goalWeightKg,
  weeklyRatePct (0.25–1.0, % of body weight per week, before the body-fat cap in §4),
  proteinPerKg (1.6–2.2), checkInWeekday.
- Weigh-ins: `Map<dayKey, kg>`. Trend via `computeTrend()` (`lib/domain/trend.dart`, EMA alpha 0.1).
- Intake per day with a `fullyLogged` flag. Only fully-logged days count.
- Previous accepted target (may be null): its maintenance, and — decoded from its stored
  explanation, when readable — its phase-start day, weekly rate, formula, maintenance mode,
  and Kalman state (§3). A check-in "skip" row carries the kept target's explanation forward
  (see §6), so it reads like the target it kept. A row with no readable explanation (e.g. one
  from before this design) is treated the same as no previous target for these fields, which
  safely starts a fresh phase and prior rather than crashing.

## 1. Formula estimate
Mifflin-St Jeor BMR = 10·kg + 6.25·cm − 5·age + (male ? 5 : −161), kg = latest trend weight.
formulaMaintenance = BMR × activityLevel.factor.

## Body composition estimate
Estimated once per recommendation from trend weight, height, age and sex — no extra user input:
- BMI = trendKg / heightM².
- bodyFatPercent = Deurenberg: 1.20×BMI + 0.23×age − (male ? 10.8 : 0) − 5.4, clamped to [5, 50].
- fatMassKg = bodyFatPercent% × trendKg.
- kcalPerKg (energy per kg of body-mass change) from Hall's energy densities (9,440 kcal/kg fat,
  1,816 kcal/kg lean) and Forbes's lean/fat partition (ΔLean/ΔFat ≈ 10.4 / fatMassKg):
  `kcalPerKg = fatFraction×9440 + (1−fatFraction)×1816`, `fatFraction = fatMassKg / (fatMassKg + 10.4)`.
  Replaces the flat 7,700 kcal/kg rule, which only holds around 30+ kg of fat mass — a leaner
  person's loss is more lean tissue, which stores less energy per kg. Falls back to the flat
  7,700 (`kKcalPerKg`) if fat mass isn't positive.
- Used for both the measured-maintenance conversion (§3) and the rate → deficit conversion (§4).

## Diet phase
A new phase starts today, resetting the skip window below, when: the weekly rate changed from the
previous target's (a user-driven change); maintenance mode was entered or left (a pause/resume);
or the formula moved by more than 300 kcal/day since the previous target (a big weight-driven
change, e.g. after a large trend-weight jump). Otherwise the phase continues from the previous
target's phase-start day. With no previous target to compare against — the very first
recommendation, or one whose stored explanation couldn't be read — there's no signal that a phase
just changed, so nothing is skipped; this also means pre-existing weigh-ins and logs from before
the feature was ever used are treated as real signal, not as a fresh diet start.

## 2. Measurement window
Nominal window = the 28 days ending yesterday (today is incomplete). The first 14 days after a
phase start are excluded from *measurement* (not from the nominal window shown in the
explanation): a diet's first two weeks lose glycogen and its bound water, which the scale counts
as fat at the same energy density and so overstates how much of the loss was real weight loss.
`measurementStart = max(nominalWindowStart, phaseStart + 14 days)`. If that's still after
yesterday, there's no measurement yet ("still settling in after a diet change").

- Weight change per day (kgPerDay), computed over `measurementStart..yesterday`:
  - Once the trend has run ≥ 30 days before `measurementStart`: (trend(end) − trend(start)) / days
    over the measurement window. By then the EMA's lag is < 5% and its difference is steadier than
    raw weigh-ins.
  - Before that: the least-squares slope through the raw weigh-ins inside the measurement window.
    The trend starts at the first weigh-in and lags ~10 days behind a steady loss, so a trend
    difference in the first weeks under-counts the loss (true maintenance 2500, intake 1950: 2283
    at day 21) and the target comes out too low. Needs the weigh-ins to span ≥ 14 days (raised from
    10, to match the 14-day phase skip above — a shorter span is mostly the excluded water swing
    anyway).
- Also needs ≥ 7 fully-logged days and ≥ 6 weigh-ins inside the measurement window. Otherwise
  measured = null for this week.
- avgIntake = mean kcal over fully-logged days in the measurement window.
- rawMeasured = avgIntake − kgPerDay × kcalPerKg. Clamp to [0.6, 1.6] × formulaMaintenance (guards
  against bad logging).
- Standard error of rawMeasured: from the regression's residuals (kg/day SE × kcalPerKg) when the
  raw-weigh-in slope was used; a fixed SD of 130 kcal/day (the rough midpoint of the 85–180 kcal
  range found once the trend-diff method has warmed up) when the trend-diff method was used, since
  a two-point difference has no residuals of its own.

## 3. Noise-weighted update (replaces a flat weekly cap on the raw measurement)
Treats the measured maintenance as a slowly drifting value, updated with a 1-variable Kalman
filter instead of trusting each week's raw reading outright:
- Prior: the previous smoothed measured value, with its variance increased by a process-noise term
  (SD 50 kcal, i.e. +2,500 kcal² per week — how much the true maintenance is expected to drift on
  its own between check-ins), scaled by the number of weeks actually elapsed since the previous
  target's `effectiveFrom` (`weeksSincePrevious`, rounded, minimum 1, capped at 12 weeks) rather
  than always assuming exactly one week. Check-ins can be skipped for arbitrarily long stretches
  (`checkInDue` stays true until the user acts — §6), and without this scaling a prior built from
  regular weekly check-ins stayed almost as confident after a 10-week gap as after a 1-week one,
  so a fresh, clean measurement was underweighted relative to a now-stale prior. No previous
  target (the first recommendation) counts as 1 week, the original assumption.
- Measurement: this week's rawMeasured, with the variance from §2 (so a noisy week counts less).
- `K = priorVar / (priorVar + measVar)`; `smoothed = prior + K × (rawMeasured − prior)`.
- The very first measurement (no prior) is taken as-is. A week with no fresh measurement carries
  the old smoothed value and variance forward (growing), so a later measurement still blends
  against a real prior instead of starting cold — but that week's own `measuredKcal` is still
  reported as null, and doesn't enter the blend below.
- Falls back to a fixed 130 kcal SD (matching §2) wherever a variance can't be computed.

## 4. Blend and target
n = fully-logged days, k = weigh-ins, both in the measurement window.
`loggedWeight = clamp((n − 7) / (18 − 7), 0, 1)`, `weighInsWeight = clamp((k − 6) / (10 − 6), 0, 1)`.
w = min(loggedWeight, weighInsWeight) when this week has a fresh measurement, else 0 (raised the
full-weight thresholds from n = 21 with the wider 28-day window, and added weigh-in coverage since
sparse weigh-ins make the slope noisy even with dense logging).
maintenance = (1 − w)·formula + w·smoothedMeasured. method = formula (w = 0), adaptive (w = 1),
blended otherwise.
If a previous target exists, limit the change of *this final maintenance* to ±150 kcal per weekly
update — kept as a hard guardrail on top of the Kalman smoothing in §3, not instead of it.

Weekly rate is capped by estimated body fat before it becomes a deficit: up to 1.0%/week at
BMI ≥ 30 or fat ≥ 30%, up to 0.75% at BMI ≥ 25 or fat ≥ 20%, else 0.5% — faster loss costs more
lean mass the less fat there is to lose.
- If trend weight ≤ goalWeightKg: target = maintenance (maintenance mode).
- Else deficit = effectiveRatePct/100 × trendKg × kcalPerKg / 7, capped at 25% of maintenance and
  750 kcal (lowered from 1000 — beyond that, lean-mass loss starts showing up under a lifting
  program).
- target = maintenance − deficit.
- In both modes the target is floored at max(BMR × 1.0, male ? 1500 : 1200). The floor used to
  apply only below goal weight; it now applies in maintenance mode too, as a safety measure — a
  maintenance estimate dragged down by under-logging must not produce an implausibly low target
  (e.g. ~775 kcal for someone whose formula maintenance is ~1,290). When maintenance itself is
  below the floor, the target is the floor in either mode, even though that is above the
  (probably under-measured) maintenance.
- Round kcal to nearest 10.

## 5. Macros
- protein = proteinPerKg × referenceKg, where referenceKg = min(trendKg, goalWeightKg × 1.15)
  (avoids huge protein at high body fat). Round to nearest 5 g. UI default 1.8 g/kg (was 2.0);
  a note suggests 2.0–2.2 above a 0.75%/week rate, where more protein helps hold lean mass.
- fat = max(0.8 g × trendKg, 25% of target kcal / 9). Round to 5 g.
- carbs = (target − protein·4 − fat·9) / 4. If carbs < 50 g, lower fat toward 0.6 g/kg to restore 50 g carbs
  (never below 0.6 g/kg). Round to 5 g.

## 6. Weekly check-in
- Due when today's weekday == checkInWeekday and no target has effectiveFrom == today, or when no target
  exists yet but a profile does (first target is created right away from the formula).
- Recommendation carries an explanation: formula, measured, weight w, avgIntake, trendDeltaKg, days,
  n logged days, weigh-ins in window, phase-start day, body fat %, kcal/kg used, weekly rate (raw
  and whether capped), Kalman-smoothed measured value and its variance, deficit, floor applied?,
  maintenance mode?.
- Accepting stores a TargetHistory row with effectiveFrom = today and the explanation as JSON.
- Skipping stores a copy of the current target's numbers with effectiveFrom = today, and copies
  the current target's explanation JSON forward with `skipped: true` / `keptFrom: <id>` added, so
  the next check-in keeps the phase start, rate, formula, maintenance mode and Kalman prior. The
  Kalman variance grows by one week of process noise (as for any week without a fresh
  measurement). Older skip rows that hold only the marker are followed back to the kept target.

## What stays as is
Mifflin-St Jeor on trend weight; not eating back exercise calories (measured maintenance already
includes average exercise); the 0.6–1.6× formula clamp; the calorie/macro floors and rounding
(the calorie floor now also covers maintenance mode, see §4); maintenance mode at or below goal
weight; no explicit metabolic-adaptation term (the weekly
re-measurement already captures any real drop in expenditure).

## Tests (required)
Synthetic histories: steady loss at known intake recovers known maintenance (±50 kcal); no lag in
the first weeks (true maintenance 2500, intake 1950, with and without noise, estimate within
±100 kcal by day 28, no single weekly change over 150 kcal); noisy weights and missed weigh-ins
stay within ±150 kcal of the true value; too little data → formula; a phase change resets and
skips the first 14 days; goal reached → maintenance; floor applies; deficit capped at 750 kcal;
rate capped by body fat; macro rounding and carb floor; ±150 kcal change limit; JSON round trip
including the new fields, and old rows (without them) still decode.
