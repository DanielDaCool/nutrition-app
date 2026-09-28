/// Abstraction over Health Connect so the sync logic can be tested with a
/// fake. The real implementation is `HealthPackageSource`.
library;

/// Whether Health Connect can be used on this phone.
enum HcAvailability {
  /// Installed (or built into Android 14+) and ready.
  available,

  /// Not installed (Android 13 and older).
  notInstalled,

  /// Installed but too old for this app; needs an update from the Play Store.
  updateRequired,

  /// Not an Android device (e.g. tests, desktop) or status unknown.
  unsupported,
}

/// One exercise session as read from Health Connect.
class HcWorkout {
  const HcWorkout({
    required this.id,
    required this.start,
    required this.end,
    required this.activityType,
    this.title,
    this.sourceApp,
    this.kcal,
  });

  /// Health Connect record id (metadata.id), stable across reads.
  final String id;
  final DateTime start;
  final DateTime end;

  /// Exercise type name as the `health` package spells it,
  /// e.g. 'STRENGTH_TRAINING'.
  final String activityType;

  /// Session title written by the source app (e.g. Hevy's 'Chest and back'),
  /// when the plugin exposes it. `health` 13.3.x does not, so this is null.
  final String? title;

  /// Package name of the app that wrote the record, e.g. 'com.hevy'.
  final String? sourceApp;

  /// Energy burned during the session, when available.
  final double? kcal;
}

/// Read-only access to Health Connect. Methods other than the read calls may
/// throw platform errors; callers (`HealthSyncService`) catch them.
abstract interface class HealthSource {
  /// Whether Health Connect is installed and usable on this phone.
  Future<HcAvailability> availability();

  /// True when read access to steps and exercise sessions is granted.
  Future<bool> hasPermissions();

  /// Shows the Health Connect permission screen for steps + exercise (read).
  Future<bool> requestPermissions();

  /// Whether the "read data older than 30 days" feature exists on this phone.
  Future<bool> isHistoryAvailable();
  /// Whether the history permission has been granted.
  Future<bool> isHistoryAuthorized();
  /// Shows the history permission screen; true when granted.
  Future<bool> requestHistoryAuthorization();

  /// Total steps in [start, end). Null when the read failed.
  Future<int?> totalSteps(DateTime start, DateTime end);

  /// Total active-energy calories burned in [start, end). Null when the read
  /// failed.
  Future<double?> totalActiveCalories(DateTime start, DateTime end);

  /// Exercise sessions overlapping [start, end).
  Future<List<HcWorkout>> workouts(DateTime start, DateTime end);

  /// Opens the Play Store page to install or update Health Connect.
  Future<void> installHealthConnect();
}
