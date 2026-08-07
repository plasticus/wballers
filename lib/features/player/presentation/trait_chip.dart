import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../domain/trait.dart';

/// A small rounded-corner badge naming one trait, tinted by
/// [TraitCategory] -- color is decorative grouping only, the trait name
/// text still carries the actual information (accessibility rule in
/// ARCHITECTURE.md). Shared between the roster row, the player detail
/// screen, and the Card Lab -- everywhere a player's traits show up.
/// Tappable: a direct GM ask ("what does this trait actually do") --
/// every trait already has a real `description` in the domain model
/// (`trait.dart`), this just surfaces it instead of leaving the GM to
/// guess from the name alone.
class TraitChip extends StatelessWidget {
  const TraitChip({required this.trait, super.key});

  final Trait trait;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = traitCategoryColor(trait.category);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showTraitExplanation(context, trait),
      child: Container(
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
      ),
    );
  }
}

/// A small popup naming [trait], its description, and (if one exists)
/// which trait it's mutually exclusive with -- a real dialog rather than
/// a snackbar, since a snackbar auto-dismisses before a full sentence or
/// two is comfortably readable, and this is meant to be read carefully,
/// not glanced at. Public (not `TraitChip`-private) so anywhere else that
/// ever wants the same "tap a trait, learn what it does" behavior --
/// the HTML trait catalog doc's in-app counterpart -- can reuse it
/// without duplicating the dialog itself.
void showTraitExplanation(BuildContext context, Trait trait) {
  final theme = Theme.of(context);
  final opposite = oppositeOf(trait);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(trait.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trait.description),
          if (opposite != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mutually exclusive with ${opposite.label} -- a player never '
              'carries both.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
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
