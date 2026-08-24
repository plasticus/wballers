import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/position.dart';
import '../domain/training_report.dart';
import 'player_growth_card.dart';

/// A live, always-current view of every roster player's total stat-field
/// growth so far this season -- unlike `TrainingReportScreen` (one
/// week's own results) or `SeasonRecapScreen`'s "Player Development"
/// section (only reachable once the season is over), this is meant to
/// be checked mid-season, any time, from the Training page (2026-08-10,
/// TODO.md item 5). Reuses `aggregateSeasonGrowth`/`PlayerGrowthCard`
/// the exact same way the recap screen does, with one deliberate
/// difference: [Franchise.seasonEndAgingResults] is never folded in --
/// that lump doesn't exist until the season actually ends, so including
/// it here would show either stale data from last season or growth that
/// hasn't happened yet.
class SeasonToDateReportScreen extends StatelessWidget {
  const SeasonToDateReportScreen({required this.franchise, super.key});

  final Franchise franchise;

  /// Mirrors `TrainingReportScreen`/`SeasonRecapScreen`'s own
  /// `_playerLabel` -- kept in sync by hand, same as those two.
  String _playerLabel(String playerId) {
    for (final membership in franchise.roster) {
      if (membership.player.id == playerId) {
        final player = membership.player;
        final jersey = player.jerseyNumber != null
            ? '#${player.jerseyNumber} '
            : '';
        return '${player.primaryPosition.abbreviation} $jersey${player.name}';
      }
    }
    // Waived (`dropPlayer`) since training resolved -- released, not
    // vanished, so she's still sitting right in `Franchise.freeAgents`
    // with her real name (2026-08-23, a direct GM report: a couple of
    // clearly-real, distinctly-different bench players -- different
    // trait bumps, different OVRs -- both showed up here as the exact
    // same generic "Former Player" label; this check was simply
    // missing, even though this screen's own retirement-era doc comment
    // already claimed to cover "a free-agent swap").
    for (final player in franchise.freeAgents) {
      if (player.id == playerId) {
        return '${player.primaryPosition.abbreviation} ${player.name}';
      }
    }
    // A real retirement mid-season -- her name still survives in
    // `Franchise.formerPlayers` (see `FormerPlayerRecord`'s own doc
    // comment).
    for (final record in franchise.formerPlayers) {
      if (record.playerId == playerId) return record.label;
    }
    // Shouldn't happen otherwise -- a player traded away to an AI team
    // is the one remaining gap (her name lives on that team's own
    // roster, which this lookup doesn't scan) -- but a label beats a
    // crash if a player was somehow since removed from the save with no
    // trace at all.
    return 'Former Player';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seasonGrowth =
        aggregateSeasonGrowth(
          weeklyReports: franchise.trainingReports,
          seasonEndAging: const [],
        )..sort(
          (a, b) =>
              totalPlayerGrowthDelta(b).compareTo(totalPlayerGrowthDelta(a)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Season To Date Report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              seasonGrowth.isEmpty
                  ? 'No training has resolved yet this season.'
                  : '${seasonGrowth.length} player'
                        '${seasonGrowth.length == 1 ? '' : 's'} moved so '
                        'far this season, most improved first.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < seasonGrowth.length; i++) ...[
              PlayerGrowthCard(
                playerName: _playerLabel(seasonGrowth[i].playerId),
                result: seasonGrowth[i],
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md, top: 2),
                child: Text(
                  'OVR: ${seasonGrowth[i].overallBefore} -> '
                  '${seasonGrowth[i].overallAfter} '
                  '(${seasonGrowth[i].overallDelta >= 0 ? '+' : ''}'
                  '${seasonGrowth[i].overallDelta})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (i != seasonGrowth.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
