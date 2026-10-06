import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/update_check.dart';

void main() {
  group('parseReleaseTag', () {
    test('a two-part tag reads patch as 0', () {
      expect(parseReleaseTag('v0.1'), const ReleaseVersion(0, 1, 0));
    });

    test('a three-part tag', () {
      expect(parseReleaseTag('v1.2.3'), const ReleaseVersion(1, 2, 3));
    });

    test('a one-part tag reads minor and patch as 0', () {
      expect(parseReleaseTag('v2'), const ReleaseVersion(2, 0, 0));
    });

    test('not a version tag', () {
      expect(parseReleaseTag('latest'), isNull);
      expect(parseReleaseTag('v1.2.3.4'), isNull);
      expect(parseReleaseTag('v1.x'), isNull);
    });
  });

  group('parseAppVersion', () {
    test('drops the build number', () {
      expect(parseAppVersion('0.0.0+2'), const ReleaseVersion(0, 0, 0));
      expect(parseAppVersion('1.2.3+45'), const ReleaseVersion(1, 2, 3));
    });
  });

  group('isUpdateAvailable', () {
    test('true when the tag is newer', () {
      expect(
        isUpdateAvailable(currentVersion: '0.0.0+2', latestTag: 'v0.1'),
        isTrue,
      );
    });

    test('false when the tag matches', () {
      expect(
        isUpdateAvailable(currentVersion: '0.1.0+1', latestTag: 'v0.1'),
        isFalse,
      );
    });

    test('false when the tag is older', () {
      expect(
        isUpdateAvailable(currentVersion: '0.2.0+1', latestTag: 'v0.1'),
        isFalse,
      );
    });

    test('false for a dev build with no baked-in version', () {
      expect(
        isUpdateAvailable(currentVersion: '', latestTag: 'v0.1'),
        isFalse,
      );
    });

    test('false when there is no latest tag yet', () {
      expect(
        isUpdateAvailable(currentVersion: '0.0.0+2', latestTag: null),
        isFalse,
      );
    });

    test('false when the tag does not parse', () {
      expect(
        isUpdateAvailable(currentVersion: '0.0.0+2', latestTag: 'latest'),
        isFalse,
      );
    });
  });

  group('shouldCheckForUpdate', () {
    final now = DateTime(2026, 10, 6);

    test('true when never checked', () {
      expect(shouldCheckForUpdate(lastCheckedAt: null, now: now), isTrue);
    });

    test('false within a day', () {
      expect(
        shouldCheckForUpdate(
          lastCheckedAt: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
    });

    test('true a day or more later', () {
      expect(
        shouldCheckForUpdate(
          lastCheckedAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
