import 'package:flutter/material.dart';

/// Shared type-scale weight overrides, applied on top of Material 3's
/// default type scale in both brightnesses so headings stay legible at
/// every text-scale multiplier.
const _textTheme = TextTheme(
  headlineMedium: TextStyle(fontWeight: FontWeight.w800),
  titleLarge: TextStyle(fontWeight: FontWeight.w700),
);

abstract final class AppTheme {
  static const _navy = Color(0xFF0B1B35);
  static const _panel = Color(0xFF172A46);
  static const _gold = Color(0xFFF4C542);
  static const _ink = Color(0xFFF4F7FB);
  static const _cream = Color(0xFFFFFBF2);
  static const _lightPanel = Color(0xFFFFFFFF);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
      surface: _panel,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: _navy,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: _ink,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(color: _panel, margin: EdgeInsets.zero),
      textTheme: _textTheme.apply(bodyColor: _ink, displayColor: _ink),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.light,
      surface: _lightPanel,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: _cream,
        foregroundColor: _navy,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: _lightPanel,
        margin: EdgeInsets.zero,
      ),
      textTheme: _textTheme.apply(bodyColor: _navy, displayColor: _navy),
    );
  }
}
