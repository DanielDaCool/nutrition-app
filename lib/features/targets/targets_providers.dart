// OWNER: engine agent (A). Contract stub: keep the public names and types.
// Riverpod providers for calorie/macro targets, the weekly check-in and the
// user profile. All logic lives in TargetsRepository.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import 'engine/engine.dart';
import 'targets_repository.dart';

/// The [TargetsRepository] bound to the app DB and clock.
final targetsRepositoryProvider = Provider<TargetsRepository>(
  (ref) => TargetsRepository(
    ref.watch(databaseProvider),
    () => ref.read(clockProvider)(),
  ),
);

/// Targets in effect today, or null before the profile is set up.
///
/// Creates the first formula target as soon as a profile and a weigh-in
/// exist. Re-emits when Profiles, TargetHistory or WeighIns change.
final currentTargetsProvider = StreamProvider<DailyTargets?>(
  (ref) => ref.watch(targetsRepositoryProvider).watchCurrentTargets(),
);

/// True when the weekly check-in is due (a new recommendation is waiting).
final checkInDueProvider = StreamProvider<bool>(
  (ref) => ref.watch(targetsRepositoryProvider).watchCheckInDue(),
);

/// The user's profile (null before it is set up).
final profileProvider = StreamProvider<Profile?>(
  (ref) => ref.watch(targetsRepositoryProvider).watchProfile(),
);

/// A fresh recommendation for today (null without profile or weigh-in).
///
/// Auto-disposed so each visit to the check-in screen recomputes it.
final checkInRecommendationProvider =
    FutureProvider.autoDispose<Recommendation?>(
      (ref) => ref.watch(targetsRepositoryProvider).recommendToday(),
    );
