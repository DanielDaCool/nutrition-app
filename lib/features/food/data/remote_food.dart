/// Foods returned by the remote APIs, before they're saved locally.
library;

/// Where a food came from. Stored in `Foods.source`.
abstract final class FoodSource {
  static const off = 'off';
  static const usda = 'usda';
  static const custom = 'custom';
}

/// A food from Open Food Facts or USDA. Nutrients are per 100 g; null means
/// the source didn't provide the value.
class RemoteFood {
  const RemoteFood({
    required this.source,
    required this.externalId,
    required this.name,
    this.brand,
    this.kcalPer100g,
    this.proteinPer100g,
    this.fatPer100g,
    this.carbsPer100g,
    this.servingName,
    this.servingGrams,
  });

  /// [FoodSource.off] or [FoodSource.usda].
  final String source;

  /// Barcode (off) or fdcId (usda).
  final String externalId;
  final String name;
  final String? brand;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? fatPer100g;
  final double? carbsPer100g;
  final String? servingName;
  final double? servingGrams;

  /// Enough data to log it. Missing macros count as 0; missing energy does
  /// not (the user should enter the label instead).
  bool get isComplete => kcalPer100g != null;

  @override
  String toString() =>
      'RemoteFood($source:$externalId "$name" '
      '$kcalPer100g kcal P$proteinPer100g F$fatPer100g C$carbsPer100g)';
}

enum FoodApiErrorKind {
  notFound,
  rateLimited,
  network,
  badKey,
  server,
  badResponse,
}

/// A failure talking to a food API, with a message fit for the UI.
class FoodApiException implements Exception {
  const FoodApiException(this.kind, this.message);

  final FoodApiErrorKind kind;
  final String message;

  @override
  String toString() => 'FoodApiException($kind): $message';
}
