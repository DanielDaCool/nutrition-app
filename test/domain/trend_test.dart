import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/trend.dart';

void main() {
  test('empty input gives empty trend', () {
    expect(computeTrend({}), isEmpty);
  });

  test('first weigh-in seeds the trend, later ones move it by alpha', () {
    final t = computeTrend({'2026-09-01': 90.0, '2026-09-02': 89.0});
    expect(t.length, 2);
    expect(t[0].trendKg, 90.0);
    expect(t[1].trendKg, closeTo(90.0 + 0.1 * (89.0 - 90.0), 1e-9));
    expect(t[1].scaleKg, 89.0);
  });

  test('missing days carry the trend forward', () {
    final t = computeTrend({'2026-09-01': 90.0, '2026-09-04': 88.0});
    expect(t.map((p) => p.dayKey), [
      '2026-09-01',
      '2026-09-02',
      '2026-09-03',
      '2026-09-04',
    ]);
    expect(t[1].trendKg, 90.0);
    expect(t[2].trendKg, 90.0);
    expect(t[2].scaleKg, isNull);
    // 3 days since the last weigh-in: weight 1 - 0.9^3.
    expect(t[3].trendKg, closeTo(90.0 + (1 - 0.729) * (88.0 - 90.0), 1e-9));
  });

  test('until extends the series past the last weigh-in', () {
    final t = computeTrend({'2026-09-01': 90.0}, until: '2026-09-03');
    expect(t.length, 3);
    expect(t.last.trendKg, 90.0);
  });

  test('until clips off future-dated weigh-ins instead of being ignored', () {
    final t = computeTrend({
      '2026-09-01': 90.0,
      '2026-09-05': 88.0, // after `until` -- e.g. a mis-keyed future day
    }, until: '2026-09-02');
    expect(t.length, 2);
    expect(t.map((p) => p.dayKey), ['2026-09-01', '2026-09-02']);
    expect(t.last.dayKey, '2026-09-02');
  });

  test(
    'a weigh-in after a gap moves the trend as much as the days it spans',
    () {
      // One reading after 3 days equals the daily EMA fed the same value on
      // each of those days.
      final sparse = computeTrend({'2026-09-01': 90.0, '2026-09-04': 88.0});
      final daily = computeTrend({
        '2026-09-01': 90.0,
        '2026-09-02': 88.0,
        '2026-09-03': 88.0,
        '2026-09-04': 88.0,
      });
      expect(sparse.last.trendKg, closeTo(daily.last.trendKg, 1e-9));
    },
  );

  test('weighing every third day tracks a steady loss like daily weighing', () {
    String key(int i) {
      final d = DateTime(2026, 7, 1).add(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final daily = {for (var i = 0; i < 90; i++) key(i): 90.0 - 0.1 * i};
    final sparse = {for (var i = 0; i < 90; i += 3) key(i): 90.0 - 0.1 * i};
    final last = key(87);
    final d = computeTrend(daily, until: last).last.trendKg;
    final s = computeTrend(sparse, until: last).last.trendKg;
    expect((d - s).abs(), lessThan(0.15));
  });

  test('a steady loss is tracked with lag', () {
    final weighIns = <String, double>{};
    for (var i = 0; i < 60; i++) {
      final d = DateTime(2026, 7, 1).add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      weighIns[key] = 90.0 - 0.1 * i; // 0.7 kg/week
    }
    final t = computeTrend(weighIns);
    final slopePerDay = t.last.trendKg - t[t.length - 2].trendKg;
    expect(slopePerDay, closeTo(-0.1, 0.005));
  });
}
