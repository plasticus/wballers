import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../draft/generation/draft_generator.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/achievement.dart';
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
/// crowned, reachable from the Dashboard's permanent trophy banner. The
/// real, computed ceremony (2026-08-11, `0D_Season_2_Roadmap.md`'s
/// Presentation stage, completing the whole Season 2 roadmap): champion,
/// [seasonAwardWinners], and starting the next season for real, all in
/// one place -- deliberately a plain, functional presentation rather
/// than a flashier animated moment, same posture every other
/// season-boundary system this pass built already carries.
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
  /// free-agent swap, or a real retirement) still gets a readable label
  /// instead of a crash. Checks [Franchise.formerPlayers] before falling
  /// back to the generic "Former Player" string -- a direct GM report
  /// (2026-08-19): a retired all-star showed up on this exact screen's
  /// Player Development section labeled "Former Player" instead of her
  /// own name (see `FormerPlayerRecord`'s own doc comment).
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
    for (final record in widget.franchise.formerPlayers) {
      if (record.playerId == playerId) return record.label;
    }
    return 'Former Player';
  }

  /// Transitions to the next season ([beginNextSeasonAndPersist]) and
  /// returns to the Dashboard -- a direct GM ask (2026-08-19): "It
  /// immediately dumps me to the draft. I don't like that ... Don't dump
  /// me right into the draft, feels stressful." [beginNextSeasonAndPersist]
  /// already leaves a fresh [Franchise.draftInProgress] behind
  /// (`season_transition_advancer.dart`), so the Dashboard's own
  /// "Draft In Progress" card (`_SeasonAdvanceCard`) picks it right back
  /// up with a "Return to Draft" button -- the GM gets a look at
  /// retirement/off-season mail first instead of being routed straight
  /// into the draft screen. The recap of a season that's already over has
  /// nothing left to show once a new one has started, so this doesn't
  /// stay on the back stack underneath the Dashboard either.
  Future<void> _beginNextSeason() async {
    setState(() => _isBeginning = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .beginNextSeasonAndPersist();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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

    final awardWinners = seasonAwardWinners(franchise);

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
                      'Eliminated from the Continental Cup in '
                      '${continentalCupRoundPhrase(cupEliminationRound)}.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Season Awards', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              awardWinners.isEmpty
                  ? 'No major individual awards were determined this '
                        'season.'
                  : '${awardWinners.length} award'
                        '${awardWinners.length == 1 ? '' : 's'} handed out '
                        'across the league.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < awardWinners.length; i++) ...[
              _AwardWinnerRow(
                winner: awardWinners[i],
                season: franchise.season,
              ),
              if (i != awardWinners.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            if (franchise.leagueRetirements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('League Retirements', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                franchise.leagueRetirements.length == 1
                    ? '1 player around the league retired this off-season.'
                    : '${franchise.leagueRetirements.length} players '
                          'around the league retired this off-season.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < franchise.leagueRetirements.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : AppSpacing.sm,
                        ),
                        child: Text(
                          '${franchise.leagueRetirements[i].primaryPosition.abbreviation} '
                          '${franchise.leagueRetirements[i].name} '
                          '(${franchise.leagueRetirements[i].teamAbbreviation})',
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
                    'Starting the new season: every roster ages up, a '
                    'fresh batch of free agents and draft prospects '
                    'arrives, and the draft plays out for real -- '
                    'you\'ll pick for your own team, and every AI team '
                    'fills out their roster too.',
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

/// One [SeasonAwardWinner], shown with their new nickname (every grant
/// auto-applies one, `achievement_grant.dart`'s `applyAchievementGrant`)
/// and a neon-hair-unlock note if this was their real 2nd career
/// achievement -- found by locating the matching [PlayerAchievementRecord]
/// in [Player.achievements] and checking its index, rather than a
/// separate flag, since nothing else tracks "did this specific grant
/// just cross the 2-achievement threshold."
class _AwardWinnerRow extends StatelessWidget {
  const _AwardWinnerRow({required this.winner, required this.season});

  final SeasonAwardWinner winner;
  final int season;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = winner.player;
    final recordIndex = player.achievements.indexWhere(
      (record) =>
          record.achievement == winner.achievement && record.season == season,
    );
    final justUnlockedHair = recordIndex == 1;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emoji_events, color: Colors.amber.shade700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner.achievement.label,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  winner.teamAbbreviation != null
                      ? '${player.name} (${winner.teamAbbreviation})'
                      : player.name,
                  style: theme.textTheme.bodyMedium,
                ),
                if (player.nickname != null)
                  Text(
                    '"${player.nickname}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (justUnlockedHair)
                  Text(
                    '✨ Neon hair color unlocked',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
