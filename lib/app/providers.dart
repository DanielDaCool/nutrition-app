// App-wide Riverpod providers shared by all features: database, clock,
// platform, feature gates and the day selected on the Today screen.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_features.dart';
import '../core/browser_install.dart';
import '../core/day_key.dart';
import '../core/install_hint.dart';
import '../core/install_hint_repository.dart';
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

/// How the web app is running (iOS? opened from the Home Screen?), read once
/// at start. Always "not applicable" off the web; override in tests.
final browserInstallInfoProvider = Provider<BrowserInstallInfo>(
  (ref) => readBrowserInstallInfo(),
);

/// Whether an [AppFeature]'s UI should show. Here that is simply "exists on
/// this platform"; it can be overridden (a fork does) to add user choice.
final featureEnabledProvider = Provider.family<bool, AppFeature>(
  (ref, feature) => feature.availableOn(isWeb: ref.watch(isWebProvider)),
);

/// When the "Add to Home Screen" hint was last dismissed, loaded from
/// KeyValues.
final installHintDismissedAtProvider =
    AsyncNotifierProvider<InstallHintDismissedAtController, DateTime?>(
      InstallHintDismissedAtController.new,
    );

/// Holds the install hint's dismissal timestamp; [dismiss] persists "now"
/// and snoozes the hint.
class InstallHintDismissedAtController extends AsyncNotifier<DateTime?> {
  @override
  FutureOr<DateTime?> build() =>
      loadInstallHintDismissedAt(ref.watch(databaseProvider));

  Future<void> dismiss() async {
    final now = ref.read(clockProvider)();
    await saveInstallHintDismissedAt(ref.read(databaseProvider), now);
    state = AsyncData(now);
  }
}

/// Whether the "Add to Home Screen" banner should show right now: on iPhone
/// Safari, not opened from the Home Screen already, and not snoozed. False
/// while the dismissal timestamp is still loading, so the banner never
/// flashes on for one frame.
final showInstallHintProvider = Provider<bool>((ref) {
  if (!ref.watch(featureEnabledProvider(AppFeature.installHint))) {
    return false;
  }
  final dismissedAt = ref.watch(installHintDismissedAtProvider);
  if (dismissedAt.isLoading) return false;
  return shouldShowInstallHint(
    ref.watch(browserInstallInfoProvider),
    dismissedAt: dismissedAt.value,
    now: ref.watch(clockProvider)(),
  );
});

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
