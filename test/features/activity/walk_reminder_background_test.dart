import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/activity/walk_reminder_background.dart';

void main() {
  group('sendWalkReminderIfMarkedSent', () {
    test('marks sent before notifying', () async {
      final calls = <String>[];
      await sendWalkReminderIfMarkedSent(
        markSent: () async => calls.add('markSent'),
        notify: () async => calls.add('notify'),
      );
      expect(calls, ['markSent', 'notify']);
    });

    test('a failed write skips the notification, not the other way around', () async {
      var notified = false;
      await expectLater(
        sendWalkReminderIfMarkedSent(
          markSent: () async => throw StateError('SQLITE_BUSY'),
          notify: () async => notified = true,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        notified,
        isFalse,
        reason:
            'the notification must not show when recording it as sent failed, '
            'or it could fire again on the next run even though the user '
            'already saw it',
      );
    });
  });
}
