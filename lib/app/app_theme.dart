import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _navy = Color(0xFF0B1B35);
  static const _panel = Color(0xFF172A46);
  static const _gold = Color(0xFFF4C542);
  static const _ink = Color(0xFFF4F7FB);

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
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
      ).apply(bodyColor: _ink, displayColor: _ink),
    );
  }
}
