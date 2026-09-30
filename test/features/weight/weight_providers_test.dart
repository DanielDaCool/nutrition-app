import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/weight/weight_providers.dart';

import '../../helpers/test_db.dart';
import 'provider_wait.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 9, 25, 9, 30);

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('weighInsProvider starts empty and follows upserts/deletes', () async {
    expect(await waitFor(container, weighInsProvider, (_) => true), isEmpty);

    final repo = container.read(weightRepositoryProvider);
    await repo.upsert('2026-09-20', 90.0);
    await repo.upsert('2026-09-22', 89.4);
    var map = await waitFor(container, weighInsProvider, (m) => m.length == 2);
    expect(map, {'2026-09-20': 90.0, '2026-09-22': 89.4});

    // One weigh-in per day: a second upsert replaces the first.
    await repo.upsert('2026-09-22', 89.0);
    map = await waitFor(
      container,
      weighInsProvider,
      (m) => m['2026-09-22'] == 89.0,
    );
    expect(map.length, 2);

    await repo.delete('2026-09-20');
    map = await waitFor(container, weighInsProvider, (m) => m.length == 1);
    expect(map.keys, ['2026-09-22']);
  });

  test('replace moves a weigh-in to another day', () async {
    final repo = container.read(weightRepositoryProvider);
    await repo.upsert('2026-09-20', 90.0);
    await repo.replace('2026-09-20', '2026-09-21', 89.5);
    final rows = await db.select(db.weighIns).get();
    expect(rows.single.dayKey, '2026-09-21');
    expect(rows.single.weightKg, 89.5);
    expect(rows.single.createdAt, now);
  });

  test('weightTrendProvider runs through today (pinned clock)', () async {
    final repo = container.read(weightRepositoryProvider);
    await repo.upsert('2026-09-20', 90.0);
    await repo.upsert('2026-09-22', 89.0);

    final trend = await waitFor(
      container,
      weightTrendProvider,
      (t) => t.any((p) => p.scaleKg == 89.0),
    );
    expect(trend.first.dayKey, '2026-09-20');
    expect(trend.last.dayKey, '2026-09-25');
    expect(trend, hasLength(6));
    expect(trend[2].trendKg, closeTo(90.0 + 0.1 * (89.0 - 90.0), 1e-9));
    expect(trend.last.trendKg, trend[2].trendKg);
    expect(trend.last.scaleKg, isNull);
  });

  test('weightTrendProvider is empty without weigh-ins', () async {
    expect(await waitFor(container, weightTrendProvider, (_) => true), isEmpty);
  });

  test('restore on the same day is one write, not delete-then-insert', () async {
    final repo = container.read(weightRepositoryProvider);
    await repo.upsert('2026-09-22', 89.0);

    // Watch every emission of the watched table between the two calls: a
    // buggy delete-then-upsert would emit an intermediate map without
    // '2026-09-22' before the real value comes back.
    final seen = <Map<String, double>>[];
    final sub = repo.watchAll().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    seen.clear();

    await repo.restore(dayKey: '2026-09-22', weightKg: 88.5);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, isNotEmpty);
    for (final m in seen) {
      expect(m.containsKey('2026-09-22'), isTrue);
    }
    expect(seen.last['2026-09-22'], 88.5);
  });

  test('restore with null weightKg removes the day (nothing to restore)', () async {
    final repo = container.read(weightRepositoryProvider);
    await repo.upsert('2026-09-22', 89.0);
    await repo.restore(dayKey: '2026-09-22', weightKg: null);
    final rows = await db.select(db.weighIns).get();
    expect(rows, isEmpty);
  });

  test('restore also restores a moved day, atomically', () async {
    final repo = container.read(weightRepositoryProvider);
    await repo.replace('2026-09-20', '2026-09-21', 89.5); // day was empty

    await repo.restore(
      dayKey: '2026-09-21',
      weightKg: null, // nothing was on 09-21 before the move
      oldDayKey: '2026-09-20',
      oldWeightKg: 90.0, // what 09-20 held before the move
    );
    final rows = {
      for (final r in await db.select(db.weighIns).get()) r.dayKey: r.weightKg,
    };
    expect(rows, {'2026-09-20': 90.0});
  });
}
