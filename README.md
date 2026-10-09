<div align="center">
  <img src="assets/icon/full-icon.png" alt="Nutrition App icon — bowl and sprout" width="112" height="112">

  # Nutrition App

  [![CI](https://github.com/DanielDaCool/nutrition-app/actions/workflows/ci.yml/badge.svg)](https://github.com/DanielDaCool/nutrition-app/actions/workflows/ci.yml)
  [![Web](https://github.com/DanielDaCool/nutrition-app/actions/workflows/web.yml/badge.svg)](https://github.com/DanielDaCool/nutrition-app/actions/workflows/web.yml)
  [![Release](https://img.shields.io/github/v/release/DanielDaCool/nutrition-app?label=release)](https://github.com/DanielDaCool/nutrition-app/releases/latest)
</div>

A personal app for losing (or gaining) weight: log what you eat, weigh in every morning, and get
calorie and macro targets that adjust every week based on how your weight is actually moving.
Steps and gym workouts come in automatically from Health Connect (Hevy writes workouts there), or
you can log a workout by hand.

Everything is stored on the phone (or the browser, for the web build). There's no account, no
server and no login. Each person's data stays on their own device; Settings → Export data saves
a backup, and Import data (or *Restore from a backup* on first run) brings it back on a new phone. Dark theme only ("Midnight Indigo" — periwinkle with a coral accent),
regardless of your device's setting.

### 📖 [Read the user manual](https://danieldacool.github.io/nutrition-app/manual/)

Installing it, first-time setup, and how to use every screen are all there, not repeated here.

**Get it:** [Android APK](https://github.com/DanielDaCool/nutrition-app/releases/latest/download/nutrition.apk) · [Web app (iPhone-friendly)](https://danieldacool.github.io/nutrition-app/) · [What's new](https://github.com/DanielDaCool/nutrition-app/releases)

Both always serve the latest release. On iPhone, open the web app in Safari and use Share → Add to
Home Screen. Your version is shown at the bottom of Settings.

### Contents

- [Development](#development)
- [How the calorie recommendation works](#how-the-calorie-recommendation-works)
- [Releasing a new version](#releasing-a-new-version)
- [Data sources](#data-sources)

## Development

Requirements: Flutter **3.47.5** (Dart 3.13.4), and Android Studio or the Android SDK to build an APK.

```bash
flutter pub get
dart run build_runner build   # after changing lib/data/db/tables.dart
flutter analyze
flutter test
flutter run                   # with a phone connected (USB debugging on)
flutter build apk --release --dart-define=USDA_API_KEY=your_key --dart-define=APP_VERSION=0.0.0+2
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
    settings/             profile and goals, backups (export and import)
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
  artifact. On a version tag it also attaches the APK to that version's GitHub release.
- **`web.yml`** — builds the Flutter web app on every push and pull request. On a version tag it
  deploys it (together with the user manual) to GitHub Pages at the web app link above.

Merging to `main` doesn't change what friends have; only [a release](#releasing-a-new-version) does.

## How the calorie recommendation works

1. **Start:** before there's enough data, maintenance = Mifflin-St Jeor BMR × your activity level.
2. **Learn:** once there are at least 7 fully logged days, 6 weigh-ins and a 10-day trend in the
   last 21 days, the app measures maintenance:
   `average intake − (trend weight change × 7700 kcal/kg) ÷ days`.
   It blends from the formula to the measured value as more logged days come in.
3. **Target:** maintenance minus the deficit (losing) or plus the surplus (gaining) for your
   weekly rate, which you pick with a slider from 0.25 % of body weight a week up to a cap the
   app sets from your BMI and body fat. Losing: cap is 0.5–1.0 % (higher BMI/body fat allows a
   faster loss rate), deficit capped at 25 % of maintenance or 750 kcal, target never below
   your BMR (or 1500 kcal for men, 1200 kcal for women). Gaining: cap is 0.25–0.5 % (leaner
   people get more surplus headroom for muscle building; modest surpluses build about as much
   muscle as large ones), surplus capped at 25 % of maintenance or 500 kcal.
4. **Macros:** protein 1.6–2.2 g per kg, fat is the larger of 0.8 g per kg and 25 % of calories,
   and carbs fill the rest (at least 50 g).
5. **Stability:** maintenance moves at most 150 kcal per week, and the target only changes when you
   accept the weekly check-in.

Only days you mark **"Day fully logged"** count. A day where you forgot dinner would otherwise make
it look like you eat less than you really do. The full spec is in [docs/engine.md](docs/engine.md).

## Releasing a new version

1. In `pubspec.yaml`, raise `version:`, both the name and the build number after `+`
   (e.g. `0.0.0+2` → `0.1.0+3`). Android only installs an update with a higher build number.
2. Merge that to `main` and wait for CI to pass.
3. Tag the merge commit and push the tag. The tag drops trailing zeros if you like (`v0.1` is
   version `0.1.0`), but it must match `pubspec.yaml`, or CI stops the release:

   ```bash
   git tag v0.1 origin/main
   git push origin v0.1
   ```

   Or create the release on GitHub (Releases → Draft a new release, new tag `v0.1` on `main`)
   to write the notes yourself.

The tag's CI run builds the APK and attaches it to the `v0.1` release (creating it, with notes
listing the merged pull requests, if it doesn't exist) and marks it as the latest. The tag's Web
run deploys the web app. Friends get the new APK from the same download link; the web app
updates the next time they open it.

### Signing secrets

**Keep your data between updates:** new versions only install over the old one if every build is
signed with the same key. Set these repository secrets once (Settings → Secrets and variables →
Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | your release `.jks` file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `USDA_API_KEY` | free key from [api.data.gov](https://api.data.gov/signup/), used by the APK and web builds (without it they fall back to the shared demo key, ~30 searches an hour). It's readable in the web app's JavaScript; rotate it if it's abused |

Without the signing secrets, CI signs with a throwaway debug key and you'd have to uninstall
(losing your data) to install a newer build. Keep the `.jks` file and passwords backed up outside
the repo.

To try a pull request's build before it's released, open its run on the
[Actions tab](https://github.com/DanielDaCool/nutrition-app/actions) and download the
`nutrition-app-apk` artifact (needs a GitHub login), then copy `app-release.apk` to the phone.

## Data sources

- [Open Food Facts](https://world.openfoodfacts.org): open database (ODbL). Crowd-sourced, so
  values can be wrong. When a product is missing or wrong, add it from its label as your own food.
- [USDA FoodData Central](https://fdc.nal.usda.gov): public domain (CC0).
