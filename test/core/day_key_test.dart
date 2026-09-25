import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/day_key.dart';

void main() {
  test('dayKeyOf pads month and day', () {
    expect(dayKeyOf(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
  });

  test('addDays crosses month and year boundaries', () {
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(addDays('2026-03-01', -1), '2026-02-28');
    expect(addDays('2028-03-01', -1), '2028-02-29');
  });

  test('daysBetween counts calendar days', () {
    expect(daysBetween('2026-09-01', '2026-09-25'), 24);
    expect(daysBetween('2026-09-25', '2026-09-01'), -24);
    // Across the Israeli DST change (last Sunday of October).
    expect(daysBetween('2026-10-20', '2026-10-30'), 10);
  });

  test('startOfDay/endOfDay bracket the day', () {
    expect(startOfDay('2026-09-25'), DateTime(2026, 9, 25));
    expect(endOfDay('2026-09-25'), DateTime(2026, 9, 26));
  });
}
