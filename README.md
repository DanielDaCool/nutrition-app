<div align="center">
  <img src="assets/icon/full-icon.png" alt="Nutrition App icon — bowl and sprout" width="112" height="112">

  # Nutrition App

  [![CI](https://github.com/DanielDaCool/nutrition-app/actions/workflows/ci.yml/badge.svg)](https://github.com/DanielDaCool/nutrition-app/actions/workflows/ci.yml)
  [![Web](https://github.com/DanielDaCool/nutrition-app/actions/workflows/web.yml/badge.svg)](https://github.com/DanielDaCool/nutrition-app/actions/workflows/web.yml)
</div>

A personal app for losing (or gaining) weight: log what you eat, weigh in every morning, and get
calorie and macro targets that adjust every week based on how your weight is actually moving.
Steps and gym workouts come in automatically from Health Connect (Hevy writes workouts there), or
you can log a workout by hand.

Everything is stored on the phone (or the browser, for the web build). There's no account, no
server and no login. Dark theme only ("Midnight Indigo" — periwinkle with a coral accent),
regardless of your device's setting.

### 📖 [Read the user manual](https://danieldacool.github.io/nutrition-app/manual/)

Installing it, first-time setup, and how to use every screen are all there, not repeated here.

**Get it:** [Android APK](https://github.com/DanielDaCool/nutrition-app/releases/download/latest-apk/nutrition.apk) · [Web app (iPhone-friendly)](https://danieldacool.github.io/nutrition-app/)

### Contents

- [Development](#development)
- [How the calorie recommendation works](#how-the-calorie-recommendation-works)
- [Releasing (signing secrets)](#releasing-signing-secrets)
- [Data sources](#data-sources)

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
    activity/             Health Connect sync (steps, workouts), manual exercise, step goal, walk reminder
    weight/               weigh-ins, trend chart
    today/                Today screen
    dashboard/            charts over time
    recipes/              bundled recipe catalog, search/filters, recommendations
test/                     unit, provider and widget tests (in-memory database)
docs/                     plan, calorie engine spec, and the user manual's source
```

Tech: Flutter, Riverpod 3 for state, Drift for the local database, `health` for Health Connect,
`mobile_scanner` for barcodes and `fl_chart` for charts.

Two workflows run in CI:

- **`ci.yml`** — on every push to `main` and every pull request: checks that the generated database
  code is up to date, then runs analyze and the tests, and builds the release APK as a downloadable
  artifact. On a push to `main` it also publishes that APK to the `latest-apk` GitHub release.
- **`web.yml`** — builds the Flutter web app and, on a push to `main`, deploys it (together with
  the user manual) to GitHub Pages at the web app link above.

## How the calorie recommendation works

1. **Start:** before there's enough data, maintenance = Mifflin-St Jeor BMR × your activity level.
2. **Learn:** once there are at least 7 fully logged days, 6 weigh-ins and a 10-day trend in the
   last 21 days, the app measures maintenance:
   `average intake − (trend weight change × 7700 kcal/kg) ÷ days`.
   It blends from the formula to the measured value as more logged days come in.
3. **Target:** maintenance minus the deficit (losing) or plus the surplus (gaining) for your
   weekly rate (0.25–1.0 % of body weight per week). The deficit side is capped at 25 % of
   maintenance or 1000 kcal, and the target never drops below your BMR (or 1500 kcal for men,
   1200 kcal for women).
4. **Macros:** protein 1.6–2.2 g per kg, fat is the larger of 0.8 g per kg and 25 % of calories,
   and carbs fill the rest (at least 50 g).
5. **Stability:** maintenance moves at most 150 kcal per week, and the target only changes when you
   accept the weekly check-in.

Only days you mark **"Day fully logged"** count. A day where you forgot dinner would otherwise make
it look like you eat less than you really do. The full spec is in [docs/engine.md](docs/engine.md).

## Releasing (signing secrets)

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

For a pull request's build instead of `latest-apk`, open its run on the
[Actions tab](https://github.com/DanielDaCool/nutrition-app/actions) and download the
`nutrition-app-apk` artifact (needs a GitHub login), then copy `app-release.apk` to the phone.

## Data sources

- [Open Food Facts](https://world.openfoodfacts.org): open database (ODbL). Crowd-sourced, so
  values can be wrong. When a product is missing or wrong, add it from its label as your own food.
- [USDA FoodData Central](https://fdc.nal.usda.gov): public domain (CC0).
