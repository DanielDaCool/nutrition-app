// When to suggest adding the web app to the iPhone Home Screen. Safari may
// delete a website's storage after about a week without a visit, and the web
// app's whole database lives there; an app on the Home Screen keeps it.
// Pure Dart: no Flutter, DB or browser imports.

/// How the app is running, as far as the browser says.
class BrowserInstallInfo {
  const BrowserInstallInfo({required this.isIos, required this.standalone});

  /// Off the web, and anywhere the hint doesn't apply.
  static const notApplicable = BrowserInstallInfo(
    isIos: false,
    standalone: false,
  );

  /// iPhone, iPad or iPod, in any browser (all of them use Safari's engine
  /// and storage rules on iOS).
  final bool isIos;

  /// Opened from the Home Screen rather than in a browser tab.
  final bool standalone;
}

/// Whether [userAgent] is an iOS device. iPadOS asks for desktop sites and
/// says "Macintosh", so a Mac with a touch screen counts too (real Macs
/// report no touch points).
bool isIosUserAgent(String userAgent, {required int maxTouchPoints}) =>
    RegExp('iPhone|iPad|iPod').hasMatch(userAgent) ||
    (userAgent.contains('Macintosh') && maxTouchPoints > 1);

/// "Not now" hides the hint for this long.
const installHintSnooze = Duration(days: 14);

/// KeyValues key: when the hint was last dismissed (UTC ISO-8601).
const installHintDismissedAtKey = 'app.installHintDismissedAt';

/// Whether to show the hint now.
bool shouldShowInstallHint(
  BrowserInstallInfo info, {
  required DateTime? dismissedAt,
  required DateTime now,
}) {
  if (!info.isIos || info.standalone) return false;
  return dismissedAt == null ||
      now.difference(dismissedAt) >= installHintSnooze;
}
