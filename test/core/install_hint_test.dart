import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/install_hint.dart';

void main() {
  group('isIosUserAgent', () {
    const iphoneUa =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15';
    const ipadUa =
        'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
    const macDesktopUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15';
    const androidUa =
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120';

    test('iPhone and iPad user agents are iOS', () {
      expect(isIosUserAgent(iphoneUa, maxTouchPoints: 0), isTrue);
      expect(isIosUserAgent(ipadUa, maxTouchPoints: 0), isTrue);
    });

    test('iPadOS requesting desktop sites reports as Macintosh with touch', () {
      expect(isIosUserAgent(macDesktopUa, maxTouchPoints: 5), isTrue);
    });

    test('a real Mac reports Macintosh with no touch points', () {
      expect(isIosUserAgent(macDesktopUa, maxTouchPoints: 0), isFalse);
    });

    test('Android is not iOS', () {
      expect(isIosUserAgent(androidUa, maxTouchPoints: 5), isFalse);
    });
  });

  group('shouldShowInstallHint', () {
    final now = DateTime(2026, 10, 6);
    const ios = BrowserInstallInfo(isIos: true, standalone: false);
    const iosStandalone = BrowserInstallInfo(isIos: true, standalone: true);
    const notIos = BrowserInstallInfo(isIos: false, standalone: false);

    test('shows on iOS Safari, never dismissed', () {
      expect(shouldShowInstallHint(ios, dismissedAt: null, now: now), isTrue);
    });

    test('hidden off iOS', () {
      expect(
        shouldShowInstallHint(notIos, dismissedAt: null, now: now),
        isFalse,
      );
    });

    test('hidden once opened from the Home Screen', () {
      expect(
        shouldShowInstallHint(iosStandalone, dismissedAt: null, now: now),
        isFalse,
      );
    });

    test('hidden within 14 days of dismissal', () {
      final dismissedAt = now.subtract(const Duration(days: 13));
      expect(
        shouldShowInstallHint(ios, dismissedAt: dismissedAt, now: now),
        isFalse,
      );
    });

    test('shows again once the snooze has elapsed', () {
      final dismissedAt = now.subtract(const Duration(days: 14));
      expect(
        shouldShowInstallHint(ios, dismissedAt: dismissedAt, now: now),
        isTrue,
      );
    });
  });
}
