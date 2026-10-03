// Registry of the app features a user can switch on or off in
// Settings → Feature hub. Pure Dart: no Flutter, DB or Riverpod imports.

/// True when the app is built with `--dart-define=NEW_FEATURES_OPT_IN=true`:
/// features that are not part of the baseline then start switched off until
/// the user turns them on in the Feature hub.
const bool newFeaturesOptIn = bool.fromEnvironment('NEW_FEATURES_OPT_IN');

/// Whether a feature starts switched on: baseline features always do, later
/// ones unless the build is opt-in ([newFeaturesOptIn]).
bool defaultEnabledFor({required bool baseline, required bool optIn}) =>
    baseline || !optIn;

/// A part of the app that can be switched on or off on this device. A
/// feature the user never touched follows [defaultEnabled].
///
/// To add a feature: add a value here, then gate its UI with
/// `ref.watch(featureEnabledProvider(AppFeature.x))`
/// (`lib/features/settings/feature_flags.dart`). It then shows up in the
/// Feature hub automatically. New features simply omit `baseline`, so they
/// default on in a normal build and off in an opt-in build.
///
/// Only append values, and never rename a [storageKey]: it is what the
/// user's choice is stored under (KeyValues key `feature.<storageKey>`).
enum AppFeature {
  /// The Activity card on Today and the steps and workouts charts on the
  /// Dashboard. Display only: Health Connect syncing, its settings rows, the
  /// home widget and notifications are not affected.
  activity(
    storageKey: 'activity',
    label: 'Steps and workouts',
    description:
        'The activity card on Today and the steps and workouts charts on '
        'the Dashboard.',
    androidOnly: true,
    baseline: true,
  ),

  /// The Recipes tab in the bottom navigation.
  recipes(
    storageKey: 'recipes',
    label: 'Recipes',
    description: 'The Recipes tab in the bottom bar.',
    baseline: true,
  ),

  /// The "Was yesterday complete?" prompt on Today.
  yesterdayPrompt(
    storageKey: 'yesterdayPrompt',
    label: 'Yesterday check',
    description:
        'The "Was yesterday complete?" question on Today that offers to '
        'mark yesterday as fully logged.',
    baseline: true,
  ),

  /// The Scan button in the add-food flow.
  barcodeScan(
    storageKey: 'barcodeScan',
    label: 'Barcode scanning',
    description: 'The Scan button when adding food.',
    baseline: true,
  ),

  /// The "Lose weight / Gain weight" choice in the profile form. While it's
  /// off the profile keeps whatever direction is stored (lose by default).
  gainGoals(
    storageKey: 'gainGoals',
    label: 'Weight gain goals',
    description:
        'The "Lose weight / Gain weight" choice in your profile, for '
        'targets that add weight instead of losing it.',
  );

  const AppFeature({
    required this.storageKey,
    required this.label,
    required this.description,
    this.androidOnly = false,
    this.baseline = false,
  });

  /// Stable id the on/off choice is stored under. Never rename.
  final String storageKey;

  /// Short name shown in the Feature hub.
  final String label;

  /// One sentence saying what the feature shows (and so what switching it
  /// off hides).
  final String description;

  /// True for features that only exist in the Android app.
  final bool androidOnly;

  /// True for the features that existed when the Feature hub was introduced;
  /// they start switched on in every build. Leave it out for new features.
  final bool baseline;

  /// Whether the feature is on until the user chooses otherwise.
  bool get defaultEnabled =>
      defaultEnabledFor(baseline: baseline, optIn: newFeaturesOptIn);

  /// Whether the feature exists at all on this platform.
  bool availableOn({required bool isWeb}) => !(androidOnly && isWeb);
}
