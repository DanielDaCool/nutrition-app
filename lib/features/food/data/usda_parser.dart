/// Parsing of USDA FoodData Central search results (pure Dart).
library;

import '../nutrition_math.dart';
import 'remote_food.dart';

/// FDC nutrient ids.
abstract final class UsdaNutrient {
  static const energyKcal = 1008;
  static const energyAtwaterGeneral = 2047;
  static const energyAtwaterSpecific = 2048;
  static const energyKj = 1062;
  static const protein = 1003;
  static const fat = 1004;
  static const carbs = 1005;
}

/// Converts one food of a `/v1/foods/search` result. Foundation and SR Legacy
/// values are per 100 g.
RemoteFood? parseUsdaFood(Map<String, dynamic> food) {
  final id = food['fdcId'];
  final description = food['description'];
  if (id == null || description is! String || description.trim().isEmpty) {
    return null;
  }

  final values = <int, double>{};
  final units = <int, String>{};
  final nutrients = food['foodNutrients'];
  if (nutrients is List) {
    for (final n in nutrients) {
      if (n is! Map) continue;
      final nid = n['nutrientId'];
      final v = toDouble(n['value']);
      if (nid is! int || v == null || values.containsKey(nid)) continue;
      values[nid] = v;
      final unit = n['unitName'];
      if (unit is String) units[nid] = unit.toUpperCase();
    }
  }

  double? energy() {
    for (final id in const [
      UsdaNutrient.energyKcal,
      UsdaNutrient.energyAtwaterGeneral,
      UsdaNutrient.energyAtwaterSpecific,
    ]) {
      final v = values[id];
      if (v == null) continue;
      return units[id] == 'KJ' ? v / kjPerKcal : v;
    }
    final kj = values[UsdaNutrient.energyKj];
    return kj == null ? null : kj / kjPerKcal;
  }

  double? nonNegative(double? v) => (v == null || v < 0) ? null : v;

  return RemoteFood(
    source: FoodSource.usda,
    externalId: id.toString(),
    name: description.trim(),
    kcalPer100g: nonNegative(energy()),
    proteinPer100g: nonNegative(values[UsdaNutrient.protein]),
    fatPer100g: nonNegative(values[UsdaNutrient.fat]),
    carbsPer100g: nonNegative(values[UsdaNutrient.carbs]),
  );
}

List<RemoteFood> parseUsdaSearchResponse(Map<String, dynamic> json) {
  final foods = json['foods'];
  if (foods is! List) return const [];
  return [
    for (final f in foods)
      if (f is Map<String, dynamic>) ?parseUsdaFood(f),
  ];
}
