// Registry of the app features whose UI is gated, so a build can hide them.
// Pure Dart: no Flutter, DB or Riverpod imports.

/// A part of the app whose UI is gated so a build can hide it. In this app
/// every available feature is always on; a fork overrides
/// `featureEnabledProvider` to let the user switch features off.
///
/// To add a feature: add a value here, then wrap its UI in
/// `ref.watch(featureEnabledProvider(AppFeature.x))`
/// (`lib/app/providers.dart`).
///
/// Only append values, and never rename a [storageKey]: builds that store a
/// per-feature choice store it under that id.
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
  ),

  /// The Recipes tab in the bottom navigation.
  recipes(
    storageKey: 'recipes',
    label: 'Recipes',
    description: 'The Recipes tab in the bottom bar.',
  ),

  /// The "Was yesterday complete?" prompt on Today.
  yesterdayPrompt(
    storageKey: 'yesterdayPrompt',
    label: 'Yesterday check',
    description:
        'The "Was yesterday complete?" question on Today that offers to '
        'mark yesterday as fully logged.',
  ),

  /// The Scan button in the add-food flow.
  barcodeScan(
    storageKey: 'barcodeScan',
    label: 'Barcode scanning',
    description: 'The Scan button when adding food.',
  ),

  /// The "Lose weight / Gain weight" choice in the profile form. While it's
  /// off the profile keeps whatever direction is stored (lose by default).
  gainGoals(
    storageKey: 'gainGoals',
    label: 'Weight gain goals',
    description:
        'The "Lose weight / Gain weight" choice in your profile, for '
        'targets that add weight instead of losing it.',
  ),

  /// Export data and Import data in Settings, and Restore from a backup on
  /// first-run setup.
  backup(
    storageKey: 'backup',
    label: 'Backups',
    description:
        'Export data and Import data in Settings, and Restore from a '
        'backup on first-run setup.',
  ),

  /// The "Update available" banner that links to the latest release's APK.
  updateAvailable(
    storageKey: 'updateAvailable',
    label: 'Update available banner',
    description:
        'The banner telling you a newer version is out, with a link to '
        'download it.',
    androidOnly: true,
  );

  const AppFeature({
    required this.storageKey,
    required this.label,
    required this.description,
    this.androidOnly = false,
  });

  /// Stable id of the feature. Never rename.
  final String storageKey;

  /// Short name of the feature.
  final String label;

  /// One sentence saying what the feature shows (and so what hiding it
  /// removes).
  final String description;

  /// True for features that only exist in the Android app.
  final bool androidOnly;

  /// Whether the feature exists at all on this platform.
  bool availableOn({required bool isWeb}) => !(androidOnly && isWeb);
}
