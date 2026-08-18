import 'package:flutter/material.dart';

/// A placeholder ad slot -- no ad SDK wired in yet (a direct GM call: "for
/// now, just a placeholder"). Originally `MatchPreviewScreen`-only;
/// promoted to a shared widget (2026-08-18) once `LiveGameLabScreen`
/// needed the exact same look in place of its old dev-only description
/// paragraph, same "one real widget, not two copies" reasoning every
/// other shared widget in `core/widgets/` already follows.
class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        'Ad · 320×50 placeholder',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
