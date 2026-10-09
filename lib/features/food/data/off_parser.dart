/// Parsing of Open Food Facts product JSON (pure Dart).
library;

import '../nutrition_math.dart';
import 'barcode_format.dart';
import 'remote_food.dart';

/// Fields requested from OFF, so responses stay small.
const offProductFields = [
  'code',
  'product_name',
  'product_name_en',
  'product_name_he',
  'generic_name',
  'generic_name_en',
  'generic_name_he',
  'brands',
  'serving_size',
  'serving_quantity',
  'serving_quantity_unit',
  'nutriments',
];

/// Trimmed string value, or null for non-strings and blank text.
String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Converts one OFF `product` object to a [RemoteFood], or null when it has
/// no usable name or barcode. [barcode] is used when the product has no
/// `code` field.
RemoteFood? parseOffProduct(Map<String, dynamic> product, {String? barcode}) {
  // OFF's own `code` can be in a different (but equivalent) form than what
  // was scanned, e.g. zero-padded to EAN-13; normalize so it still matches
  // a later scan.
  final rawCode = _text(product['code']) ?? barcode;
  if (rawCode == null) return null;
  final code = normalizeBarcode(rawCode);

  // Prefer English, then the main-language name, then generic/Hebrew names.
  final name =
      _text(product['product_name_en']) ??
      _text(product['product_name']) ??
      _text(product['generic_name_en']) ??
      _text(product['generic_name']) ??
      _text(product['product_name_he']) ??
      _text(product['generic_name_he']);
  if (name == null) return null;

  final brands = _text(product['brands']);
  final brand = brands == null ? null : _text(brands.split(',').first);

  final n = product['nutriments'];
  final nutriments = n is Map ? n : const {};
  // OFF's `energy_100g` is in kJ.
  final kj =
      toDouble(nutriments['energy-kj_100g']) ??
      toDouble(nutriments['energy_100g']);
  final kcal = resolveKcal(
    kcalField: toDouble(nutriments['energy-kcal_100g']),
    kjField: kj,
  );
  double? nonNegative(double? v) => (v == null || v < 0) ? null : v;

  final servingSize = _text(product['serving_size']);
  final servingGrams = parseServingGrams(
    servingSize: servingSize,
    servingQuantity: product['serving_quantity'],
    unit: _text(product['serving_quantity_unit']),
  );

  return RemoteFood(
    source: FoodSource.off,
    externalId: code,
    name: name,
    brand: brand,
    kcalPer100g: nonNegative(kcal),
    proteinPer100g: nonNegative(toDouble(nutriments['proteins_100g'])),
    fatPer100g: nonNegative(toDouble(nutriments['fat_100g'])),
    carbsPer100g: nonNegative(toDouble(nutriments['carbohydrates_100g'])),
    servingName: servingGrams == null ? null : servingSize,
    servingGrams: servingGrams,
  );
}

/// Parses a `/api/v2/product/{code}` response body. Returns null when OFF
/// says the product doesn't exist.
RemoteFood? parseOffProductResponse(
  Map<String, dynamic> json, {
  required String barcode,
}) {
  final status = json['status'];
  final product = json['product'];
  if (status == 0 || status == '0' || product is! Map<String, dynamic>) {
    return null;
  }
  return parseOffProduct(product, barcode: barcode);
}

/// Parses a search response (`products` array). Products without a name are
/// skipped.
List<RemoteFood> parseOffSearchResponse(Map<String, dynamic> json) {
  final products = json['products'];
  if (products is! List) return const [];
  return [
    for (final p in products)
      if (p is Map<String, dynamic>) ?parseOffProduct(p),
  ];
}
