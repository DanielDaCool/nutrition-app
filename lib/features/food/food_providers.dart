// OWNER: food agent (B). Contract stub: keep the public names and types.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

/// Everything eaten on one day (dayKey = YYYY-MM-DD).
final dayIntakeProvider = StreamProvider.family<DayIntake, String>(
  (ref, dayKey) => Stream.value(
    DayIntake(
      dayKey: dayKey,
      total: Macros.zero,
      byMeal: const {},
      fullyLogged: false,
    ),
  ), // TODO(B): implement
);

/// One DayIntake per calendar day in [from, to] inclusive, oldest first.
/// Days with nothing logged are included with zero totals.
final intakeRangeProvider =
    StreamProvider.family<List<DayIntake>, (String from, String to)>(
  (ref, range) => Stream.value(const []), // TODO(B): implement
);
