# Competitive landscape

Research date: 2026-10-12 (Israel time). Product baseline: app v0.1.1+4 at commit `4ca23cd`. This is a point-in-time snapshot; prices and features move.

## How to read the evidence

| Label | Meaning |
|---|---|
| **Verified** | Read on a first-party page (vendor site, store listing, official docs, repository) during this research. |
| **Vendor claim** | Stated on the vendor's own marketing. Accurate as "what they say", not as proof it is true. |
| **3P** | Third-party article, usually a rival app's blog or an affiliate review. Treat as a lead, not a fact. |
| **User-reported** | Something users are said to complain about or praise. Almost all of it here is second-hand (see limitations). |
| **Inference** | Our reasoning from the above. |

### Research limits (important)

- Reddit, `loseit.com`, `macrofactor.com/pricing` and `cronometer.com/pricing` could not be fetched from the research sandbox. I read **no primary Reddit threads** and no Play Store review pages. User sentiment below comes from secondary sources (review analyses, vendor blogs, forum summaries), several of them written by competing apps.
- Several prices (Cronometer, Lose It!, Carbon, Yazio, Cal AI) come from third-party blogs. They are marked `3P`.
- No Hebrew or Israeli-user feedback was found beyond store listings. That segment is **unresearched**.
- Flutter is not installed in the research sandbox, so `flutter analyze` and `flutter test` were not run; the product baseline comes from reading the code.
- Happy Scale, Libra, Noom, WW, Zero, Gyroscope, RP Diet, Strong and JEFIT were searched but returned nothing citable, so no claims are made about them.

## Our product, as verified from the code

A free, ad-free, account-free Flutter app (Android, plus a web build that iPhone users add to the Home Screen). Everything is stored on the device.

| Area | Implemented today |
|---|---|
| Food logging | Four meals a day; search over your own foods (offline) plus Open Food Facts and USDA; barcode scan that remembers barcodes; add-from-label; an offline free-text "Type it" parser with a built-in list of common and Israeli foods that learns corrections; recents and favorites; copy a meal or day; a "Day fully logged" flag |
| Recipes | Bundled catalog with filters and "Recommended for you" ranked by remaining macros. **Recipes cannot be logged** (read-only, no log button) |
| Weight | Daily weigh-ins, smoothed trend, chart, history |
| Targets | Adaptive engine (`docs/engine.md`): formula start, then measured maintenance from fully-logged intake versus trend-weight change, Kalman smoothing, body-fat-aware kcal-per-kg, 14-day settling window after a diet change, rate caps, floors, lose and gain goals, maintenance mode, a weekly check-in with a plain-language "why" |
| Activity (Android) | Health Connect steps and workouts (Hevy writes there), manual exercise calculator, step goal, walk reminder. Activity is deliberately not eaten back |
| Other | JSON export/import with versioned upgrades, in-app problem report, update banner |

**Not implemented (verified in code):** fiber, sugar, sodium or any micronutrient (nutrition is kcal, protein, fat, carbs per 100 g only: `lib/data/db/tables.dart:51-54`); photo or AI logging; water; CSV export; quick-add calories without creating a food; reminders other than the Android walk reminder; localization (English only); light theme; cloud sync.
**Exists in the database but has no feature:** `SavedMeals` and `SavedMealItems` (`tables.dart:86-99`). Nothing reads or writes them outside backup import/export.

## Direct competitors

