// Display formatting shared by the food screens (numbers, kcal, macros,
// meal and source names, days, friendly error messages).

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/day_key.dart';
import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../data/remote_food.dart';

/// Display name of a meal.
String mealLabel(Meal m) => switch (m) {
  Meal.breakfast => 'Breakfast',
  Meal.lunch => 'Lunch',
  Meal.dinner => 'Dinner',
  Meal.snack => 'Snacks',
};

/// "12" for whole numbers, "12.5" otherwise.
String fmtNum(double v, {int decimals = 1}) {
  final r = double.parse(v.toStringAsFixed(decimals));
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

/// Rounded kcal, e.g. "250 kcal".
String fmtKcal(double kcal) => '${kcal.round()} kcal';

/// Compact macro summary, e.g. "P 20 g · F 5.5 g · C 30 g".
String macroLine(Macros m) =>
    'P ${fmtNum(m.proteinG)} g · '
    'F ${fmtNum(m.fatG)} g · C ${fmtNum(m.carbsG)} g';

/// Display name of a `Foods.source` value; anything unknown is "My food".
String sourceLabel(String source) => switch (source) {
  'off' => 'Open Food Facts',
  'usda' => 'USDA',
  'builtin' => 'Typical values',
  'recipe' => 'Recipe',
  'quick' || 'quickKcal' => 'Quick add',
  _ => 'My food',
};

/// One-line summary for food lists: brand, kcal per 100 g and serving size.
String foodSubtitle(Food f) {
  if (f.source == FoodSource.recipe) {
    return '${f.kcalPer100g.round()} kcal per serving';
  }
  final parts = <String>[
    if (f.brand != null) f.brand!,
    '${f.kcalPer100g.round()} kcal/100 g',
    if (f.servingGrams != null)
      '${f.servingName ?? 'serving'} = ${fmtNum(f.servingGrams!)} g',
  ];
  return parts.join(' · ');
}

/// A short message for [error] that is safe to show the user. The details
/// go to the debug log, never to the screen.
String friendlyError(Object error, [StackTrace? stackTrace]) {
  debugPrint('food: $error${stackTrace == null ? '' : '\n$stackTrace'}');
  return switch (error) {
    FoodApiException(:final message) => message,
    ArgumentError(name: 'grams') => 'Enter an amount above 0',
    _ => 'Something went wrong. Try again.',
  };
}

/// "Yesterday", "Tomorrow" or e.g. "Wed 24 Sep" for [dayKey] seen from
/// [todayKey]; null when it is today.
String? otherDayLabel(String dayKey, String todayKey) {
  if (dayKey == todayKey) return null;
  return switch (daysBetween(todayKey, dayKey)) {
    -1 => 'Yesterday',
    1 => 'Tomorrow',
    _ => DateFormat('EEE d MMM').format(startOfDay(dayKey)),
  };
}

/// [title] followed by the day when it isn't today, e.g.
/// "Add to Breakfast · Yesterday".
String withDay(String title, String dayKey, String todayKey) {
  final day = otherDayLabel(dayKey, todayKey);
  return day == null ? title : '$title · $day';
}

/// An amount as the user thinks of it: "150 g", or "1.5 servings" for a
/// recipe ([FoodSource.recipe] stores a serving as 100 pseudo-grams). A quick
/// add has no amount, so it reads "Quick add".
String fmtAmount(double grams, String source) {
  if (FoodSource.isQuick(source)) return 'Quick add';
  if (source != FoodSource.recipe) return '${fmtNum(grams)} g';
  final servings = grams / 100;
  return '${fmtNum(servings, decimals: 2)} '
      '${(servings - 1).abs() < 1e-9 ? 'serving' : 'servings'}';
}

/// "Added Greek yogurt · 150 g · 146 kcal to Breakfast".
String addedMessage(
  String foodName,
  double grams,
  double kcal,
  Meal meal, {
  String source = '',
}) => FoodSource.isQuick(source)
    ? 'Added $foodName · ${fmtKcal(kcal)} to ${mealLabel(meal)}'
    : 'Added $foodName · ${fmtAmount(grams, source)} · ${fmtKcal(kcal)} '
          'to ${mealLabel(meal)}';

/// "150 g last time · 248 kcal" for a food's last logged amount.
String lastTimeLine(Food f, double grams) =>
    '${fmtAmount(grams, f.source)} last time · '
    '${fmtKcal(f.kcalPer100g * grams / 100)}';

/// "1 item" / "4 items".
String itemsLabel(int n) => n == 1 ? '1 item' : '$n items';
