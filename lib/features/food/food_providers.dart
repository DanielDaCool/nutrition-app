// OWNER: food agent (B). Contract stub: keep the public names and types.
// Riverpod providers for food logging: the public intake contract used by
// other features, plus the repository, API clients and list streams.
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

/// The [FoodRepository] on the app database, using the injectable clock for
/// timestamps.
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

/// Open Food Facts client. Its rate limiters use the injectable clock.
final offClientProvider = Provider<OffClient>(
  (ref) => OffClient(
    ref.watch(foodHttpClientProvider),
    clock: () => ref.read(clockProvider)(),
  ),
);

/// USDA FoodData Central client (API key from `--dart-define=USDA_API_KEY`).
final usdaClientProvider = Provider<UsdaClient>(
  (ref) => UsdaClient(ref.watch(foodHttpClientProvider)),
);

/// Barcode lookup: local foods first, then Open Food Facts.
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

/// Foods logged before, most recently used first (up to 50).
final recentFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchRecent(),
);

/// Starred foods, most recently used first, then by name.
final favoriteFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchFavorites(),
);

/// Foods the user created (e.g. from a label), alphabetically.
final customFoodsProvider = StreamProvider<List<Food>>(
  (ref) => ref.watch(foodRepositoryProvider).watchCustom(),
);

/// A single food, kept fresh (e.g. the favorite star on the portion screen).
final foodProvider = StreamProvider.family<Food, int>(
  (ref, id) => ref.watch(foodRepositoryProvider).watchFood(id),
);
