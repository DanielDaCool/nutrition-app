// Pure rule for the evening "Done eating today?" prompt on Today.
import '../../domain/models.dart';

/// Local hour (24h) from which the close-the-day prompt may show.
const int kCloseDayFromHour = 19;

/// Whether [intake] has anything logged.
bool dayHasFood(DayIntake? intake) =>
    intake != null && (intake.byMeal.isNotEmpty || intake.total.kcal > 0);

/// True when the close-the-day prompt should show: it is [fromHour] or later,
/// today has food, today isn't marked fully logged, and the prompt wasn't
/// dismissed on [todayKey] already.
bool showCloseDay({
  required DateTime now,
  required String todayKey,
  required DayIntake? today,
  required String? dismissedOn,
  int fromHour = kCloseDayFromHour,
}) {
  if (now.hour < fromHour) return false;
  if (today == null || !dayHasFood(today) || today.fullyLogged) return false;
  return dismissedOn != todayKey;
}
