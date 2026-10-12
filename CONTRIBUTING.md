# Contributing

Thanks for taking a look. This is a small personal project, so please open an issue before
starting anything large.

## Setup

Flutter **3.47.5** (Dart 3.13.4). From the repo root:

```bash
flutter pub get
dart run build_runner build   # after changing lib/data/db/tables.dart
flutter analyze               # must be clean
flutter test                  # must pass
```

The project layout and conventions (units, `dayKey` strings, one writer per table, tests with an
in-memory database) are in [README.md](README.md#development).

## Pull requests

- Branch from `main` and keep the change focused.
- Label the PR with exactly one of `feature`, `bug fix`, `design`, `docs`, `ci`.
- Don't add or upgrade packages without asking first.
- A change to `lib/data/db/tables.dart` needs three things: a migration step in
  `AppDatabase.migration`, a matching step in `_upgrade` in
  `lib/features/settings/data_import.dart`, and tests upgrading from every earlier schema version.
- CI must be green: codegen check, analyze and tests.

Releases are cut by the maintainer; see [Releasing a new version](README.md#releasing-a-new-version).
