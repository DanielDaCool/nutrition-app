# Feature opportunities

Research date: 2026-10-12 (Israel time). Read [competitive-landscape.md](competitive-landscape.md) first for the evidence labels and the research limits. Strategy and sequencing are in [product-roadmap.md](product-roadmap.md).

This is a short list on purpose. The research supports a few well-targeted improvements, not a feature race.

## Method and scoring

Candidates came from four independent research passes (direct competitors, user complaints, adjacent products, a code and UX audit), then went through an adversarial review that tried to disprove each one. Two ideas changed materially in that review:

- The claim "no other free app does adaptive targets" was **false**: NutriTrace, a self-hosted open-source tracker, has an experimental adaptive mode. Positioning was rewritten.
- MacroFactor already ships most of what I first called "show your work" (expenditure history, check-in explanations, a visible logging-sufficiency rule). The shortlist was narrowed to the part it does not appear to do.

**Scores are my estimates from 1 (weak) to 5 (strong). They are not measured market data.** They support judgment; they do not replace it.

| Criterion | What a 5 means |
|---|---|
| User value | Removes a frequent or serious friction, or enables something users clearly want |
| Evidence | Directly supported by verified facts. 1-2 means mostly inference or thin second-hand reports |
| Differentiation | Competitors do not offer it, or do it clearly worse. 1 means everyone has it |
| Fit | Matches the app's local-first, simple, no-account character and its lifting-oriented user |
| Feasibility | Small change on existing code and tables. 1 means a large or risky build |

Effort is separate: **Low** (about a day or less), **Medium** (a few days), **High** (a week or more), each including tests and manual updates.

## Shortlist at a glance

| # | Feature | Value | Evidence | Differentiation | Fit | Feasibility | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| 1 | Honest targets: confidence range, readiness, check-in history | 4 | 2 | 4 | 5 | 3 | Medium | Medium-Low |
| 2 | Finish saved meals and make recipes loggable | 4 | 3 | 1 | 5 | 4 | Medium | Medium |
| 3 | Quick-add calories | 3 | 3 | 1 | 5 | 5 | Low | Medium |
| 4 | CSV export | 3 | 3 | 2 | 4 | 5 | Low | Medium |
| 5 | Close-the-day prompt | 3 | 2 | 2 | 5 | 4 | Low-Medium | Medium-Low |

Considered and not promoted (details at the end): fiber and other nutrients, goal pace and ETA, consistency card, weigh-in prefill, AI photo logging, Health Connect nutrition write, Hebrew, training-day macro splits, reminders.

Items 2, 3 and 4 are mostly **catch-up**, not differentiators: competitors already have them. They are on the list because they remove real gaps (item 2 is a dead end in the shipped UI), not because they win users.

---

## 1. Honest targets: confidence range, readiness and check-in history

**One sentence.** Show how sure the engine is about your maintenance calories, what it still needs before it can adapt, and let you look back at every past check-in and why it changed.

**Problem.** The engine already computes uncertainty and stores a full explanation for every check-in, but the user sees only a point estimate and a one-off explanation, and cannot look back. Before the engine has enough data, the check-in says only that you should "log a weigh-in" (`checkin_screen.dart:170-205`).

**Evidence.**
- Verified in code: Kalman variance and the full explanation are stored in `TargetHistory.explanationJson` (`targets_repository.dart:181,215`) and read back only by the engine, never rendered. There is no check-in history screen. The thresholds the engine needs (7 fully-logged days, 6 weigh-ins, a 14-day span: `engine.dart:23,32,39`) are not shown anywhere before a check-in.
- Verified on MacroFactor: it explains check-in suggestions and shows a "holding" or "updating" status under a 4-of-7 logging rule. I found **no displayed confidence interval** there, but I could not inspect the in-app screens, so treat "MacroFactor does not show confidence" as unverified.
- Verified on NutriTrace: a readiness card with a confidence field and an explainer exists in a free, self-hosted app.
- User-reported, thin: MacroFactor users say targets feel too low, and some find the expenditure and trend screens confusing ("I'm apparently very confused how to read both of these", a mirrored forum post). Second-hand.

**Competitors.** MacroFactor: explanations and a sufficiency status, no verified confidence band. NutriTrace: readiness and confidence, but self-hosted and experimental. Everyone else: no adaptive engine to explain.

**What is wrong with the alternatives.** MacroFactor is paid and needs an account. NutriTrace needs a server for most users. Neither is "install and go, free, on your phone". Whether either handles uncertainty as rigorously as our Kalman engine is unverified.

