# Nutrition & Weight-Loss App: Plan v2 (for approval)

_Updated 2026-09-25 after Daniel's answers. Nothing built yet, no repository created._

## 1. Decisions so far
| Topic | Decision |
|---|---|
| Phone | Android only |
| Stack | Flutter |
| Hevy Pro | No, so no Hevy API. Workouts come in through Android Health Connect |
| Workout detail | Sessions only ("Chest and back", "Legs": name, start, duration) |
| Strava | Later |
| Food logging | Full: search, barcode scan, custom foods |
| Units | kg |
| Accounts | None. Single user, no login |
| Where data lives | **Phone** (Claude's pick, reasons in section 3) |

## 2. How the data gets in

```
Hevy ──writes workouts──►  Health Connect  ◄──on-device step tracking (Android 14+)
                                 │
                        our app reads (steps, exercise sessions)
                                 │
You ──food, weigh-ins──►   our app  ──► local database on the phone
Open Food Facts / USDA ──food data──►
```

- **Workouts:** Hevy writes to Health Connect (Hevy help: "How to Connect Hevy to Google Fit Using Health Connect"). Our app reads **exercise sessions** with the Flutter `health` package (v13.3.x, Aug 2026), which supports steps, weight, exercise sessions and nutrition on Android.
- **Steps:** your step app (Step Counter & Pedometer by DOSA Apps) does **not** mention Health Connect on its Play Store page, so I assume it doesn't share data. Health Connect has its own **on-device step tracking on Android 14+** (Android developer docs, "Track steps"), so our app reads steps from there. The count may differ a little from the DOSA app because they're separate counters. If your phone is older than Android 14, the fallback is our app counting steps from the phone's step sensor itself. That works but is less reliable (the sensor counter resets on reboot).
- **History:** Health Connect lets an app read 30 days back by default. Older data needs an extra "history" permission, which the app will request.
- **Sync:** every time you open the app, it pulls anything new from Health Connect into its own database. It stores a copy, so data survives even if Health Connect is cleared.

## 3. Why phone storage (not cloud) for now
- You asked for no user system. Phone storage needs no login, no server, no monthly cost, no project pausing, and works offline.
- Android automatically backs up app data to your Google account (Auto Backup, up to 25 MB per app). A food/weight/steps log is far below that. I'll verify this works on a real reinstall before relying on it. There will also be a manual **Export** button (JSON file).
- The **PC dashboard later** needs the data off the phone. Plan: add Supabase then, with one login you do once, and push the local data up. The data model is designed for that from day one, so nothing gets redone.
- Tradeoff: until then, you can only see your data on the phone.

## 4. Recommended calories and macros (the core feature)

**Inputs:** daily weigh-ins, logged food, and a one-time profile (sex, age, height, activity level, goal weight, weekly loss rate). You enter these in the app's settings, not in chat.

**Method:**
1. **Trend weight:** daily scale weight is noisy (water, salt, food in the gut). The app smooths it with an exponential moving average (about a 10-day smoothing window) and shows both the raw points and the trend line.
2. **Starting estimate:** before there's data, maintenance calories = Mifflin-St Jeor BMR × activity factor.
3. **Adaptive estimate:** once there are about 14 days of data: maintenance ≈ average daily intake − (trend weight change in kg × 7,700 kcal/kg) ÷ days. This covers workouts and steps automatically, so exercise calories are **not** added to your budget. The app gradually blends from the formula to the measured value as data builds up.
4. **Target:** daily calories = maintenance − (weekly loss rate × 7,700 ÷ 7). The rate is chosen as % of body weight per week (0.25 to 1.0%, default 0.5%). A floor stops it from going dangerously low.
5. **Macros:** protein about 2.0 g per kg of body weight (adjustable 1.6 to 2.2), fat at least about 0.8 g/kg, carbs fill the rest.
6. **Weekly update:** the target changes once a week (on a check-in screen that shows why), not every day, so it doesn't jump around with noise.
7. **Incomplete days:** a day where you forgot to log dinner would make it look like you eat less than you do. Each day has a "fully logged" toggle, and only fully logged days feed the estimate.

Steps and workouts are shown alongside (for example, "steps this week vs last week") as context, and can explain changes in maintenance. They are not calorie credits.

## 5. Food data
- **Open Food Facts:** barcode lookups and branded products. Free, needs a custom User-Agent, limited to 15 reads/min and 10 searches/min. Fine for one person, but search runs when you press Search, not on every keystroke.
- **USDA FoodData Central:** generic foods (chicken breast, rice, eggs). Free key, 1,000 requests/hour. The key would be inside the app. Acceptable for a personal app that isn't on the Play Store, but noted.
- **Your foods:** custom foods and saved meals, plus recent and favorite foods. After a couple of weeks, this is where most logging happens.
- Every food you log is cached locally, so repeat entries work offline.
- Coverage of local products depends on your country (question below). Custom foods fill any gaps.

## 6. Screens (v1)
1. **Today:** calories and protein remaining, macro bars, meals (breakfast/lunch/dinner/snacks), today's steps and workout, a quick weigh-in button.
2. **Add food:** search, barcode scan, recent, favorites, custom; grams or servings.
3. **Weight:** raw weigh-ins plus trend line; add/edit.
4. **Dashboard:** weight trend, weekly average intake vs target, steps per day, workouts per week, estimated maintenance over time.
5. **Weekly check-in:** new targets and why.
6. **Settings:** profile, goal, rate, protein level, Health Connect permissions, export.

## 7. Technical design
- Flutter (current stable, pinned when the project is created), Android only.
- Local database: SQLite through **Drift** (typed queries, migrations).
- State: Riverpod. Charts: fl_chart. Barcode: mobile_scanner. Health: `health`.
- Exact package versions are checked against pub.dev when the project is created, not assumed now.
- The calorie/macro engine is plain Dart with no UI or database dependencies, so it can be unit-tested thoroughly with made-up weight/intake histories.
- Tables: `foods`, `food_log`, `saved_meals`, `weights`, `day_status` (fully-logged flag), `steps_daily`, `workouts`, `profile`, `targets_history`.

## 8. How I'll build it (after approval)
- **Step 1 (me):** create the project skeleton, database, navigation, and CI (GitHub Actions: analyze, tests, build a debug APK you download and install).
- **Step 2 (parallel agents, as you asked):**
  - Agent A: calorie/macro engine plus unit tests
  - Agent B: food search, barcode, custom foods (Open Food Facts + USDA)
  - Agent C: Health Connect sync (steps + workouts)
  - Agent D: weight screen and dashboard charts
- **Step 3 (me):** integrate, review every agent's diff, run analyze + tests + APK build, then hand you an APK.
- **What I can't verify here:** Health Connect, the camera and real Android behaviour need your phone. I'll give you a short test checklist for that. Tests and builds prove the code compiles and the maths is right, not that it works on your device.
- Every commit, push and PR waits for your OK, per your rules. For speed, I'd ask for one approval to push feature branches and open PRs for this project.

## 9. Later
- v2: Supabase + PC web dashboard (Flutter web, same code).
- v3: Strava, AI photo/text meal logging, recipes, writing weight to Health Connect.

## 10. Risks
- Steps from Health Connect need Android 14+. Otherwise it falls back to the sensor, which is less reliable.
- Hevy's Health Connect session may not include a useful title on every workout. I'll check this on your first synced workouts.
- Food data is crowd-sourced (Open Food Facts) and can be wrong. Editing a food fixes it locally.
- If you rarely mark days as fully logged, the adaptive estimate stays near the formula for longer.
- USDA key is embedded in the app.

## 11. Answers (2026-09-25)
- Android 15: Health Connect native step tracking applies.
- Country: Israel. Open Food Facts coverage of Israeli barcodes is probably patchy (not measured). The "add food from the label" flow must be quick, and anything entered is saved for reuse. The Israeli Ministry of Health "Tzameret" food composition database could replace or complement USDA for generic foods. I couldn't reach data.gov.il from here, so that's unverified and not in v1.
- Language: English.
- Pushes and PRs: blanket OK for this project. Merging stays Daniel's.
- Repo: Daniel creates an empty private repo (this session can't create repositories).
- Builds: the Android SDK download is blocked in Claude's cloud environment, so APKs are built by GitHub Actions. Analysis and unit tests run locally.
