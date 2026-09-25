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
    expect(t[3].trendKg, closeTo(89.8, 1e-9));
  });

  test('until extends the series past the last weigh-in', () {
    final t = computeTrend({'2026-09-01': 90.0}, until: '2026-09-03');
    expect(t.length, 3);
    expect(t.last.trendKg, 90.0);
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