**Our approach.** Three small pieces on data we already have:
1. *Confidence line* on the check-in and calorie card, derived from the Kalman variance: "Maintenance about 2,650 kcal, give or take 120, based on 19 days." Needs a plain-English mapping from variance to a range. This is the research-risky part.
2. *Readiness*: replace the generic "log a weigh-in" with what is actually missing: "4 of the 7 fully-logged days the engine needs, 3 weigh-ins of 6." Lean toward MacroFactor's simpler idea of what counts, so people are not pushed to flag days as complete just to unlock it.
3. *Check-in history*: a list of past targets (date, calories, maintenance, method) that expands to the existing `explainLines` text. It must handle old rows with no readable explanation (`docs/engine.md`, inputs section).

**Why users would choose it.** Mostly a trust argument: the same adaptive idea as the paid apps, free, with the reasoning and its uncertainty visible. This is a quality bar, not a headline feature.

**Frequency.** Weekly at check-in; occasional otherwise.

**MVP.** Check-in history list plus the readiness text. Confidence range second, once the variance-to-range mapping is validated against the engine's own tests.

**Future.** Maintenance-over-time chart with the confidence band; "why did my target change" on the calorie card.

**Feasibility.** All in `lib/features/targets/**` and a dashboard chart: no schema change, no new package. Needs pure-Dart functions for the range and the readiness text, tests for legacy and skipped rows, and an `AppFeature` value (CLAUDE.md feature rules). Ownership crosses targets and today (the calorie card).

**Risks and trade-offs.**
- A wide band for weeks can read as "the app is broken". Mitigate with wording that frames it as normal early on.
- A readiness gate can be gamed through the "fully logged" flag, which would poison the engine. Keep wording about what is missing, not a score to hit.
- Contributor-style rows may overwhelm casual users; start with plain sentences.
- Mapping Kalman variance to a human range is not trivial and could mislead if done carelessly. Test against the existing synthetic histories.

**Confidence: Medium-Low.** The gap in the app is verified, and the competitive opening is plausible, but user demand is second-hand and the opening depends on MacroFactor not showing confidence, which I could not confirm.

**Validation.** Before building the range: show 3-5 friends a mock of the check-in with and without the confidence line and ask which they would trust and whether the band alarms them. Cheap build first: the history list, then watch whether anyone opens it.

---

## 2. Finish saved meals and make recipes loggable

**One sentence.** Turn the orphaned saved-meal tables into a working "save this meal, log it in one tap" feature and let a recipe be logged to a meal.

**Problem.** Two dead ends in the shipped app. `SavedMeals` and `SavedMealItems` exist in the schema and in backups (`tables.dart:86-99`) but no screen uses them, although `CLAUDE.md` lists them as live. The Recipes tab shows "Recommended for you" ranked by remaining macros, but nothing logs a recipe; you retype it via "Type it".

**Evidence.** Verified in code (grep: zero references outside backup import/export; no recipe-to-log call). Competitor parity is verified: MacroFactor has saved meals, recipes, copy and paste; Cronometer has copy and multi-select copy; FatSecret gates Copy Food behind Premium. Our free copy-day already beats that last one.

**Competitors.** Standard everywhere. This is table stakes, so there is no differentiation claim.

**Our approach.** "Save as meal" on a logged meal, a Saved meals list in the add-food screen, one tap to log it. On each recipe, "Log a serving" to a chosen meal. Meal-aware Recents (rank by the same meal slot) is a smaller follow-up and can wait: the adversarial review judged its marginal gain small given copy-day and recents already exist.

**Why users would choose it.** They would not choose the app for it. They would stop being annoyed by a visible dead end, and the recommended-recipes feature would finally close its loop.

**Frequency.** Daily for anyone who repeats meals.

**MVP.** Saved meals only (save, list, log). Recipes second.

**Future.** Edit saved meals; recipe import (MacroFactor does this from links and photos; not proposed here).

**Feasibility.** Tables exist, so likely no migration, but verify that backup `_upgrade` already handles them. Needs a repository, an `AppFeature` value, gating and a gate-off widget test. Recipes currently read-only by contract, so logging crosses the recipes and food owners; the recipe's serving and gram semantics need a decision (yield, per-serving grams).

**Risks.** Recipe yield and portion edge cases. Scope creep for a feature users regard as basic.

**Confidence: Medium.** The gap is verified; the user benefit is plausible but unmeasured.

**Validation.** Ask the friends how they log repeat meals today. Check whether anyone has retyped a recommended recipe.

---

## 3. Quick-add calories

**One sentence.** Log "400 kcal, optional protein/fat/carbs" without creating a food.

