/// Pure dashboard aggregation (no Flutter/DB imports) so it's unit-testable.
library;

import 'package:intl/intl.dart';

import '../../core/day_key.dart';
import '../../domain/models.dart';
import '../weight/weight_logic.dart';

/// A target row reduced to what the dashboard needs.
class TargetPoint {
  const TargetPoint({
    required this.effectiveFrom,
    required this.kcal,
    required this.maintenanceKcal,
  });

  /// Day key the target applies from.
  final String effectiveFrom;
  final double kcal;

  /// Estimated maintenance calories at that check-in.
  final double maintenanceKcal;
}

/// Monday of the week containing [dayKey].
String weekStartOf(String dayKey) {
  final weekday = startOfDay(dayKey).weekday; // 1 = Monday
  return addDays(dayKey, -(weekday - 1));
}

/// The target in effect on [dayKey] ([targets] sorted by effectiveFrom
/// ascending; later entries win ties). Null if none applies yet.
TargetPoint? targetOn(List<TargetPoint> targets, String dayKey) {
  TargetPoint? result;
  for (final t in targets) {
    if (t.effectiveFrom.compareTo(dayKey) <= 0) {
      result = t;
    } else {
      break;
    }
  }
  return result;
}

/// One week of intake for the dashboard bar chart.
class WeeklyIntake {
  const WeeklyIntake({
    required this.weekStart,
    required this.avgKcal,
    required this.loggedDays,
    required this.targetKcal,
  });

  /// Monday of the week, as a day key.
  final String weekStart;

  /// Average kcal over fully logged days; null when no day was fully logged.
  final double? avgKcal;

  /// Number of fully logged days that week.
  final int loggedDays;

  /// Target in effect that week (at its start, or the first one set during it).
  final double? targetKcal;
}

/// Groups [days] into Monday-based weeks, averaging only fully logged days.
List<WeeklyIntake> weeklyIntake(
  List<DayIntake> days,
  List<TargetPoint> targets,
) {
  final byWeek = <String, List<DayIntake>>{};
  for (final d in days) {
    byWeek.putIfAbsent(weekStartOf(d.dayKey), () => []).add(d);
  }
  final weeks = byWeek.keys.toList()..sort();
  return [
    for (final w in weeks)
      () {
        final logged = byWeek[w]!.where((d) => d.fullyLogged).toList();
        final avg = logged.isEmpty
            ? null
            : logged.fold<double>(0, (s, d) => s + d.total.kcal) /
                  logged.length;
        return WeeklyIntake(
          weekStart: w,
          avgKcal: avg,
          loggedDays: logged.length,
          targetKcal: _targetForWeek(targets, w)?.kcal,
        );
      }(),
  ];
}

/// Target at [weekStart], or else the first one that starts during that week.
TargetPoint? _targetForWeek(List<TargetPoint> targets, String weekStart) {
  final atStart = targetOn(targets, weekStart);
  if (atStart != null) return atStart;
  final weekEnd = addDays(weekStart, 6);
  for (final t in targets) {
    if (t.effectiveFrom.compareTo(weekStart) >= 0 &&
        t.effectiveFrom.compareTo(weekEnd) <= 0) {
      return t;
    }
  }
  return null;
}

/// One day of the steps chart: raw steps and the rolling 7-day average.
class StepsDay {
  const StepsDay({required this.dayKey, this.steps, this.avg7});

  final String dayKey;
  final int? steps;

  /// Average of the days with step data in the 7 days ending on [dayKey].
  final double? avg7;
}

/// Sorts [days] by day and adds a trailing 7-day average of the days that
/// have step data (days without data are skipped, not counted as zero).
///
/// Pass [from] to fetch a week of lead-in data ([days] starting 6 days
/// before the range shown) so the average is a real trailing 7-day window
/// even for the first day shown, then only that range is returned; days
/// before [from] are used for the average but left out of the result.
List<StepsDay> stepsWithAverage(List<DayActivity> days, {String? from}) {
  final sorted = [...days]..sort((a, b) => a.dayKey.compareTo(b.dayKey));
  final out = <StepsDay>[];
  for (var i = 0; i < sorted.length; i++) {
    var sum = 0;
    var n = 0;
    for (var j = i; j >= 0 && j > i - 7; j--) {
      final s = sorted[j].steps;
      if (s != null) {
        sum += s;
        n++;
      }
    }
    out.add(
      StepsDay(
        dayKey: sorted[i].dayKey,
        steps: sorted[i].steps,
        avg7: n == 0 ? null : sum / n,
      ),
    );
  }
  if (from == null) return out;
  return [
    for (final d in out)
      if (d.dayKey.compareTo(from) >= 0) d,
  ];
}

/// True when at least one day has step data.
bool hasAnySteps(List<DayActivity> days) => days.any((d) => d.steps != null);

/// A count for one Monday-based week ([weekStart] is the Monday).
class WeeklyCount {
  const WeeklyCount({required this.weekStart, required this.count});
  final String weekStart;
  final int count;
}

