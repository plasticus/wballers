import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_screen.dart';
import 'app_preferences.dart';
import 'app_theme.dart';

class WomensBasketballManagerApp extends ConsumerWidget {
  const WomensBasketballManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScaleMultiplier = ref.watch(textScaleProvider);
    final themeModePreference = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Women\'s Basketball Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeModePreference) {
        ThemeModePreference.system => ThemeMode.system,
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = resolveTextScale(
          systemScale: mediaQuery.textScaler.scale(1.0),
          userMultiplier: textScaleMultiplier,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const AppShell(),
    );
  }
}