**Problem.** Every entry needs a food row with per-100 g values (`FoodLogEntries.foodId` is non-null: `tables.dart:76`). A restaurant meal means filling the custom-food form (about seven fields).

**Evidence.** Verified in code. Verified parity: MacroFactor Quick-Add and OpenNutriTracker quick-add. User demand is unmeasured.

**Approach.** A "Quick add" option on the add-food screen. Without a schema change it can create a hidden food with `source: 'quick'`, per-100 g set so that 100 g equals the typed calories; a cleaner version adds a nullable note column and needs the three-step migration. Entries with no macros skew protein, fat and carb targets, so mark them as macro-incomplete and say so on the day.

**MVP.** Calories plus optional macros, no schema change. **Effort: Low. Confidence: Medium.** Risk: macro skew and clutter in "My foods" if hidden foods leak into lists (exclude them).

**Validation.** Count how often friends create one-off custom foods.

---

## 4. CSV export

**One sentence.** Export food log, weigh-ins and target history as CSV alongside the existing JSON backup.

**Problem and evidence.** Export is JSON only. Data lock-in and export are about 5% of complaints in one unauditable review analysis; Obsidian's "file over app" and Actual Budget make ownership a selling point; OpenNutriTracker ships CSV, but excludes weight and profile. MacroFactor's CSV including expenditure is reported by a third party, so this is **parity with the paid app and an edge only against free peers.**

**Approach.** Plain headers using the app's own conventions (`dayKey`, `kcal`, `kg`), three files, hand-written in pure Dart (no new package). Include weigh-ins and targets, which the open-source peer omits. Skip the "documented schema" as a headline: publishing one creates a compatibility promise for a small audience.

**Effort: Low. Confidence: Medium.** Risks: web download behavior needs testing (`file_picker` and `share_plus` on web). **Validation:** ask whether anyone would use it; it is cheap enough to build without waiting.

---

## 5. Close-the-day prompt

**One sentence.** Prompt to mark today complete at a sensible moment, and show the engine's current data status next to the "Day fully logged" switch.

**Problem.** The "Day fully logged" flag is the engine's most important input but is a small switch at the bottom of a long card. Only yesterday is ever prompted, and that prompt reappears after each restart (`yesterday_prompt.dart:12-23`; in-memory state).

**Evidence.** Verified in code. The adversarial review warns the flag can be gamed. That is a risk to wording, not a reason to hide the flag. No user feedback on this specific friction was found.

**Approach.** An in-app evening card on Today (web and Android) with "Mark today complete". An Android notification would reuse the walk-reminder scheduler and is a larger, separate step. Pair with the readiness text from item 1.

**Effort: Low-Medium** (in-app), **Medium** with a notification. **Confidence: Medium-Low.** **Validation:** compare, over a few weeks, how many days each friend flags complete before and after.

---

## Considered and not promoted

| Idea | Why not now |
|---|---|
| **Fiber (and maybe sugar, sodium)** | A real gap against Cronometer and MacroFactor, and the nutrient lifters most plausibly want. But it needs a three-step schema migration and parser changes (Effort: High), and I found no user evidence for it. Ask the friends first; if yes, fiber alone is the cheap middle ground. |
| **Goal pace and ETA** | Cheap, but weight-trend apps already do it, and early projections are unreliable. If built, show it only once the trend is stable. |
| **Consistency card (days on target, protein hit-rate)** | Useful for lifters, but MacroFactor appears to avoid adherence UI deliberately (it has an opt-in to display overages), and it can nag. If built, opt-in, no streaks. |
| **Weigh-in prefill or stepper** | Genuine small friction (the field does not prefill), from the code audit alone. Do it as a tweak, not a feature. |
| **Bring-your-own-key AI photo logging** | Photo logging is standard in paid tiers and OpenNutriTracker has an experimental version. It conflicts with "nothing leaves your phone", needs a key in the app and extra design. Defer; revisit only if friends ask. |
| **Health Connect nutrition write** | Possible per Android docs, and Cronometer does it. No demand evidence; whether the pinned `health` package exposes it was not checked; needs lead approval for permissions. |
| **Hebrew localization** | No evidence of demand in the research (unresearched, not disproved). Ask the friends. |
| **Training-day macro split from Hevy workouts** | Hypothesis only; no evidence found. Would apply to macro distribution, not total calories, to respect "activity is not eaten back". |
| **Reminders (evening log, weigh-in)** | Plausible, Android-only, no demand evidence. Part of item 5 if wanted. |
| **Streaks, social, coach, grocery lists** | Rejected: streaks risk junk logging that poisons the engine; the rest fit neither the product nor the evidence. |
