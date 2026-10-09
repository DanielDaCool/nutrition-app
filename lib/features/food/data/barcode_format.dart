// Canonical form for a scanned/typed barcode, so the same physical barcode
// always compares equal regardless of which symbology a scan decoded it as.

/// Normalizes [raw] to a canonical form. A 12-digit UPC-A code is the GS1
/// equivalent of EAN-13 with a leading zero, and the same physical barcode
/// can come back from the scanner as either depending on which symbology it
/// was decoded as this time — so UPC-A is always widened to 13 digits.
/// Anything else (EAN-13, EAN-8, non-numeric) is returned trimmed.
String normalizeBarcode(String raw) {
  final trimmed = raw.trim();
  return RegExp(r'^\d{12}$').hasMatch(trimmed) ? '0$trimmed' : trimmed;
}

/// Other forms a scan might report for the same physical barcode as
/// [normalized] (itself the result of [normalizeBarcode]), so a lookup can
/// still match a barcode that was saved before normalization existed.
/// Currently just the UPC-A/EAN-13 pair.
Iterable<String> barcodeVariants(String normalized) sync* {
  yield normalized;
  final m = RegExp(r'^0(\d{12})$').firstMatch(normalized);
  if (m != null) yield m.group(1)!;
}
