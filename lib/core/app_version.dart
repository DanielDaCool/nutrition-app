// The app's version, baked in at build time. Pure Dart: no Flutter imports.

/// pubspec.yaml's `version:` (e.g. "0.0.0+2"), passed by CI with
/// `--dart-define=APP_VERSION=...` (.github/scripts/app-version.sh). Empty
/// in local builds that don't pass it.
const appVersion = String.fromEnvironment('APP_VERSION');

/// How [raw] reads to a person: "0.0.0 (build 2)", or "Development build"
/// when the build didn't say.
String appVersionLabel(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return 'Development build';
  final plus = v.indexOf('+');
  if (plus < 0) return v;
  return '${v.substring(0, plus)} (build ${v.substring(plus + 1)})';
}
