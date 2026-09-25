// App theme: dark "Midnight Indigo". Periwinkle is the main color, coral the
// second chart color (targets, averages), on blue-violet tinted surfaces.

import 'package:flutter/material.dart';

const _indigo = Color(0xFF8C9EFF);
const _coral = Color(0xFFFF9E7A);

final ColorScheme appColorScheme =
    ColorScheme.fromSeed(
      seedColor: _indigo,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _indigo,
      onPrimary: const Color(0xFF10194D),
      primaryContainer: const Color(0xFF2C3566),
      onPrimaryContainer: const Color(0xFFDDE1FF),
      secondary: const Color(0xFF6FD3C0),
      onSecondary: const Color(0xFF00382F),
      secondaryContainer: const Color(0xFF1F4640),
      onSecondaryContainer: const Color(0xFFB8F0E4),
      tertiary: _coral,
      onTertiary: const Color(0xFF4A1A06),
      tertiaryContainer: const Color(0xFF5E2E1C),
      onTertiaryContainer: const Color(0xFFFFDBCC),
      error: const Color(0xFFFF6E86),
      onError: const Color(0xFF4A0615),
      errorContainer: const Color(0xFF5C1524),
      onErrorContainer: const Color(0xFFFFD9DF),
      surface: const Color(0xFF101118),
      onSurface: const Color(0xFFE7E8F0),
      onSurfaceVariant: const Color(0xFFA0A4B8),
      surfaceDim: const Color(0xFF101118),
      surfaceBright: const Color(0xFF2B2E3D),
      surfaceContainerLowest: const Color(0xFF0B0C12),
      surfaceContainerLow: const Color(0xFF14161F),
      surfaceContainer: const Color(0xFF181A24),
      surfaceContainerHigh: const Color(0xFF212431),
      surfaceContainerHighest: const Color(0xFF2A2D3C),
      outline: const Color(0xFF5E6378),
      outlineVariant: const Color(0xFF323647),
      inverseSurface: const Color(0xFFE7E8F0),
      onInverseSurface: const Color(0xFF1B1D28),
      inversePrimary: const Color(0xFF4355B9),
      surfaceTint: Colors.transparent,
    );

ThemeData buildAppTheme() {
  final scheme = appColorScheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerHigh),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
