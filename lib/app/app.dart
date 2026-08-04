import 'package:flutter/material.dart';

import '../features/dashboard/dashboard_screen.dart';
import 'app_theme.dart';

class WomensBasketballManagerApp extends StatelessWidget {
  const WomensBasketballManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women\'s Basketball Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
