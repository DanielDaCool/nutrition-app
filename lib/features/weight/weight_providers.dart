// OWNER: weight & charts agent (D). Contract stub: keep the public names/types.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

/// All weigh-ins: dayKey -> kg.
final weighInsProvider = StreamProvider<Map<String, double>>(
  (ref) => Stream.value(const {}), // TODO(D): implement
);

/// Daily trend points from the first weigh-in through today.
final weightTrendProvider = StreamProvider<List<TrendPoint>>(
  (ref) => Stream.value(const []), // TODO(D): implement with computeTrend()
);
