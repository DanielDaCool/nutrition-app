# Nutrition App

A personal Android app for losing weight: log what you eat, weigh in every morning, and get
calorie and macro targets that adjust every week based on how your weight is actually moving.
Steps and gym workouts come in automatically from Health Connect (Hevy writes workouts there).

Everything is stored on the phone. There's no account, no server and no login.

## What it does

- **Food logging.** Search Open Food Facts (packaged products) or USDA (generic foods like
  chicken breast or rice), scan a barcode, or add a food from its label. Foods you've used show up
  under Recent and Favorites, so after a couple of weeks most logging is a few taps.
- **Describe what you ate.** Type a meal the way you'd say it ("5 spoons of cottage cheese 5% and
  2 eggs", "chicken breast 200g, 1 cup rice") and it's understood as you type: each food with its
  grams, calories and how the grams were worked out, ready to add in one tap. It's free and works
  offline (a built-in list of about 120 common and Israeli foods plus your own foods, no account
  or API key), and it learns: pick a different food or fix the grams once and next time your words
  and your spoon size are used.
- **Daily weigh-ins.** One weigh-in per day. The app smooths them into a trend line, so water and
  salt swings don't hide real progress.
- **Adaptive targets.** Each week (Sunday by default) the check-in compares what you ate on fully
  logged days with how your trend weight moved, estimates your real maintenance calories, and
  recommends new calories plus protein, fat and carbs for your chosen weekly loss rate.
- **Steps and workouts.** Read from Health Connect every time the app opens. They're shown for
  context and are never added back to your calorie budget.
- **Dashboard.** Weight trend, weekly intake against target, steps per day, workouts per week and
  the maintenance estimate over time.
- **Export.** Settings → Export data writes everything to a JSON file you can save or share.

## How the calorie recommendation works

1. **Start:** before there's enough data, maintenance = Mifflin-St Jeor BMR × your activity level.
2. **Learn:** once there are at least 7 fully logged days, 6 weigh-ins and a 10-day trend in the
   last 21 days, the app measures maintenance:
   `average intake − (trend weight change × 7700 kcal/kg) ÷ days`.
   It blends from the formula to the measured value as more logged days come in.
3. **Target:** maintenance minus the deficit for your weekly loss rate (0.25–1.0 % of body weight
   per week). The deficit is capped at 25 % of maintenance or 1000 kcal, and the target never drops
   below your BMR (or 1500 kcal for men, 1200 kcal for women).
4. **Macros:** protein 1.6–2.2 g per kg, fat is the larger of 0.8 g per kg and 25 % of calories,
   and carbs fill the rest (at least 50 g).
5. **Stability:** maintenance moves at most 150 kcal per week, and the target only changes when you
   accept the weekly check-in.

Only days you mark **"Day fully logged"** count. A day where you forgot dinner would otherwise make
it look like you eat less than you really do. The full spec is in [docs/engine.md](docs/engine.md).

## Installing on your phone

1. Open the latest successful run on the [Actions tab](https://github.com/DanielDaCool/nutrition-app/actions) (for `main` or a pull request).
2. Download the `nutrition-app-apk` artifact, unzip it, and copy `app-release.apk` to the phone.
3. Open it on the phone and allow installing from that source.

**Keep your data between updates:** new versions only install over the old one if every build is
signed with the same key. Set these repository secrets once (Settings → Secrets and variables →
Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | your release `.jks` file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `USDA_API_KEY` | optional: free key from [api.data.gov](https://api.data.gov/signup/) (the shared demo key allows ~50 searches a day) |

Without the signing secrets, CI signs with a throwaway debug key and you'd have to uninstall
(losing your data) to install a newer build. Keep the `.jks` file and passwords backed up outside
the repo.

## Connecting Hevy and steps (Health Connect)

Health Connect is built into Android 14 and newer.

1. In the app: **Settings → Health Connect → Connect**, allow steps, exercise, distance and calories,
   then allow access to past data (this lets the first sync go back 90 days instead of 30).
2. **Steps:** Health Connect starts counting steps on the phone itself as soon as an app is allowed
   to read steps. Your old step counter app doesn't need to share anything. The two counts may differ
   slightly.
3. **Workouts:** in Hevy, turn on syncing to Health Connect. Hevy workouts then appear on the Today
   screen after the next sync. The sync runs whenever the app opens or comes back to the
   foreground, and there's also a Sync now button.

The `health` package doesn't pass through workout titles yet, so workouts show their type (for
example "Strength training") rather than the name you gave them in Hevy.

## Development

Requirements: Flutter **3.47.5** (Dart 3.13.4), and Android Studio or the Android SDK to build an APK.

```bash
flutter pub get
dart run build_runner build   # after changing lib/data/db/tables.dart
flutter analyze
flutter test
flutter run                   # with a phone connected (USB debugging on)
flutter build apk --release --dart-define=USDA_API_KEY=your_key
```

For local release signing, create `android/key.properties` (it's git-ignored):

```properties
storeFile=C:/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

### Project layout

```
lib/
  main.dart               app entry, opens the database
  app/                    MaterialApp, bottom navigation, shared providers
  core/day_key.dart       days are stored as 'YYYY-MM-DD' strings in local time
  domain/                 types shared between features, weight trend math
  data/db/                Drift (SQLite) tables and generated code
  features/
    food/                 Open Food Facts + USDA clients, food log, add-food screens
    targets/              calorie engine, current targets, weekly check-in
    settings/             profile and goals, data export
    activity/             Health Connect sync (steps, workouts)
    weight/               weigh-ins, trend chart
    today/                Today screen
    dashboard/            charts over time
test/                     unit, provider and widget tests (in-memory database)
docs/                     plan and calorie engine spec
```

Tech: Flutter, Riverpod 3 for state, Drift for the local database, `health` for Health Connect,
`mobile_scanner` for barcodes and `fl_chart` for charts.

CI (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request. It checks that
the generated database code is up to date, then runs analyze and the tests, and builds the release
APK as a downloadable artifact.

## Data sources

- [Open Food Facts](https://world.openfoodfacts.org): open database (ODbL). Crowd-sourced, so
  values can be wrong. When a product is missing or wrong, add it from its label as your own food.
- [USDA FoodData Central](https://fdc.nal.usda.gov): public domain (CC0).
