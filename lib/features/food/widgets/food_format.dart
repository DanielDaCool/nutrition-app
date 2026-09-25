import '../../../data/db/database.dart';
import '../../../domain/models.dart';

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

String fmtKcal(double kcal) => '${kcal.round()} kcal';

String macroLine(Macros m) =>
    'P ${fmtNum(m.proteinG)} g · '
    'F ${fmtNum(m.fatG)} g · C ${fmtNum(m.carbsG)} g';

String sourceLabel(String source) => switch (source) {
  'off' => 'Open Food Facts',
  'usda' => 'USDA',
  _ => 'My food',
};

String foodSubtitle(Food f) {
  final parts = <String>[
    if (f.brand != null) f.brand!,
    '${f.kcalPer100g.round()} kcal/100 g',
    if (f.servingGrams != null)
      '${f.servingName ?? 'serving'} = ${fmtNum(f.servingGrams!)} g',
  ];
  return parts.join(' · ');
}
