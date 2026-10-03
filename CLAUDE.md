# Nutrition App — project guide

Personal Android app (single user, no login) for food logging, daily weigh-ins,
adaptive calorie/macro targets, and steps + workouts from Health Connect.
Plan of record: `docs/plan.md`. Calorie engine spec: `docs/engine.md`.

## Stack (pinned)
- Flutter 3.47.5 / Dart 3.13.4, Android only (minSdk 26).
- State: flutter_riverpod 3.x, plain providers (no codegen).
- DB: Drift 2.35 on SQLite (`lib/data/db/`), generated code is committed.
- Health: `health` 13.x (Health Connect). Barcode: `mobile_scanner`. Charts: `fl_chart`.
- Don't add or upgrade packages without the lead's approval.

## Commands
```
flutter pub get
dart run build_runner build      # after changing lib/data/db/tables.dart
flutter analyze                  # must be clean
flutter test                     # must pass
flutter build apk --release      # CI only (Android SDK isn't available in the cloud sandbox)
```
CI (`.github/workflows/ci.yml`) runs codegen check, analyze, test, and builds an APK artifact.

## Conventions
- Days are `dayKey` strings `YYYY-MM-DD` in local time (`lib/core/day_key.dart`). Never store a day as DateTime.
- Units: kg, grams, kcal. Food nutrition is per 100 g. Name variables with units (`weightKg`, `kcalPer100g`).
- Enum columns store `.index`; only append to enums in `lib/domain/models.dart`.
- Features talk through the contract types in `lib/domain/models.dart` and the providers/widgets named below. Any feature may read any table; each table has one writer (below).
- Get the DB via `ref.watch(databaseProvider)`; "now" via `ref.read(clockProvider)()` so tests can pin time.
- Tests: in-memory DB via `test/helpers/test_db.dart`. HTTP via `package:http/testing.dart` `MockClient`. No real network in tests.
- Pure logic (math, parsing) lives in plain Dart files with no Flutter/DB imports, so it's unit-testable.
- UI: Material 3, English. Keep screens simple; show loading and error states from `AsyncValue`.
- New user-facing features get an `AppFeature` value in `lib/core/app_features.dart` and gate their UI with `ref.watch(featureEnabledProvider(AppFeature.x))` (`lib/features/settings/feature_flags.dart`), so they can be switched off in Settings → Feature hub. New features omit `baseline` (on by default; off by default in a `--dart-define=NEW_FEATURES_OPT_IN=true` build).

## Ownership (parallel work)
| Area | Owner | Files | Writes tables |
|---|---|---|---|
| Shared core | lead | `pubspec.yaml`, `lib/main.dart`, `lib/app/**`, `lib/core/**`, `lib/domain/**`, `lib/data/**`, `android/**`, `.github/**`, `test/helpers/**` | — |
| A. Calorie engine, check-in, settings | engine agent | `lib/features/targets/**`, `lib/features/settings/**`, `test/features/targets/**`, `test/features/settings/**` | Profiles, TargetHistory, KeyValues (keys prefixed `feature.`) |
| B. Food logging | food agent | `lib/features/food/**`, `test/features/food/**` | Foods, FoodLogEntries, SavedMeals, SavedMealItems, DayStatuses, KeyValues (keys prefixed `describe.`) |
| C. Health Connect | health agent | `lib/features/activity/**`, `test/features/activity/**` | DailySteps, Workouts, KeyValues (keys prefixed `hc.`) |
| D. Weight, Today, Dashboard | charts agent | `lib/features/weight/**`, `lib/features/today/**`, `lib/features/dashboard/**`, `test/features/{weight,today,dashboard}/**` | WeighIns |

Contract names (keep them; replace stub bodies):
- A: `currentTargetsProvider`, `checkInDueProvider`, `CheckInScreen`, `SettingsScreen`
- B: `dayIntakeProvider(dayKey)`, `intakeRangeProvider((from, to))`, `MealsSection(dayKey:)`
- C: `dayActivityProvider(dayKey)`, `activityRangeProvider((from, to))`, `healthSyncProvider` (`syncNow()`), `ActivityCard(dayKey:)`, `HealthConnectSettingsTile()`
- D: `weighInsProvider`, `weightTrendProvider`, `TodayScreen`, `WeightScreen`, `DashboardScreen`

Need a change in a file you don't own (schema, pubspec, manifest, contracts)? Don't edit it: report what and why to the lead.
