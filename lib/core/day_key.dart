/// Days are stored as `YYYY-MM-DD` strings in the phone's local time zone.
///
/// Using a string key (instead of a DateTime) keeps "which day did I eat this"
/// stable when the phone changes time zone or daylight-saving time.
library;

String dayKeyOf(DateTime t) {
  final local = t.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// Local midnight at the start of [dayKey].
DateTime startOfDay(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid day key', dayKey);
  }
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Local midnight at the start of the day after [dayKey].
DateTime endOfDay(String dayKey) {
  final s = startOfDay(dayKey);
  return DateTime(s.year, s.month, s.day + 1);
}

/// [dayKey] shifted by [days] calendar days (negative for the past).
String addDays(String dayKey, int days) {
  final s = startOfDay(dayKey);
  return dayKeyOf(DateTime(s.year, s.month, s.day + days));
}

/// Whole calendar days from [from] to [to] (positive when [to] is later).
int daysBetween(String from, String to) {
  final a = startOfDay(from);
  final b = startOfDay(to);
  // Use UTC dates so DST shifts don't produce 23/25-hour "days".
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}
