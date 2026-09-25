import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/activity/activity_format.dart';

void main() {
  test('readableActivityType', () {
    expect(readableActivityType('STRENGTH_TRAINING'), 'Strength training');
    expect(readableActivityType('ROCK_CLIMBING'), 'Rock climbing');
    expect(readableActivityType('OTHER'), 'Workout');
    expect(readableActivityType(null), 'Workout');
    expect(readableActivityType(''), 'Workout');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 72)), '1 h 12 min');
    expect(formatDuration(const Duration(minutes: 45)), '45 min');
    expect(formatDuration(const Duration(hours: 2)), '2 h');
    expect(formatDuration(const Duration(seconds: -5)), '0 min');
  });

  test('formatSteps', () {
    expect(formatSteps(0), '0');
    expect(formatSteps(999), '999');
    expect(formatSteps(8432), '8,432');
    expect(formatSteps(1234567), '1,234,567');
  });

  test('readableSourceApp', () {
    expect(readableSourceApp('com.hevy'), 'Hevy');
    expect(readableSourceApp('com.unknown'), isNull);
    expect(readableSourceApp(null), isNull);
  });
}
