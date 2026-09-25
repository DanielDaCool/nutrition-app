// OWNER: food agent (B). Contract stub: keep the public names and types.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import 'data/barcode_lookup.dart';
import 'data/food_repository.dart';
import 'data/off_client.dart';
import 'data/usda_client.dart';

/// Everything eaten on one day (dayKey = YYYY-MM-DD).
final dayIntakeProvider = StreamProvider.family<DayIntake, String>(
  (ref, dayKey) => ref
      .watch(foodRepositoryProvider)
      .watchIntakeRange(dayKey, dayKey)
      .map((days) => days.single),
);

/// One DayIntake per calendar day in [from, to] inclusive, oldest first.
/// Days with nothing logged are included with zero totals.
final intakeRangeProvider =
    StreamProvider.family<List<DayIntake>, (String from, String to)>(
      (ref, range) => ref
          .watch(foodRepositoryProvider)
          .watchIntakeRange(range.$1, range.$2),
    );

// ----------------------------------------------------------- feature-internal

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => FoodRepository(
    ref.watch(databaseProvider),
    () => ref.read(clockProvider)(),
  ),
);

/// HTTP client for the food APIs; overridden with a MockClient in tests.
final foodHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final offClientProvider = Provider<OffClient>(
  (ref) => OffClient(
    ref.watch(foodHttpClientProvider),
    clock: () => ref.read(clockProvider)(),
  ),
);

final usdaClientProvider = Provider<UsdaClient>(
  (ref) => UsdaClient(ref.watch(foodHttpClientProvider)),
);

final barcodeLookupProvider = Provider<BarcodeLookup>(
  (ref) => BarcodeLookup(
    ref.watch(foodRepositoryProvider),
    ref.watch(offClientProvider),
  ),
);

/// Logged items of one day, in the order they were added.
final dayItemsProvider = StreamProvider.family<List<LoggedItem>, String>(
  (ref, dayKey) => ref.watch(foodRepositoryProvider).watchDayItems(dayKey),
);

final recentFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchRecent(),
);

final favoriteFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchFavorites(),
);

final customFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchCustom(),
);

/// A single food, kept fresh (e.g. the favorite star on the portion screen).
final foodProvider = StreamProvider.family<Food, int>(
  (ref, id) => ref.watch(foodRepositoryProvider).watchFood(id),
);
