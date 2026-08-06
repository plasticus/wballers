import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../season/domain/standings_entry.dart';
import 'domain/team.dart';

/// A single team's identity: color swatch, name, abbreviation, and
/// location. Shared between `LeagueScreen` (standings/roster of teams) and
/// onboarding (browsing a conference's existing teams before naming your
/// own club).
class TeamRow extends StatelessWidget {
  const TeamRow({
    required this.team,
    this.isUserTeam = false,
    this.rank,
    this.record,
    super.key,
  });

  final Team team;

  /// True when this row is the GM's own club, shown in the league listing
  /// in place of the original team it replaced.
  final bool isUserTeam;

  /// This team's 1-based standing within its conference, if the caller is
  /// showing a ranked table (`LeagueScreen`) rather than a plain roster of
  /// teams (onboarding's conference browser, which leaves this `null`).
  final int? rank;

  /// This team's regular-season record so far, if there's a season to
  /// derive one from. `null` (rather than a 0-0 entry) is how a caller
  /// says "don't show a record at all" -- `LeagueScreen` always passes one
  /// once a franchise exists, onboarding never does.
  final StandingsEntry? record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
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
                Row(
                  children: [
                    Text(team.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(team.name, style: theme.textTheme.bodyLarge),
                    ),
                    if (isUserTeam) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Your Team',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${team.abbreviation} · ${team.location}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (record != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${record!.wins}-${record!.losses}',
              style: theme.textTheme.titleMedium,
            ),
          ],
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
