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

  test('latestWeighInKg and changeVsPreviousKg', () {
    final w = {'2026-09-20': 84.0, '2026-09-24': 83.1, '2026-09-22': 83.6};
    expect(latestWeighInKg(w), 83.1);
    expect(latestWeighInKg(const {}), isNull);
    expect(changeVsPreviousKg(w, '2026-09-24'), closeTo(-0.5, 1e-9));
    expect(changeVsPreviousKg(w, '2026-09-20'), isNull);
    expect(changeVsPreviousKg(w, '2026-09-21'), isNull);
  });

  test('weighInSummaryLine', () {
    final w = {'2026-09-18': 84.0, '2026-09-25': 82.4};
    final trend = computeTrend(w, until: '2026-09-25');
    // trend: 84.0 until the 25th, then 84 + 0.1 * (82.4 - 84) = 83.84.
    expect(
      weighInSummaryLine(w, trend, '2026-09-25'),
      '82.4 kg · trend 83.8 · −0.2 this week',
    );
    // Not enough history for a weekly change.
    expect(weighInSummaryLine(w, trend, '2026-09-18'), '84.0 kg · trend 84.0');
    expect(weighInSummaryLine(w, trend, '2026-09-20'), isNull);
  });

  test('toGoalText and goalLabel', () {
    expect(toGoalText(81.1, 78), '3.1 kg to goal');
    expect(toGoalText(77.0, 78), '1.0 kg to goal');
    expect(toGoalText(78.04, 78), 'At your goal');
    expect(toGoalText(null, 78), isNull);
    expect(toGoalText(80, null), isNull);
    expect(goalLabel(78), 'Goal 78 kg');
    expect(goalLabel(78.5), 'Goal 78.5 kg');
  });
}
