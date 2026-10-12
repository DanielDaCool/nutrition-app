// Pure helpers for "Quick add calories" (no Flutter or DB imports).

/// Energy implied by the macros (4 / 9 / 4 kcal per gram); blanks count as 0.
double macroKcal({double? proteinG, double? fatG, double? carbsG}) =>
    (proteinG ?? 0) * 4 + (fatG ?? 0) * 9 + (carbsG ?? 0) * 4;

/// True when the macros imply clearly more energy than [kcal] (more than 15%
/// and 20 kcal over), which usually means a typo. Label rounding and fibre
/// stay under that.
bool macrosExceedKcal(
  double kcal, {
  double? proteinG,
  double? fatG,
  double? carbsG,
}) {
  final implied = macroKcal(proteinG: proteinG, fatG: fatG, carbsG: carbsG);
  return implied > kcal * 1.15 && implied - kcal > 20;
}

/// Total kcal of entries whose protein, fat or carbs were left blank, given
/// (kcal, incomplete) pairs. Used for the note under the day's totals.
double incompleteKcal(Iterable<(double kcal, bool incomplete)> entries) =>
    entries.fold(0.0, (a, e) => e.$2 ? a + e.$1 : a);
