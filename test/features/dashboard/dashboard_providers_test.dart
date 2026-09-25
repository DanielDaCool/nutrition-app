import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/dashboard/dashboard_providers.dart';

import '../../helpers/test_db.dart';
import '../weight/provider_wait.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 20)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> addTarget(String from, double kcal, double maintenance) => db
      .into(db.targetHistory)
      .insert(
        TargetHistoryCompanion.insert(
          effectiveFrom: from,
          kcal: kcal,
          proteinG: 150,
          fatG: 70,
          carbsG: 200,
          maintenanceKcal: maintenance,
          method: 0,
          createdAt: DateTime(2026, 9, 25),
        ),
      );

  test('fixed ranges end today', () async {
    expect(await waitFor(container, dashboardWindowProvider, (_) => true), (
      '2026-08-29',
      '2026-09-25',
    ));
    container.read(dashboardRangeProvider.notifier).set(DashboardRange.weeks12);
    expect(
      await waitFor(
        container,
        dashboardWindowProvider,
        (w) => w.$1 != '2026-08-29',
      ),
      ('2026-07-04', '2026-09-25'),
    );
  });

  test('"all" starts at the earliest data, at least 4 weeks back', () async {
    container.read(dashboardRangeProvider.notifier).set(DashboardRange.all);
    expect(await waitFor(container, dashboardWindowProvider, (_) => true), (
      '2026-08-29',
      '2026-09-25',
    ));

    await db
        .into(db.weighIns)
        .insert(
          WeighInsCompanion.insert(
            dayKey: '2026-03-02',
            weightKg: 90,
            createdAt: DateTime(2026, 3, 2),
          ),
        );
    await addTarget('2026-02-15', 2200, 2700);
    expect(
      await waitFor(
        container,
        dashboardWindowProvider,
        (w) => w.$1 == '2026-02-15',
      ),
      ('2026-02-15', '2026-09-25'),
    );
  });

  test('targetHistoryProvider is ordered and updates live', () async {
    expect(
      await waitFor(container, targetHistoryProvider, (_) => true),
      isEmpty,
    );
    await addTarget('2026-09-14', 2000, 2500);
    await addTarget('2026-09-01', 2100, 2600);
    final list = await waitFor(
      container,
      targetHistoryProvider,
      (l) => l.length == 2,
    );
    expect(list.map((t) => t.effectiveFrom), ['2026-09-01', '2026-09-14']);
    expect(list.last.maintenanceKcal, 2500);
  });
}
