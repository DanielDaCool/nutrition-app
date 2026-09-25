import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/trend.dart';
import 'package:nutrition_app/features/weight/weight_logic.dart';

void main() {
  group('parseWeightKg', () {
    test('accepts dot or comma and rounds to one decimal', () {
      expect(parseWeightKg('82.4'), 82.4);
      expect(parseWeightKg(' 82,4 '), 82.4);
      expect(parseWeightKg('82.46'), 82.5);
      expect(parseWeightKg('90'), 90.0);
    });

    test('rejects empty, junk and out-of-range values', () {
      expect(parseWeightKg(''), isNull);
      expect(parseWeightKg('abc'), isNull);
      expect(parseWeightKg('29.9'), isNull);
      expect(parseWeightKg('300.1'), isNull);
      expect(parseWeightKg('30'), 30.0);
      expect(parseWeightKg('300'), 300.0);
    });

    test('validator messages', () {
      expect(validateWeightKg(''), 'Enter a weight');
      expect(validateWeightKg('12'), contains('between 30 and 300'));
      expect(validateWeightKg('80'), isNull);
    });
  });

  group('trendChangeKg', () {
    test('null without enough history', () {
      expect(trendChangeKg(const [], 7), isNull);
      final trend = computeTrend({'2026-09-20': 80}, until: '2026-09-25');
      expect(trendChangeKg(trend, 7), isNull);
      expect(trendChangeKg(trend, 5), 0);
    });

    test('difference between latest point and N days earlier', () {
      final trend = computeTrend({
        '2026-09-01': 90,
        '2026-09-18': 88,
        '2026-09-25': 87,
      }, until: '2026-09-25');
      final expected = trend.last.trendKg - trend[17].trendKg; // 09-18
      expect(trendChangeKg(trend, 7), closeTo(expected, 1e-9));
      expect(trendChangeKg(trend, 30), isNull);
    });
  });

  test('trendSince filters by day', () {
    final trend = computeTrend({'2026-09-01': 90}, until: '2026-09-10');
    expect(trendSince(trend, '2026-09-08').map((p) => p.dayKey), [
      '2026-09-08',
      '2026-09-09',
      '2026-09-10',
    ]);
    expect(trendSince(trend, null), hasLength(10));
  });

  test('formatChangeKg', () {
    expect(formatChangeKg(-0.84), '−0.8 kg');
    expect(formatChangeKg(0.26), '+0.3 kg');
    expect(formatChangeKg(0.01), '0.0 kg');
  });
}
