import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/today/close_day_logic.dart';

void main() {
  const todayKey = '2026-09-25';

  DayIntake intake({double kcal = 1500, bool logged = false}) => DayIntake(
    dayKey: todayKey,
    total: Macros(kcal: kcal, proteinG: 0, fatG: 0, carbsG: 0),
    byMeal: const {},
    fullyLogged: logged,
  );

  bool show({
    DateTime? now,
    DayIntake? today,
    String? dismissedOn,
    bool noToday = false,
  }) => showCloseDay(
    now: now ?? DateTime(2026, 9, 25, 20),
    todayKey: todayKey,
    today: noToday ? null : (today ?? intake()),
    dismissedOn: dismissedOn,
  );

  test('shows in the evening when there is food and it is not complete', () {
    expect(show(), isTrue);
  });

  test('hour boundary: 18:59 hides, 19:00 shows', () {
    expect(show(now: DateTime(2026, 9, 25, 18, 59)), isFalse);
    expect(show(now: DateTime(2026, 9, 25, 19)), isTrue);
    expect(show(now: DateTime(2026, 9, 25, 23, 59)), isTrue);
  });

  test('a custom start hour is honoured', () {
    expect(
      showCloseDay(
        now: DateTime(2026, 9, 25, 17),
        todayKey: todayKey,
        today: intake(),
        dismissedOn: null,
        fromHour: 17,
      ),
      isTrue,
    );
  });

  test('hidden with no food or no intake loaded yet', () {
    expect(show(today: intake(kcal: 0)), isFalse);
    expect(show(noToday: true), isFalse);
  });

  test('hidden when the day is already marked complete', () {
    expect(show(today: intake(logged: true)), isFalse);
  });

  test('dismissed today hides it, dismissed on an earlier day does not', () {
    expect(show(dismissedOn: todayKey), isFalse);
    expect(show(dismissedOn: '2026-09-24'), isTrue);
  });
}
