import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../domain/trait.dart';

/// A small rounded-corner badge naming one trait, tinted by
/// [TraitCategory] -- color is decorative grouping only, the trait name
/// text still carries the actual information (accessibility rule in
/// ARCHITECTURE.md). Shared between the roster row and the player detail
/// screen, the two places a player's traits show up.
class TraitChip extends StatelessWidget {
  const TraitChip({required this.trait, super.key});

  final Trait trait;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = traitCategoryColor(trait.category);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        trait.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Color traitCategoryColor(TraitCategory category) {
  return switch (category) {
    TraitCategory.workEthic => Colors.indigo,
    TraitCategory.durability => Colors.brown,
    TraitCategory.leadership => Colors.pink,
    TraitCategory.mental => Colors.red,
    // Default cyan/amber are too pale for legible text on a light tint.
    TraitCategory.loyalty => Colors.cyan.shade700,
    TraitCategory.crowd => Colors.amber.shade800,
    TraitCategory.skillBadge => Colors.deepPurple,
  };
}
