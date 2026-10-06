// App-wide Riverpod providers shared by all features: database, clock,
// platform, feature gates and the day selected on the Today screen.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/app_features.dart';
import '../core/app_version.dart';
import '../core/browser_install.dart';
import '../core/day_key.dart';
import '../core/install_hint.dart';
import '../core/install_hint_repository.dart';
import '../core/update_check.dart';
import '../core/update_check_repository.dart';
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

/// HTTP client for the update check; override with a `MockClient` in tests.
final updateCheckClientProvider = Provider<http.Client>((ref) => http.Client());

/// The app's own version ([appVersion]); override in tests, since a test
/// run has no `APP_VERSION` dart-define and so always sees a dev build.
final appVersionProvider = Provider<String>((ref) => appVersion);

/// The latest release tag on GitHub, checked at most once a day. Null if
/// it's never been fetched successfully. Disabled on web (see
/// [AppFeature.updateAvailable]), where nothing is ever checked.
final latestReleaseTagProvider = FutureProvider<String?>((ref) {
  if (!ref.watch(featureEnabledProvider(AppFeature.updateAvailable))) {
    return null;
  }
  return latestReleaseTag(
    ref.watch(databaseProvider),
    ref.watch(updateCheckClientProvider),
    ref.watch(clockProvider)(),
  );
});

/// The tag this device has already dismissed the update banner for.
final updateDismissedTagProvider =
    AsyncNotifierProvider<UpdateDismissedTagController, String?>(
      UpdateDismissedTagController.new,
    );

/// Holds the dismissed tag; [dismiss] persists it so the banner doesn't
/// show again for that same release.
class UpdateDismissedTagController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() =>
      loadUpdateDismissedTag(ref.watch(databaseProvider));

  Future<void> dismiss(String tag) async {
    await saveUpdateDismissedTag(ref.read(databaseProvider), tag);
    state = AsyncData(tag);
  }
}

/// The release tag to show the "Update available" banner for, or null to
/// keep it hidden: there's a newer release than [appVersion] and this
/// device hasn't already dismissed it. Null while either lookup is still
/// loading, so the banner never flashes on for one frame.
final updateAvailableTagProvider = Provider<String?>((ref) {
  final latest = ref.watch(latestReleaseTagProvider);
  final dismissed = ref.watch(updateDismissedTagProvider);
  if (latest.isLoading || dismissed.isLoading) return null;
  final tag = latest.value;
  if (tag == null) return null;
  if (!isUpdateAvailable(
    currentVersion: ref.watch(appVersionProvider),
    latestTag: tag,
  )) {
    return null;
  }
  return tag == dismissed.value ? null : tag;
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
