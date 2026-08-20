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
    this.overall,
    this.onTap,
    super.key,
  });

  final Team team;

  /// Pushes a real detail screen when given (`LeagueScreen`'s AI-team
  /// rows only, `TeamDetailScreen` -- 2026-08-20, a direct GM ask) --
  /// `null` (the default) leaves the row a plain, non-interactive listing,
  /// same as every caller before this existed (onboarding's conference
  /// browser, and `LeagueScreen`'s own row for the GM's own club, which
  /// already has a richer detail screen of its own, the Team tab).
  final VoidCallback? onTap;

  /// This team's overall rating (`teamOverallForPlayers`), if the caller
  /// has a roster to derive one from. `null` hides it entirely --
  /// onboarding's conference browser has no rosters yet to compute from.
  /// Surfaced per a direct GM ask after a 126-85 blowout loss: "I don't
  /// know OVR team scores... I don't know if I'm a 70 going up against a
  /// 90."
  final int? overall;

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
    final row = Container(
      // A background tint instead of a "Your Team" text chip (a direct GM
      // ask, 2026-08-09: "just highlight your team in a color") -- the row
      // itself now carries the signal, so nothing needs to compete with
      // the team name for space on narrow screens. Rounded so the tint
      // reads as a deliberate highlight, not a stray full-bleed band.
      decoration: isUserTeam
          ? BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: isUserTeam ? AppSpacing.sm : 0,
      ),
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
                      child: Semantics(
                        // The tint alone doesn't announce anything to a
                        // screen reader the way the old "Your Team" chip's
                        // own text did -- this keeps that announcement
                        // without needing the chip's on-screen space back.
                        label: isUserTeam ? '${team.name}, Your Team' : null,
                        child: ExcludeSemantics(
                          excluding: isUserTeam,
                          child: Text(
                            team.name,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  overall != null
                      ? '${team.abbreviation} · ${team.location} · '
                            '$overall OVR'
                      : '${team.abbreviation} · ${team.location}',
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
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
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
