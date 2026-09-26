/// Pure formatting helpers for activity data (no Flutter/DB imports).
library;

const _typeNames = <String, String>{
  'STRENGTH_TRAINING': 'Strength training',
  'WEIGHTLIFTING': 'Weightlifting',
  'HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
  'OTHER': 'Workout',
  'WALKING': 'Walk',
  'RUNNING': 'Run',
  'BIKING': 'Cycling',
};

/// 'STRENGTH_TRAINING' -> 'Strength training'.
String readableActivityType(String? type) {
  if (type == null || type.trim().isEmpty) return 'Workout';
  final known = _typeNames[type];
  if (known != null) return known;
  final text = type
      .toLowerCase()
      .split('_')
      .where((w) => w.isNotEmpty)
      .join(' ');
  if (text.isEmpty) return 'Workout';
  return text[0].toUpperCase() + text.substring(1);
}

const _appNames = <String, String>{
  'com.hevy': 'Hevy',
  'com.google.android.apps.healthdata': 'Health Connect',
  'com.google.android.apps.fitness': 'Google Fit',
  'com.sec.android.app.shealth': 'Samsung Health',
};

/// Friendly name for a Health Connect data origin package, or null if unknown.
String? readableSourceApp(String? packageName) =>
    packageName == null ? null : _appNames[packageName];

/// 72 min -> '1 h 12 min', 45 min -> '45 min', 120 min -> '2 h'.
String formatDuration(Duration d) {
  final totalMin = d.inSeconds <= 0 ? 0 : (d.inSeconds / 60).round();
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// At most [maxDecimals] decimals, no trailing zeros: 2.50 -> '2.5', 6.0 -> '6'.
String formatDecimal(double v, int maxDecimals) {
  final s = v.toStringAsFixed(maxDecimals);
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// "2.5 km · 5 km/h · 6% incline" for a manual walk or run; null without a
/// distance.
String? formatWalkDetails({
  required double? distanceKm,
  required double? inclinePct,
  required Duration duration,
}) {
  if (distanceKm == null || distanceKm <= 0) return null;
  final parts = ['${formatDecimal(distanceKm, 2)} km'];
  final hours = duration.inSeconds / 3600;
  if (hours > 0) parts.add('${formatDecimal(distanceKm / hours, 1)} km/h');
  if (inclinePct != null && inclinePct > 0) {
    parts.add('${formatDecimal(inclinePct, 1)}% incline');
  }
  return parts.join(' · ');
}

/// 8432 -> '8,432'.
String formatSteps(int steps) {
  final s = steps.abs().toString();
  final buf = StringBuffer(steps < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
