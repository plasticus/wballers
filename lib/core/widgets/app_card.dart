import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';

/// Standard padded card surface, shared across feature screens.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}
