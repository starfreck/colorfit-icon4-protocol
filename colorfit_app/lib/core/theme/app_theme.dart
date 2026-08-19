import 'package:flutter/material.dart';

class AppTheme {
  // shadcn-inspired colors
  static const Color background = Color(0xFF09090B);
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color card = Color(0xFF09090B);
  static const Color cardForeground = Color(0xFFFAFAFA);
  static const Color popover = Color(0xFF09090B);
  static const Color popoverForeground = Color(0xFFFAFAFA);
  static const Color primary = Color(0xFFFAFAFA);
  static const Color primaryForeground = Color(0xFF18181B);
  static const Color secondary = Color(0xFF27272A);
  static const Color secondaryForeground = Color(0xFFFAFAFA);
  static const Color muted = Color(0xFF27272A);
  static const Color mutedForeground = Color(0xFFA1A1AA);
  static const Color accent = Color(0xFF27272A);
  static const Color accentForeground = Color(0xFFFAFAFA);
  static const Color destructive = Color(0xFF7F1D1D);
  static const Color destructiveForeground = Color(0xFFFAFAFA);
  static const Color border = Color(0xFF27272A);
  static const Color input = Color(0xFF27272A);
  static const Color ring = Color(0xFFD4D4D8);

  // Chart colors
  static const Color chart1 = Color(0xFF22D3EE);
  static const Color chart2 = Color(0xFFA78BFA);
  static const Color chart3 = Color(0xFF34D399);
  static const Color chart4 = Color(0xFFF472B6);
  static const Color chart5 = Color(0xFFFBBF24);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: background,
        onSurface: foreground,
        primary: primary,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        error: destructive,
        onError: destructiveForeground,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: foreground),
        bodyMedium: TextStyle(color: foreground),
        bodySmall: TextStyle(color: foreground),
        labelLarge: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: foreground, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
