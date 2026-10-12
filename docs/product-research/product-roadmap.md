# Product direction and roadmap

Research date: 2026-10-12 (Israel time). Evidence and limits: [competitive-landscape.md](competitive-landscape.md). Per-feature detail and scores: [feature-opportunities.md](feature-opportunities.md).

**Findings versus hypotheses.** Statements marked *(finding)* rest on verified sources or on reading the code. Statements marked *(hypothesis)* are my reasoning and need validation before money or time is spent on them. There is **no usage data, no analytics and no user research** behind this document; the app is used by a small circle of friends and nothing measures what they do.

## The question

What should we build, for whom, and why would they choose this app over the best alternatives?

## Where the app stands

- *(finding)* The calorie engine is the product's strongest asset. It is the same idea as MacroFactor's flagship (expenditure measured from weight trend and intake), with extra rigor documented in `docs/engine.md`, and it runs free, on the device, with no account.
- *(finding)* It is not alone: NutriTrace, a self-hosted open-source app, shipped an experimental adaptive mode in May 2026. MacroFactor already has most of the surrounding experience (explanations, history, saved meals, quick-add, CSV export).
- *(finding)* The shipped app has visible gaps relative to its own ambitions: saved-meal tables with no feature, recipes that cannot be logged, a flag the engine depends on that is easy to miss, and stored explanations the user cannot revisit.
- *(finding)* It is missing things the paid apps now treat as normal: photo logging, micronutrients, many languages. Chasing those is a different, funded race.

## Strategic directions compared

| | A. The adaptive engine you own | B. The lifter's nutrition companion | C. Breadth parity |
|---|---|---|---|
| Idea | Adaptive targets with no subscription, no server, no account, and honest about uncertainty | Link training (Hevy via Health Connect) to nutrition: protein, training-day macros | Match paid apps: micronutrients, AI photo, languages |
| Evidence | Moderate: adaptive is rare and mostly paid; privacy declarations differ (verified); demand is second-hand | Weak: no evidence found of lifters wanting this specifically; MacroFactor is moving in with Workouts | Strong that these exist; weak that this app's users want them |
| Advantage over time | Compounds: trust in an engine builds with use, and a local-first stance is hard for a subscription business to copy | Possible but contested by a funded competitor | None; competitors out-resource us |
| Cost | Low to medium | Medium, depends on unverified data | High, ongoing (data, AI costs, translation) |
| Verdict | **Primary** | Revisit after A, if the friends ask | Reject as a strategy; take single items only if validated |

## Recommended direction

**Primary: the adaptive engine you own.** *(hypothesis, supported by findings above)*

> Adaptive calorie targets with no subscription, no server and no account. Everything stays on your phone, and it tells you how sure it is.

Answers to the strategy questions:

1. **Underserved segment.** People who want expenditure-based targets but will not pay about $72 a year, will not run a Docker server, or do not want an account. Whether that is a large group is unknown; for now it is the friends and the developer. *(hypothesis)*
2. **Problem solved better.** Getting trustworthy daily targets from your own weight and food data, for free, privately. The edge to build is honesty about uncertainty, because MacroFactor's displayed confidence could not be found. *(hypothesis; the absence is unverified)*
3. **What to be known for.** "Your data and your targets, explained." A quality bar, not a slogan.
4. **Strengths to reinforce.** The engine, the offline free-text logger with Israeli foods, remembered barcodes, copy-day, the Hevy-to-Health-Connect path, JSON backup.
5. **Features that fit together.** Confidence and readiness (item 1) with close-the-day (item 5) fix the engine's weakest input. Saved meals, quick-add and CSV (items 2-4) make daily use less annoying and the data portable.
6. **Deliberately avoid.** Streaks and shame mechanics; chasing the micronutrient database; cloud accounts and ads (they would erase the privacy advantage); photo AI that uploads meals, unless friends demand it and a bring-your-own-key design stays optional; adherence scorecards that nag by default.
7. **Switching.** To switch from a paid app: free, no account, similar engine, and imports are not available (a gap to be honest about). To stay: the engine keeps working and explains itself, backup is simple, nothing is lost if the developer stops. A user who needs micronutrients, photo logging or Hebrew has a reason to stay with a competitor.
8. **Temporary versus compounding.** Temporary: any single feature (competitors can copy a confidence display). Compounding: a trusted engine tuned on a user's own history, local ownership of data, and no subscription pressure.

