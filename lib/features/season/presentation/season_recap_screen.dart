import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../draft/generation/draft_generator.dart';
import '../../draft/presentation/draft_day_screen.dart';
import '../../franchise/application/current_franchise_provider.dart';
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
/// is deliberately the **placeholder** version for the *ceremony* half:
/// award winners, nicknames earned, and neon hair unlocked are real
/// follow-up work the GM explicitly deferred (`0B_Planned.md`'s
/// achievement/nickname-ceremony entry) rather than something to build
/// alongside the rest of this pass. The season-*transition* half is real
/// now, though (2026-08-11, `0D_Season_2_Roadmap.md`'s "The draft, for
/// real" stage) -- see [_BeginNextSeasonButton].
class SeasonRecapScreen extends ConsumerStatefulWidget {
  const SeasonRecapScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  ConsumerState<SeasonRecapScreen> createState() => _SeasonRecapScreenState();
}

class _SeasonRecapScreenState extends ConsumerState<SeasonRecapScreen> {
  var _isBeginning = false;

  /// Same lookup-with-fallback `TrainingReportScreen`'s own `_playerLabel`
  /// already established -- a player who's since left the roster (a
  /// free-agent swap; there's no trade system yet) still gets a readable
  /// label instead of a crash.
  String _playerLabel(String playerId) {
    for (final membership in widget.franchise.roster) {
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

  /// Transitions to the next season ([beginNextSeasonAndPersist]) and
  /// replaces this screen with [DraftDayScreen] -- the recap of a season
  /// that's already over has nothing left to show once a new one has
  /// started, so this doesn't stay on the back stack underneath it.
  Future<void> _beginNextSeason() async {
    setState(() => _isBeginning = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .beginNextSeasonAndPersist();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DraftDayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;
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

    // Still just a projection, not the real pick -- this re-derives its
    // own lottery roll off kDraftOrderSeedOffset (the preview-only
    // stream), separate from the real draft order beginNextSeason
    // actually computes off kRealDraftOrderSeedOffset once the GM taps
    // "Begin Next Season" below (2026-08-11, 0D_Season_2_Roadmap.md's
    // "The draft, for real" stage) -- the two seeds are deliberately
    // different streams, so this number can land close to, but isn't
    // guaranteed to exactly match, the real pick. `generateDraftOrder`
    // needs a real lottery field (more teams than make the playoffs) to
    // work at all -- guards a full league always satisfies, but a
    // handful of tests build a deliberately thin standings table that
    // wouldn't.
    final draftPosition = standings.length > kPostseasonTeamCount
        ? generateDraftOrder(
                Random(franchise.seasonSeed + kDraftOrderSeedOffset),
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
                      'Rough estimate: #$draftPosition overall, off this '
                      'season\'s final standings -- the real lottery runs '
                      'when you begin the next season below, so the exact '
                      'pick may land a little differently.',
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
                    'nicknames earned, neon hair unlocked -- is coming in a '
                    'future update. Starting the new season itself is real '
                    'right now, though: every roster ages up, a fresh '
                    'batch of free agents and draft prospects arrives, and '
                    'the draft plays out for real -- you\'ll pick for your '
                    'own team, and every AI team fills out their roster too.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _isBeginning ? null : _beginNextSeason,
                    icon: _isBeginning
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Begin Next Season'),
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
