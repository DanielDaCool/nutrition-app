import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/targets_repository.dart';

import '../../helpers/test_db.dart';

final friday = DateTime(2026, 9, 25, 9);

Future<TargetsRepository> seeded(AppDatabase db) async {
  final repo = TargetsRepository(db, () => friday);
  await repo.saveProfile(
    sex: Sex.male,
    birthDate: DateTime(1996, 9, 25),
    heightCm: 180,
    activityLevel: ActivityLevel.moderate,
    goalWeightKg: 80,
    weeklyRatePct: 0.5,
    proteinPerKg: 2.0,
    checkInWeekday: 7,
    goalDirection: GoalDirection.lose,
  );
  await db
      .into(db.weighIns)
      .insert(
        WeighInsCompanion.insert(
          dayKey: dayKeyOf(friday),
          weightKg: 90,
          createdAt: friday,
        ),
      );
  await repo.currentTargets(); // creates the first formula target
  return repo;
}

void main() {
  test('setManualCalories overrides kcal, keeps protein, fills carbs', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = await seeded(db);
    final auto = (await repo.currentTargets())!;

    expect(await repo.setManualCalories(2300), isTrue);
    final t = (await repo.currentTargets())!;
    expect(t.method, TargetMethod.manual);
    expect(t.macros.kcal, 2300);
    expect(t.macros.proteinG, auto.macros.proteinG);
    expect(t.maintenanceKcal, auto.maintenanceKcal);
    final macroKcal =
        t.macros.proteinG * 4 + t.macros.fatG * 9 + t.macros.carbsG * 4;
    expect(macroKcal, closeTo(2300, 25));
  });

  test('useAutomaticTarget restores the engine target', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = await seeded(db);
    final auto = (await repo.currentTargets())!;
    await repo.setManualCalories(1800);

    expect(await repo.useAutomaticTarget(), isTrue);
    final t = (await repo.currentTargets())!;
    expect(t.method, isNot(TargetMethod.manual));
    expect(t.macros.kcal, auto.macros.kcal);
  });

  test('skipping a check-in keeps the manual target', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = await seeded(db);
    await repo.setManualCalories(2100);
    final sunday = DateTime(2026, 9, 27, 9);
    final later = TargetsRepository(db, () => sunday);
    await later.keepCurrentTarget();
    final t = (await later.currentTargets())!;
    expect(t.method, TargetMethod.manual);
    expect(t.macros.kcal, 2100);
  });

  test('without a profile there is nothing to override', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = TargetsRepository(db, () => friday);
    expect(await repo.setManualCalories(2000), isFalse);
    expect(await repo.useAutomaticTarget(), isFalse);
  });

  test('manual macros follow a new weigh-in and profile, kcal stays', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = await seeded(db);
    await repo.setManualCalories(2300);
    final before = (await repo.currentTargets())!;

    await repo.saveProfile(
      sex: Sex.male,
      birthDate: DateTime(1996, 9, 25),
      heightCm: 180,
      activityLevel: ActivityLevel.moderate,
      goalWeightKg: 80,
      weeklyRatePct: 0.5,
      proteinPerKg: 2.5,
      checkInWeekday: 7,
      goalDirection: GoalDirection.lose,
    );
    final after = (await repo.currentTargets())!;
    expect(after.method, TargetMethod.manual);
    expect(after.macros.kcal, 2300);
    expect(after.macros.proteinG, greaterThan(before.macros.proteinG));
  });
}
