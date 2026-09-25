// OWNER: engine agent (A). Contract stub: keep the public names and types.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

/// Targets in effect today, or null before the profile is set up.
final currentTargetsProvider = StreamProvider<DailyTargets?>(
  (ref) => Stream.value(null), // TODO(A): implement
);

/// True when the weekly check-in is due (a new recommendation is waiting).
final checkInDueProvider = StreamProvider<bool>(
  (ref) => Stream.value(false), // TODO(A): implement
);
