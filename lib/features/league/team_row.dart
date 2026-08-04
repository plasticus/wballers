import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import 'domain/team.dart';

/// A single team's identity: color swatch, name, abbreviation, and
/// location. Shared between `LeagueScreen` (standings/roster of teams) and
/// onboarding (browsing a conference's existing teams before naming your
/// own club).
class TeamRow extends StatelessWidget {
  const TeamRow({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Decorative only — the team name text next to it already
          // carries the information, so this doesn't need its own label.
          ExcludeSemantics(
            child: _ColorSwatch(
              color: team.colors.primary,
              borderColor: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: theme.textTheme.bodyLarge),
                Text(
                  '${team.abbreviation} · ${team.location}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({this.color, this.borderColor});

  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
    );
  }
}