## Roadmap

### Quick wins (small, low risk)
| Item | Notes | Depends on |
|---|---|---|
| Fix README's engine section (done in this change) | The README still says flat 7,700 kcal/kg and a 10-day trend in 21 days; the engine uses neither | none |
| Quick-add calories (feature 3) | Mark entries macro-incomplete | none |
| CSV export (feature 4) | Include weigh-ins and targets | none |
| Weigh-in prefill from the last weight | UX tweak found in the audit | none |
| Remove stale statements: `docs/plan.md` ("nothing built yet"), `CLAUDE.md` listing saved meals as live | Docs only; `CLAUDE.md` is lead-owned | owner approval |

### Near-term differentiators
| Item | Notes | Depends on |
|---|---|---|
| Check-in history and readiness text (feature 1, first two pieces) | No schema change | none |
| Close-the-day prompt (feature 5) | Pairs with readiness text | readiness text |
| Saved meals UI (feature 2, part one) | Tables exist; verify backup upgrade | none |
| Confidence range (feature 1, third piece) | Needs a validated variance-to-range mapping | history list; validation with friends |
| Log a recipe serving (feature 2, part two) | Decide serving and yield semantics | saved meals |

### Longer-term, only after validation
| Item | Gate |
|---|---|
| Fiber (then sugar and sodium) | Friends say they want it; accept a three-step schema migration |
| Goal pace and ETA | Only when the trend is stable |
| Consistency card | Opt-in only; no streaks |
| Hebrew localization | A real Hebrew-reading user asks |
| Bring-your-own-key AI photo | Friends ask and the privacy trade-off is accepted |
| Training-day macro split | Evidence from friends that it changes behavior |
| Health Connect nutrition write | A concrete use case and lead approval for permissions |

Every item that is a `feature` PR must follow the CLAUDE.md rules: append an `AppFeature` value, gate every entry point, add a gate-off widget test. Schema changes need the migration, backup `_upgrade` and the tests listed there. No new packages without lead approval.

## What I would build first

1. **Check-in history with readiness text** (feature 1, pieces one and two). It is the cheapest slice of the primary direction, needs no schema change, and tests whether anyone cares about seeing the engine's reasoning. *Success looks like:* friends can say what the engine still needs before it adapts without asking; the check-in history is opened by more than one person in the first few weeks (counted by asking, since there is no analytics); and the share of days flagged fully logged changes in a direction we can explain. No baseline exists, so record one first.
2. **Saved meals** (feature 2, part one). It closes a visible dead end with tables already in place. *Success looks like:* friends use it for their repeated meals and stop retyping them; "Type it" volume for repeats falls (observed with friends, not measured). Do not expect it to win users.
3. **Quick-add calories plus CSV export** (features 3 and 4, together, one small PR each). They remove two common reasons to leave or to doubt the app, at low cost. *Success looks like:* no custom food created just for a restaurant meal; someone exports and opens the CSV in a spreadsheet without help.

**Why this order.** The first item tests the strategic bet cheaply; the second fixes a promise the app already makes; the third is hygiene that costs little. The confidence range is deliberately not first: it is the highest-differentiation piece but also the riskiest to get right, and should follow the history list so there is a place to show it.

## Validation plan *(hypotheses)*

There is no analytics and none is proposed, since the product's stance is that nothing leaves the device. Use the friend circle directly:

1. Ask 5 or so users how they repeat meals, what they dislike about logging, and whether they want fiber, Hebrew or photo logging. This is the main gap in the research: I found no primary user feedback.
2. Show a mock of the check-in with a confidence line and see whether it builds or erodes trust.
3. Watch for the engine's data sufficiency: how many users reach a measured (not formula) target within a few weeks.
4. Re-run the competitor check in six months: MacroFactor, NutriTrace and MyFitnessPal are all moving.

## Known uncertainty

- Competitor prices partly come from third-party blogs (see the landscape doc).
- I could not read Reddit or store review pages, so user demand claims are second-hand.
- MacroFactor's in-app screens were not inspected, so "does not display confidence" is unverified.
- NutriTrace's standalone mode and real user base were not verified.
- Nothing in this document has been tested on a device; no code was changed or run (Flutter is not installed in the research environment).
