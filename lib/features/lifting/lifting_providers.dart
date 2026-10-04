// Riverpod providers for weight lifting: the repository, the user's
// exercises and presets, a day's plan with its sets, and exercise history.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../domain/models.dart';
import 'lifting_repository.dart';

/// The [LiftingRepository] on the app database, stamping `createdAt` with
/// the injectable clock.
final liftingRepositoryProvider = Provider<LiftingRepository>(
  (ref) =>
      LiftingRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// The day shown on the Lifting tab (defaults to today; unlike Today it can
/// also be a future day, to plan ahead).
final liftSelectedDayProvider = NotifierProvider<LiftSelectedDay, String>(
  LiftSelectedDay.new,
);

/// Holds the Lifting tab's selected day key; starts at today.
class LiftSelectedDay extends Notifier<String> {
  @override
  String build() => dayKeyOf(ref.read(clockProvider)());

  /// Selects [dayKey] (a `YYYY-MM-DD` day key).
  void set(String dayKey) => state = dayKey;

  /// Jumps back to today.
  void today() => state = dayKeyOf(ref.read(clockProvider)());
}

/// The user's exercises by name, without deleted (archived) ones.
final liftExercisesProvider = StreamProvider<List<LiftExercise>>(
  (ref) => ref.watch(liftingRepositoryProvider).watchExercises(),
);

/// Exercises with at least one tracked set, by name (for progress charts).
final liftLoggedExercisesProvider = StreamProvider<List<LiftExercise>>(
  (ref) => ref.watch(liftingRepositoryProvider).watchLoggedExercises(),
);

/// The exercises planned on a day, in order, each with its tracked sets.
final liftDayProvider = StreamProvider.family<List<LiftEntry>, String>(
  (ref, dayKey) => ref.watch(liftingRepositoryProvider).watchDay(dayKey),
);

/// The last time an exercise was tracked before a day: `(exerciseId,
/// beforeDayKey)` -> that day's sets, or null when there is none.
final liftLastSessionProvider =
    StreamProvider.family<LiftSession?, (int exerciseId, String beforeDayKey)>(
      (ref, key) => ref
          .watch(liftingRepositoryProvider)
          .watchLastSession(key.$1, key.$2),
    );

/// The days with tracked sets of an exercise in an inclusive range, oldest
/// first: `(exerciseId, from, to)`.
final liftHistoryProvider =
    StreamProvider.family<
      List<LiftSession>,
      (int exerciseId, String from, String to)
    >(
      (ref, key) => ref
          .watch(liftingRepositoryProvider)
          .watchHistory(key.$1, key.$2, key.$3),
    );

/// All presets by name, each with its exercises in order.
final liftPresetsProvider = StreamProvider<List<LiftPreset>>(
  (ref) => ref.watch(liftingRepositoryProvider).watchPresets(),
);
