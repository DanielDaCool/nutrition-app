import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/lifting_format.dart';

void main() {
  test('weights drop a trailing .0', () {
    expect(formatLiftKg(60), '60');
    expect(formatLiftKg(62.5), '62.5');
    expect(formatLiftKg(1.25), '1.25');
    expect(formatLiftKg(0), '0');
    expect(formatLiftKg(100), '100');
  });

  test('bodyweight exercises show only the extra weight', () {
    expect(formatLiftWeight(60, isBodyweight: false), '60 kg');
    expect(formatLiftWeight(0, isBodyweight: false), '0 kg');
    expect(formatLiftWeight(0, isBodyweight: true), 'BW');
    expect(formatLiftWeight(20, isBodyweight: true), 'BW + 20 kg');
  });

  test('sets list every set in order', () {
    const sets = [
      LiftSet(id: 1, reps: 7, weightKg: 60),
      LiftSet(id: 2, reps: 4, weightKg: 60),
      LiftSet(id: 3, reps: 6, weightKg: 57.5),
    ];
    expect(formatLiftSet(sets.first, isBodyweight: false), '60 kg × 7');
    expect(
      formatLiftSets(sets, isBodyweight: false),
      '60 kg × 7 · 60 kg × 4 · 57.5 kg × 6',
    );
    expect(
      formatLiftSets(const [
        LiftSet(id: 1, reps: 8, weightKg: 0),
        LiftSet(id: 2, reps: 6, weightKg: 20),
      ], isBodyweight: true),
      'BW × 8 · BW + 20 kg × 6',
    );
  });
}