/// Workouts per Monday-based week, including weeks with zero workouts.
List<WeeklyCount> workoutsPerWeek(List<DayActivity> days) {
  final byWeek = <String, int>{};
  for (final d in days) {
    final w = weekStartOf(d.dayKey);
    byWeek[w] = (byWeek[w] ?? 0) + d.workouts.length;
  }
  final weeks = byWeek.keys.toList()..sort();
  return [for (final w in weeks) WeeklyCount(weekStart: w, count: byWeek[w]!)];
}

/// Maintenance kcal from [dayKey] onwards (one step of the series).
class MaintenancePoint {
  const MaintenancePoint({required this.dayKey, required this.kcal});
  final String dayKey;
  final double kcal;
}

/// Maintenance estimate as a step series within [from, to]: the value in effect
/// at [from] (if any), every change inside the range, and the last value
/// carried to [to].
List<MaintenancePoint> maintenanceSeries(
  List<TargetPoint> targets,
  String from,
  String to,
) {
  final out = <MaintenancePoint>[];
  final atStart = targetOn(targets, from);
  if (atStart != null) {
    out.add(MaintenancePoint(dayKey: from, kcal: atStart.maintenanceKcal));
  }
  for (final t in targets) {
    if (t.effectiveFrom.compareTo(from) > 0 &&
        t.effectiveFrom.compareTo(to) <= 0) {
      if (out.isNotEmpty && out.last.dayKey == t.effectiveFrom) {
        out[out.length - 1] = MaintenancePoint(
          dayKey: t.effectiveFrom,
          kcal: t.maintenanceKcal,
        );
      } else {
        out.add(
          MaintenancePoint(dayKey: t.effectiveFrom, kcal: t.maintenanceKcal),
        );
      }
    }
  }
  if (out.isNotEmpty && out.last.dayKey != to) {
    out.add(MaintenancePoint(dayKey: to, kcal: out.last.kcal));
  }
  return out;
}

// ------------------------------------------------------------- headlines

final _count = NumberFormat.decimalPattern('en_US');

/// Rounds [v] to the nearest [step] and adds thousands separators.
String _rounded(double v, int step) => _count.format((v / step).round() * step);

/// "Trend 83.1 kg · −1.2 kg": the latest trend and its change over [points]
/// (the trend within the range). Null without points.
String? weightHeadline(List<TrendPoint> points) {
  if (points.isEmpty) return null;
  final last = points.last.trendKg;
  final head = 'Trend ${formatKg(last)} kg';
  if (points.length < 2) return head;
  return '$head · ${formatChangeKg(last - points.first.trendKg)}';
}

/// "Avg 8,400/day" over days with step data (rounded to 100). Null when no
/// day has steps.
String? stepsHeadline(List<DayActivity> days) {
  final withSteps = [
    for (final d in days)
      if (d.steps != null) d.steps!,
  ];
  if (withSteps.isEmpty) return null;
  final avg = withSteps.fold<int>(0, (s, v) => s + v) / withSteps.length;
  return 'Avg ${_rounded(avg, 100)}/day';
}

/// "Avg 2,150 of 2,300 kcal": average intake and average target, both over
/// the same days — fully logged days that also have a target in effect
/// (rounded to 10). Without any target it's "Avg 2,150 kcal" over all fully
/// logged days. Null when no day is fully logged.
String? intakeHeadline(List<DayIntake> days, List<TargetPoint> targets) {
  final logged = [
    for (final d in days)
      if (d.fullyLogged) d,
  ];
  if (logged.isEmpty) return null;
  final withTarget = [
    for (final d in logged)
      if (targetOn(targets, d.dayKey) case final t?) (d, t.kcal),
  ];
  if (withTarget.isEmpty) {
    final avg =
        logged.fold<double>(0, (s, d) => s + d.total.kcal) / logged.length;
    return 'Avg ${_rounded(avg, 10)} kcal';
  }
  final avg =
      withTarget.fold<double>(0, (s, e) => s + e.$1.total.kcal) /
      withTarget.length;
  final target =
      withTarget.fold<double>(0, (s, e) => s + e.$2) / withTarget.length;
  return 'Avg ${_rounded(avg, 10)} of ${_rounded(target, 10)} kcal';
}

/// "9 workouts · 2.3/week" over [days] (the whole range, one entry per
/// day). Null when there were no workouts.
String? workoutsHeadline(List<DayActivity> days) {
  final total = days.fold<int>(0, (s, d) => s + d.workouts.length);
  if (total == 0) return null;
  final perWeek = total / (days.length / 7);
  final noun = total == 1 ? 'workout' : 'workouts';
  return '$total $noun · ${perWeek.toStringAsFixed(1)}/week';
}

/// "Now 2,550 kcal/day": the latest maintenance estimate. Null when empty.
String? maintenanceHeadline(List<MaintenancePoint> series) {
  if (series.isEmpty) return null;
  return 'Now ${_rounded(series.last.kcal, 10)} kcal/day';
}
