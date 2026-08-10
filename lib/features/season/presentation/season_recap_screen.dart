import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../draft/generation/draft_generator.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/position.dart';
import '../../training/domain/training_report.dart';
import '../../training/presentation/player_growth_card.dart';
import '../application/franchise_rosters.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import '../generation/continental_cup_generator.dart'
    show continentalCupEliminationRound;
import '../generation/postseason_generator.dart'
    show kPostseasonTeamCount, seasonChampion;

/// A completed season's landing page -- fires once a champion has been
/// crowned, reachable from the Dashboard's permanent trophy banner. This
/// is deliberately the **placeholder** version: a real end-of-season
/// ceremony (award winners, nicknames earned, neon hair unlocked) is real
/// follow-up work the GM explicitly deferred (`0B_Planned.md`'s
/// achievement/nickname-ceremony entry) rather than something to build
/// alongside the rest of this pass -- this screen exists so a finished
/// season has *somewhere* to land beyond a bare trophy line, not to be
/// that ceremony itself.
class SeasonRecapScreen extends StatelessWidget {
  const SeasonRecapScreen({required this.franchise, super.key});

  final Franchise franchise;

  /// Same lookup-with-fallback `TrainingReportScreen`'s own `_playerLabel`
  /// already established -- a player who's since left the roster (a
  /// free-agent swap; there's no trade system yet) still gets a readable
  /// label instead of a crash.
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
    return 'Former Player';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playedGames = franchise.seasonProgress.playedGames;
    final championAbbreviation = seasonChampion(playedGames);
    final isChampion = championAbbreviation == franchise.team.abbreviation;

    final leagueTeams = [
      franchise.team,
      for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
    ];
    final standings = currentStandings(franchise.seasonProgress, leagueTeams);
    final ownRecord = recordFor(franchise.team.abbreviation, standings);

    final ownPostseasonGames = playedGames.where(
      (played) =>
          played.game.type == GameType.postseason &&
          (played.game.homeTeamAbbreviation == franchise.team.abbreviation ||
              played.game.awayTeamAbbreviation == franchise.team.abbreviation),
    );
    final madePlayoffs = ownPostseasonGames.isNotEmpty;
    final deepestRound = madePlayoffs
        ? ownPostseasonGames
              .map((played) => played.game.postseasonRound!)
              .reduce((a, b) => a > b ? a : b)
        : null;

    final cupEliminationRound = continentalCupEliminationRound(
      playedGames,
      franchise.team.abbreviation,
    );

    // A projection, not a real pick -- there's no Season 2 draft-day flow
    // to actually make it in yet (2026-08-10, TODO.md item 13). Reseeded
    // fresh every render off the franchise's own seed, same
    // never-persisted posture `player_market_preview_generator.dart`'s
    // Draft tab preview already established for the prospect class.
    // `generateDraftOrder` needs a real lottery field (more teams than
    // make the playoffs) to work at all -- guards a full league always
    // satisfies, but a handful of tests build a deliberately thin
    // standings table that wouldn't.
    final draftPosition = standings.length > kPostseasonTeamCount
        ? generateDraftOrder(
                Random(franchise.simulationSeed + kDraftOrderSeedOffset),
                standings,
              ).indexOf(franchise.team.abbreviation) +
              1
        : null;

    final seasonGrowth =
        aggregateSeasonGrowth(
          weeklyReports: franchise.trainingReports,
          seasonEndAging: franchise.seasonEndAgingResults,
        )..sort(
          (a, b) =>
              totalPlayerGrowthDelta(b).compareTo(totalPlayerGrowthDelta(a)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Season Recap')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isChampion
                        ? '🏆 You are the champions!'
                        : championAbbreviation == null
                        ? 'The season is complete.'
                        : '🏆 ${teamByAbbreviation(franchise, championAbbreviation).name} '
                              'are the champions.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Final record: ${ownRecord.wins}-${ownRecord.losses}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isChampion
                        ? 'You won it all this season.'
                        : madePlayoffs
                        ? 'Your season ended in the '
                              '${_postseasonRoundLabel(deepestRound!)}.'
                        : 'You missed the playoffs this season.',
                  ),
                  if (cupEliminationRound != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Eliminated from the Continental Cup in the '
                      '${continentalCupRoundName(cupEliminationRound)}.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Player Development', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              seasonGrowth.isEmpty
                  ? 'No development results recorded this season.'
                  : '${seasonGrowth.length} player'
                        '${seasonGrowth.length == 1 ? '' : 's'} changed -- '
                        'the whole season\'s training plus the off-season '
                        'conditioning that follows it.',
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
            if (draftPosition != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Draft', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Projected pick: #$draftPosition overall '
                      '(off this season\'s final standings -- not locked '
                      'in until a real draft-day flow exists).',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What\'s Next', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'A real end-of-season ceremony -- award winners, '
                    'nicknames earned, and starting a new season with an '
                    'aged-up roster and a fresh draft class -- is coming in '
                    'a future update. For now, you can still browse '
                    'everything that happened this season from the '
                    'Results and Mail tabs.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UI-only formatting, same "not worth a domain-level label extension"
/// reasoning as `schedule_screen.dart`'s own round-name helper.
String _postseasonRoundLabel(int round) {
  return switch (round) {
    1 => 'First Round',
    2 => 'Semifinals',
    _ => 'Finals',
  };
}
