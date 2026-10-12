// OWNER: engine agent (A).
// CSV text for spreadsheets (RFC 4180). Pure Dart: no Flutter or DB imports;
// `csv_data.dart` reads the tables and feeds the rows in.

/// UTF-8 byte order mark. Excel needs it to read non-Latin text (Hebrew food
/// names) as UTF-8 rather than as the local code page.
const csvBom = '﻿';

/// Header of the food log file, in column order.
const foodLogCsvHeader = [
  'dayKey',
  'meal',
  'food',
  'brand',
  'source',
  'grams',
  'servings',
  'kcal',
  'proteinG',
  'fatG',
  'carbsG',
  'macrosIncomplete',
  'dayFullyLogged',
];

/// Header of the weigh-ins file.
const weighInsCsvHeader = ['dayKey', 'weightKg'];

/// Header of the targets file.
const targetsCsvHeader = [
  'effectiveFrom',
  'kcal',
  'proteinG',
  'fatG',
  'carbsG',
  'maintenanceKcal',
  'method',
  'skipped',
];

/// CSV text for [header] and [rows]: a UTF-8 BOM, then CRLF-terminated
/// records. Cells may be null (empty), String, num or bool.
///
/// Fields containing a comma, quote, CR or LF are quoted with quotes doubled.
/// Text starting with `=`, `+`, `-`, `@`, tab or CR gets a leading `'` so a
/// spreadsheet doesn't run it as a formula. Numbers are written with `.`
/// decimals, no grouping and no exponent.
String toCsv(List<String> header, Iterable<List<Object?>> rows) {
  final out = StringBuffer(csvBom);
  void record(Iterable<Object?> cells) {
    out
      ..writeAll(cells.map(_cell), ',')
      ..write('\r\n');
  }

  record(header);
  for (final row in rows) {
    record(row);
  }
  return out.toString();
}

String _cell(Object? v) => switch (v) {
  null => '',
  bool b => b ? 'true' : 'false',
  num n => csvNumber(n),
  _ => _quote(_neutralise(v.toString())),
};

/// Up to three decimals with trailing zeros dropped: "612.5", "14.86",
/// "100". NaN and infinity (which should not occur) are written empty.
String csvNumber(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isNaN || d.isInfinite) return '';
  var s = d.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

String _neutralise(String s) =>
    s.isNotEmpty && '=+-@\t\r'.contains(s[0]) ? "'$s" : s;

String _quote(String s) =>
    s.contains(RegExp(r'[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// One row of the food log file from a log entry and its food.
///
/// [source] is `Foods.source`. Recipe entries (`recipe`) are counted in
/// servings of 100 pseudo-grams: `servings` is filled and `grams` left
/// blank. Quick adds (`quick`, `quickKcal`) have neither, and are written
/// with source `quick`; `quickKcal` ones also set `macrosIncomplete` (their
/// blank macros are written as 0). Everything else has `grams` and a blank
/// `servings`.
List<Object?> foodLogCsvRow({
  required String dayKey,
  required String meal,
  required String food,
  required String? brand,
  required String source,
  required double grams,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbsG,
  required bool dayFullyLogged,
}) {
  final isRecipe = source == 'recipe';
  final isQuick = source == 'quick' || source == 'quickKcal';
  return [
    dayKey,
    meal,
    food,
    brand,
    isQuick ? 'quick' : source,
    isRecipe || isQuick ? null : grams,
    isRecipe ? grams / 100 : null,
    kcal,
    proteinG,
    fatG,
    carbsG,
    source == 'quickKcal',
    dayFullyLogged,
  ];
}
