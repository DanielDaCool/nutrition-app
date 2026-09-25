import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
import 'package:nutrition_app/features/food/widgets/food_format.dart';

void main() {
  group('friendlyError', () {
    test('API errors show their own message', () {
      expect(
        friendlyError(
          const FoodApiException(FoodApiErrorKind.network, 'No internet.'),
        ),
        'No internet.',
      );
    });

    test('bad amounts ask for an amount above 0', () {
      expect(
        friendlyError(ArgumentError.value(0.0, 'grams', 'must be > 0')),
        'Enter an amount above 0',
      );
    });

    test('anything else is short and hides the details', () {
      final text = friendlyError(StateError('SqliteException(1): no table'));
      expect(text, 'Something went wrong. Try again.');
      expect(text, isNot(contains('Sqlite')));
    });
  });

  group('otherDayLabel / withDay', () {
    test('today has no label, neighbours are named, others are dated', () {
      expect(otherDayLabel('2026-09-25', '2026-09-25'), isNull);
      expect(otherDayLabel('2026-09-24', '2026-09-25'), 'Yesterday');
      expect(otherDayLabel('2026-09-26', '2026-09-25'), 'Tomorrow');
      expect(otherDayLabel('2026-09-23', '2026-09-25'), 'Wed 23 Sep');
    });

    test('withDay appends the day only when it is not today', () {
      expect(
        withDay('Add to Breakfast', '2026-09-25', '2026-09-25'),
        'Add to Breakfast',
      );
      expect(
        withDay('Add to Breakfast', '2026-09-24', '2026-09-25'),
        'Add to Breakfast · Yesterday',
      );
    });
  });
}
