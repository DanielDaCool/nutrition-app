import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/lifting/widgets/lift_set_input.dart';

void main() {
  test('parseLiftReps accepts whole numbers above 0', () {
    expect(parseLiftReps('7'), 7);
    expect(parseLiftReps(' 12 '), 12);
    expect(parseLiftReps('1000'), 1000);
    for (final bad in ['', '0', '-3', '7.5', '7,5', 'abc', '1e2', '1001']) {
      expect(parseLiftReps(bad), isNull, reason: bad);
    }
  });

  test('parseLiftWeightKg accepts "." and "," decimals from 0 up', () {
    expect(parseLiftWeightKg('60'), 60);
    expect(parseLiftWeightKg('62.5'), 62.5);
    expect(parseLiftWeightKg('62,5'), 62.5);
    expect(parseLiftWeightKg(' 0 '), 0);
    expect(parseLiftWeightKg('1000'), 1000);
    for (final bad in ['', '-5', 'abc', '1e3', '6.2.5', '.5', '5.', '1000.5']) {
      expect(parseLiftWeightKg(bad), isNull, reason: bad);
    }
  });

  test('parseLiftWeightKg treats empty as 0 only for bodyweight', () {
    expect(parseLiftWeightKg('', emptyIsZero: true), 0);
    expect(parseLiftWeightKg('  ', emptyIsZero: true), 0);
    expect(parseLiftWeightKg('abc', emptyIsZero: true), isNull);
    expect(parseLiftWeightKg(''), isNull);
  });
}
