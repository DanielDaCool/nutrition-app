// App-wide Riverpod providers shared by all features: database, clock,
// platform, feature gates and the day selected on the Today screen.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_features.dart';
import '../core/day_key.dart';
import '../data/db/database.dart';

/// The app database. Overridden in main() (real file) and in tests (in-memory).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Current time source; override in tests to pin "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// True in the web build. Android-only features (Health Connect, the home
/// widget, lock-screen notification, walk reminders, file export) hide
/// themselves when set; override in tests to check the web layout.
final isWebProvider = Provider<bool>((ref) => kIsWeb);

/// Whether an [AppFeature]'s UI should show. Here that is simply "exists on
/// this platform"; it can be overridden (a fork does) to add user choice.
final featureEnabledProvider = Provider.family<bool, AppFeature>(
  (ref, feature) => feature.availableOn(isWeb: ref.watch(isWebProvider)),
);

/// The day shown on the Today screen (defaults to today; user can browse back).
final selectedDayProvider = NotifierProvider<SelectedDay, String>(
  SelectedDay.new,
);

/// Holds the selected day key; starts at today per [clockProvider].
class SelectedDay extends Notifier<String> {
  @override
  String build() => dayKeyOf(ref.read(clockProvider)());

  /// Selects [dayKey] (a `YYYY-MM-DD` day key).
  void set(String dayKey) => state = dayKey;

  /// Jumps back to today.
  void today() => state = dayKeyOf(ref.read(clockProvider)());
}
