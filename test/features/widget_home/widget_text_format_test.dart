import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/widget_home/widget_text_format.dart';

void main() {
  group('formatKcalLeftText', () {
    test('no target yet shows a setup placeholder', () {
      expect(
        formatKcalLeftText(targetKcal: null, loggedKcal: 400),
        'Set up your targets',
      );
    });

    test('nothing logged yet treats logged as zero', () {
      expect(
        formatKcalLeftText(targetKcal: 2000, loggedKcal: null),
        '2,000 kcal left',
      );
    });

    test('remaining budget uses thousands separators', () {
      expect(
        formatKcalLeftText(targetKcal: 2500, loggedKcal: 1050),
        '1,450 kcal left',
      );
    });

    test('exactly at target shows zero left', () {
      expect(
        formatKcalLeftText(targetKcal: 2000, loggedKcal: 2000),
        '0 kcal left',
      );
    });

    test('over target shows "over" instead of a negative number', () {
      expect(
        formatKcalLeftText(targetKcal: 2000, loggedKcal: 2320),
        '320 kcal over',
      );
    });

    test('large over-target value uses thousands separators', () {
      expect(
        formatKcalLeftText(targetKcal: 1800, loggedKcal: 3250),
        '1,450 kcal over',
      );
    });
  });

  group('formatStepsText', () {
    test('no step data yet', () {
      expect(formatStepsText(null), 'No step data');
    });

    test('zero steps', () {
      expect(formatStepsText(0), '0 steps');
    });

    test('small step count', () {
      expect(formatStepsText(432), '432 steps');
    });

    test('thousands separator', () {
      expect(formatStepsText(8432), '8,432 steps');
    });

    test('large step count', () {
      expect(formatStepsText(123456), '123,456 steps');
    });
  });
}
