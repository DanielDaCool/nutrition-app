// App theme: dark "Slate & Teal". Teal is the main color, amber the second
// chart color (targets, averages), on blue-tinted slate surfaces.

import 'package:flutter/material.dart';

const _teal = Color(0xFF5CC8BA);
const _amber = Color(0xFFF0B35B);

final ColorScheme appColorScheme =
    ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _teal,
      onPrimary: const Color(0xFF00302A),
      primaryContainer: const Color(0xFF1E4A45),
      onPrimaryContainer: const Color(0xFFB7F0E6),
      secondary: const Color(0xFF9CC3D8),
      onSecondary: const Color(0xFF0B2F40),
      secondaryContainer: const Color(0xFF263945),
      onSecondaryContainer: const Color(0xFFCDE6F4),
      tertiary: _amber,
      onTertiary: const Color(0xFF3F2A00),
      tertiaryContainer: const Color(0xFF5A4217),
      onTertiaryContainer: const Color(0xFFFFDDB0),
      error: const Color(0xFFFF8A80),
      onError: const Color(0xFF4A0A06),
      errorContainer: const Color(0xFF5C1A15),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: const Color(0xFF0F141A),
      onSurface: const Color(0xFFE6EBF0),
      onSurfaceVariant: const Color(0xFF9AA7B4),
      surfaceDim: const Color(0xFF0F141A),
      surfaceBright: const Color(0xFF2A333D),
      surfaceContainerLowest: const Color(0xFF0B0F14),
      surfaceContainerLow: const Color(0xFF131A21),
      surfaceContainer: const Color(0xFF161D25),
      surfaceContainerHigh: const Color(0xFF1F2831),
      surfaceContainerHighest: const Color(0xFF28323C),
      outline: const Color(0xFF5B6773),
      outlineVariant: const Color(0xFF2E3945),
      inverseSurface: const Color(0xFFE6EBF0),
      onInverseSurface: const Color(0xFF1A2129),
      inversePrimary: const Color(0xFF006B60),
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