| Product | Free tier | Paid price | Adaptive targets | AI / photo logging | Health Connect | Account / privacy |
|---|---|---|---|---|---|---|
| **MacroFactor** | None; 7-day trial | $11.99/mo, $71.99/yr (Verified, Play listing 2026-10-12) | **Yes**, weekly expenditure algorithm (flagship) | Photo, voice, text (vendor claim) | Yes (Verified) | Account required; Play data safety declares no data shared |
| **Cronometer** | Yes, with ads | Gold about $49.99/yr (3P) | None found | Photo (Gold, Aug 2025), voice (Apr 2026) (Verified changelog) | Reads and writes (Verified) | Account |
| **MyFitnessPal** | Yes, but barcode and Meal Scan are Premium | Premium $79.99/yr; Premium+ $99.99/yr (Verified) | None verified | Meal Scan, voice | 40+ integrations (Verified) | Play data safety: data may be shared with third parties |
| **Lose It!** | Yes, core tracking | Premium about $39.99/yr (3P) | None verified | Photo and voice (Premium, Verified Play) | Fitbit, Garmin, Google Fit | Data may be shared (Play) |
| **Carbon Diet Coach** | Trial only | About $79.99/yr (3P) | **Yes**, coach-style | No (3P) | Not verified | Account |
| **Cal AI** (owned by MyFitnessPal since March 2026) | Barcode and search free; photo paid | About $29.99/yr (3P) | No, static formula (MacroFactor's claim) | Photo is the core | Not verified | Account |
| **Yazio / FatSecret / Fitatu** | Yes, with ads or limits | Roughly EUR 4-6/mo (Yazio, 3P); others not verified | None found | Fitatu AI photo (2025); FatSecret image recognition | Fitbit/Garmin; Google Fit | Yazio and FatSecret: Play data safety says data may be shared |
| **NutriTrace** | Free, AGPL-3.0, self-hosted | n/a | **Yes, experimental** (shipped 2026-05-10 per its roadmap) | Not verified | Health Connect as a weight source (roadmap) | Own server; Android app described as able to run standalone |
| **OpenNutriTracker** | Free, GPL-3.0 | n/a | No | Optional, bring-your-own API key, marked experimental | Read-only workout import | Local-first; CSV export |
| **Waistline** | Free, GPLv3 | n/a | No | No | Not verified | Local; backup and restore |
| **CalBuddy** (Israeli) | Free download, scans paid | Not verified | Not verified | Photo AI | Not verified | Account |

Sources for the table are in the per-product sections below.

### MacroFactor: the closest competitor

- Positioning: ad-free "nutrition coach" built on a weekly expenditure algorithm. The Play listing (updated 2026-09-22) says it "estimates energy expenditure and adjusts calorie and macro targets weekly". <https://play.google.com/store/apps/details?id=com.sbs.diet> (Verified)
- Pricing and bundle: $11.99 a month, $71.99 a year, no free tier. Its Workouts app launched January 2026 and is bundled at $89.99 a year for users who started on or after 2026-01-01. <https://macrofactor.com/workouts/price/> (Verified)
- 2026 direction: Workouts app, recipe import from links and from a photo of a written recipe, iOS Live Activities in beta. <https://macrofactor.com/mm-jan-2026/>, <https://macrofactor.com/mm-april-2026/> (Verified)
- Health Connect: connects to Health Connect and Apple Health; the Workouts app reads whatever other apps write there. <https://help.macrofactorapp.com/en/articles/65-connect-health-connect-or-apple-health> (Verified). It names no direct Hevy integration, and whether it uses Hevy workouts for expenditure was **not verified**.
- Database: about 1.36M verified foods, 4M barcodes, 54 nutrients, with photo, voice and text logging (vendor claim, <https://macrofactor.com/macrofactor-vs-cal-ai/>).
- What it already does (Verified, `help.macrofactorapp.com`, checked by the adversarial reviewer): an expenditure graph of about six months; check-ins that suggest target changes and coaching modules that "explain why they appear"; a 4-of-7 logged-days rule with an "updating" or "holding" status and a Logging Break module; Copy and Paste, saved meals, recipes, Quick-Add calories and macros. CSV export of food, weight and expenditure is reported by a third party. A displayed confidence interval was **not found**.
- Weak points (user-reported, second-hand): no free tier; some lean users report targets that feel too low; trend-weight lag and water-weight swings confuse new users. Export options were **not verified**.
- Why it matters (inference): it is the only verified product that does what our engine does, and it is now moving into lifters' territory with Workouts.

### Cronometer

Micronutrient depth (up to 92 nutrients, Feb 2026), photo logging launched to Gold in August 2025 and voice in April 2026. No adaptive target feature was found in its official changelog (a negative finding from the changelog only). Health Connect reads weight, body fat and exercise, and writes nutrition, water and weight. <https://cronometer.com/blog/cronometer-updates-whats-new-improved>, <https://support.cronometer.com/hc/en-us/articles/22731903751316-Health-Connect> (Verified).

### MyFitnessPal

Mass-market (20.5M foods, 100M+ downloads per its Play listing, updated 2026-10-02). Premium $79.99 a year includes barcode, Meal Scan and voice logging; Premium+ adds meal planning. Acquired Cal AI (announced 2026-03-04, 3P news). No expenditure-based adaptive feature was found. Play data safety says it may share data with third parties. <https://www.myfitnesspal.com/premium> (Verified for prices).

### Lose It!, Carbon, Cal AI, SnapCalorie, Yazio, FatSecret, Fitatu

Summarised in the table. Carbon is the only other adaptive coach found, and all of its details come from a rival's blog (3P). SnapCalorie is photo-first with optional LiDAR on iPhone Pro, up to $149 a year (Verified, App Store). Cal AI is the acquisition-hook pattern: photo scanning behind a paywall (3P). Yazio gates data export behind its paid tier (3P).

### Open-source and local-first peers

- **NutriTrace** (<https://github.com/TraceApps/nutritrace>, Verified 2026-10-12): AGPL-3.0, 156 stars. The README lists "Goals + Adaptive TDEE. Fixed/Dynamic/Adaptive modes, 7,700 kcal/kg regression math" and says it "runs as a single Docker container on your own hardware", with an Android app that "works standalone or connected to your NutriTrace server". Its roadmap (read by the adversarial reviewer, not re-read by me) says adaptive TDEE shipped as experimental on 2026-05-10, needs 21 valid days, and shows a readiness card with a confidence field and a "How it works" explainer. **This is the one free adaptive tracker I found. It means "the only free adaptive app" is not a claim we can make.** It uses a flat 7,700 kcal/kg regression where our engine adds Kalman smoothing, a body-fat-aware kcal-per-kg and a settling window (our docs, not independently benchmarked). Whether its adaptive mode works without the server was not verified.

- **OpenNutriTracker** (<https://github.com/simonoppowa/OpenNutriTracker>, Verified): Flutter, GPL-3.0, about 2.5k stars. Search, barcode, quick-add, a 10-nutrient panel, water, optional fasting timer, optional bring-your-own-key LLM meal assistant, optional read-only workout import, CSV export in a zip. **No adaptive targets and no weight trend.** The README says it is still under construction.
  *Versus us:* we are ahead on the adaptive engine, weight trend, offline free-text parser, Israeli foods and the Hevy path. They have iOS native, micronutrients, water, fasting, CSV and several languages.
- **Waistline** (<https://github.com/davidhealey/waistline>, Verified): Android, GPLv3, diary and barcode, backup and restore. Its last release date was not verified.

### Israel

- **CalBuddy** is an Israeli app with a Hebrew UI, AI photo scan and a database of common Israeli foods, 100K+ downloads, 4.2 on the App Store but 2.8 across written reviews (a store mirror, <https://mwm.ai/apps/calbuddy/6745977666>). Complaints cited: portion accuracy, billing, database completeness. Price not verified.
- Open Food Facts Israel listed **8,620 products** on 2026-10-12 (<https://il-en.openfoodfacts.org/>, Verified). Inference: this is small next to a supermarket's range, so scan misses will be common; our add-from-label and remembered barcodes are the right fallback.
- Tzameret (the Ministry of Health food composition database): licence, API and bulk access are **unverified**. The government pages could not be fetched. Do not assume it can be embedded.
- Israeli supermarket price files exist (25 chains, barcode and name, no nutrition) per a third-party listing. They could pre-fill product names on a scan miss, but that would be a large ingestion project and is not recommended now.

## Adjacent and unconventional patterns

| Source | Pattern | Evidence | How it could translate |
|---|---|---|---|
| Oura readiness score | One score split into named contributors, each phrased as a question ("Was my resting heart rate higher than usual?") | Verified, <https://ouraring.com/blog/readiness-score/> | Check-in "why" as contributor rows (logged days counted, trend, window excluded) plus a confidence line |
| Duolingo streak research and a critique | Harsh streak loss can reduce motivation; critics recommend recovery paths | Verified, <https://blog.duolingo.com/duolingo-streak-research/>, <https://ignorethecode.net/blog/2023/06/26/streak_redemption/> | For a calorie app, streaks risk pushing people to log junk that pollutes the engine. Show "days the engine used", not a streak |
| Obsidian "file over app" | Data in formats you can still open in ten years | Verified, <https://stephango.com/file-over-app> | CSV export and a documented JSON schema |
| Actual Budget vision | Data lives on the device; you own it | Verified, <https://actualbudget.org/docs/vision/> (says nothing about export) | State the privacy promises plainly in Settings |
| Android Health Connect docs | Nutrition and hydration records are writable; do not write back data you read from Health Connect; use `clientRecordId` to avoid duplicates | Verified, <https://developer.android.com/health-and-fitness/health-connect/data-types>, `.../write-data` | An opt-in "write my meals to Health Connect" is technically possible. Whether the pinned `health` package exposes it was **not checked** |
| Android app shortcuts | Long-press launcher shortcuts (static XML or dynamic) | Verified, <https://developer.android.com/develop/ui/views/launch/shortcuts/creating-shortcuts> | Shortcuts for scan, weigh-in and Type it. Needs manifest changes (lead-owned) |
| Hevy help page | Hevy passes data through Health Connect to other apps | Verified, <https://help.hevyapp.com/hc/en-us/articles/34895971528727-How-to-connect-to-MyFitnessPal-through-Apple-Health-or-Health-Connect> | Hevy to Health Connect is the sanctioned route; the page says nothing about nutrition |

Not researched or not citable: Quick Settings tiles, Wear OS, widgets, share targets, Happy Scale, Libra, Noom, WW, Zero, Gyroscope, YNAB's specifics.

## What users complain about (second-hand, ranked by consistency)

1. **Paywalls, subscriptions and ads.** The most consistent theme. One review analysis (Unstar, 2026-04-23, sample size undisclosed) puts paywall and upsell complaints at 29% and ads at 15% of 1-3 star reviews. MyFitnessPal's 2022 move of barcode scanning behind Premium is repeatedly cited. <https://unstar.app/blog/calorie-tracking-apps-ranked-1-star-reviews-2026> (User-reported; the figures are unauditable).
2. **Inaccurate or inconsistent food data**, 18% in the same analysis; Cal AI reviews cite wrong calories and serving sizes (very small sample).
3. **Logging friction.** Cronometer lag and no offline mode, no fractions (one forum summary). The founder of a competing indie app cites clunky flows (<https://www.indiehackers.com/post/i-built-metricsync-after-getting-tired-of-calorie-apps-that-cost-more-and-still-made-logging-slower-045b2ce009>). Builder motivation, not a survey.
4. **Adaptive-algorithm trust.** MacroFactor targets reported as too low for lean users; confusion about water weight (affiliate review and forum titles only).
5. **Data lock-in and privacy.** 5% of complaints in the same analysis; privacy-minded Android users steer to open-source apps (one forum thread).
6. **Streak and shame mechanics** (12% and 6% in the same analysis). Weak evidence.

What is **not** supported by what I could find: demand for Hebrew localization, demand for micronutrient tracking among this app's users, and how people actually repeat meals (spreadsheets, copy and paste). All three need validation with real users.

## What the landscape says

1. **Adaptive targets are rare, and mostly paid.** MacroFactor and Carbon were verified as expenditure-adaptive, at roughly $72 and $80 a year; the only free one found is the self-hosted, experimental NutriTrace. Cronometer, MyFitnessPal, Lose It! and Yazio showed no such feature in the sources I could read. A free adaptive engine that runs on the device is an uncommon combination, though the negative findings rest on what I could read, not on exhaustive testing of each app. (Verified for MacroFactor; negative findings for the others.)
2. **AI photo logging is now standard** in paid tiers (Cronometer, Lose It!, MyFitnessPal, Cal AI, SnapCalorie, Fitatu, CalBuddy). We have none. The price of it elsewhere is a subscription and uploading food photos to a server. Our offline text parser is the privacy-preserving alternative, not a substitute for photos.
3. **Micronutrients are the largest feature gap** against paid peers (Cronometer 92 nutrients, MacroFactor 54 by its own claim). Whether this app's users want it is unknown.
4. **Privacy is a real, checkable difference.** Several large competitors declare third-party data sharing in their Play data-safety sections; this app has no account and no server. The Play data-safety statements are verified; whether users switch for it is not.
5. **Consolidation is happening.** MyFitnessPal bought Cal AI (March 2026); MacroFactor added a Workouts app (January 2026) aimed at lifters. The lifter niche will not stay empty.
6. **Our nearest open-source peer lacks the engine.** OpenNutriTracker has more breadth and iOS, but no adaptive targets.
