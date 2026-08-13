import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../matchup/domain/analyst.dart';
import '../../matchup/domain/matchup_analysis.dart';
import '../../player/domain/player.dart';
import '../../player/domain/position.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../roster/domain/team_overall.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/game_result.dart';
import '../domain/league_leaders.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import 'game_result_screen.dart';

const kAwayStrengthColor = Color(0xFFFF8A00); // Vivid Orange
const kHomeStrengthColor = Color(0xFF10B981); // Emerald Green
const kFormWinColor = Color(0xFF22C55E); // High-contrast crisp green
const kFormLossColor = Color(0xFFEF4444); // High-contrast bright red

/// Shown before the GM's own scheduled game actually simulates -- a direct
/// GM ask ("there should be some kind of splash before my games, not just
/// straight to the result"), grown into a full "Matchup Analysis" screen
/// through a 3-round design lab (2026-08-12,
/// https://claude.ai/code/artifact/1323d3db-6fe2-49e7-90dc-417388e4b4a0),
/// GM-confirmed final ("Card A is perfect... mark it down as the thing
/// we're going to do," `TODO.md`'s former item 1).
///
/// Structure, top to bottom -- an ad banner placeholder and the header are
/// fixed and never scroll; the analysis itself scrolls; Play Game is
/// pinned at the bottom and never scrolls either:
///
/// ```
/// [ad placeholder]           <- fixed
/// Matchup Analysis           <- fixed
/// [scroll: Team Callouts, Team Strength, Top Contributors, The Analysts]
/// [Play Game]                <- fixed
/// ```
///
/// The single thing that actually does anything here is still the Play
/// Game button: it runs the same `advanceGameDay` the Dashboard's "Advance
/// to Next Game Day" button already calls (this screen only ever gets
/// pushed in place of that direct call, on a day `nextOwnGame` says the
/// GM's own team is playing), then hands off to `GameResultScreen`. Every
/// other team's game that game day is still simulated the same instant,
/// background-sim way it always was -- this only changes what the GM sees
/// for their own.
class MatchPreviewScreen extends ConsumerStatefulWidget {
  const MatchPreviewScreen({
    required this.franchise,
    required this.game,
    super.key,
  });

  final Franchise franchise;
  final ScheduledGame game;

  @override
  ConsumerState<MatchPreviewScreen> createState() => _MatchPreviewScreenState();
}

class _MatchPreviewScreenState extends ConsumerState<MatchPreviewScreen> {
  var _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;
    final game = widget.game;

    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);

    final rosters = rostersByAbbreviation(franchise);
    final homePlayers = rosters[game.homeTeamAbbreviation] ?? const <Player>[];
    final awayPlayers = rosters[game.awayTeamAbbreviation] ?? const <Player>[];

    final homeOverall = teamOverallForPlayers(homePlayers);
    final awayOverall = teamOverallForPlayers(awayPlayers);

    final standings = currentStandings(
      franchise.seasonProgress,
      allLeagueTeams(franchise),
    );
    final homeRecord = recordFor(game.homeTeamAbbreviation, standings);
    final awayRecord = recordFor(game.awayTeamAbbreviation, standings);

    final homeForm = recentResultsFor(
      franchise.seasonProgress,
      game.homeTeamAbbreviation,
    );
    final awayForm = recentResultsFor(
      franchise.seasonProgress,
      game.awayTeamAbbreviation,
    );

    final homeOffense = teamCompositeRating(
      homePlayers,
      (r) => r.offenseOverall,
    );
    final awayOffense = teamCompositeRating(
      awayPlayers,
      (r) => r.offenseOverall,
    );
    final homeDefense = teamCompositeRating(
      homePlayers,
      (r) => r.defenseOverall,
    );
    final awayDefense = teamCompositeRating(
      awayPlayers,
      (r) => r.defenseOverall,
    );
    final homePhysical = teamCompositeRating(
      homePlayers,
      (r) => r.physicalOverall,
    );
    final awayPhysical = teamCompositeRating(
      awayPlayers,
      (r) => r.physicalOverall,
    );

    final homeTop3 = topPlayersFor(homePlayers);
    final awayTop3 = topPlayersFor(awayPlayers);
    final homeTopOverall = homeTop3.isEmpty
        ? 0
        : homeTop3.first.ratings.overall;
    final awayTopOverall = awayTop3.isEmpty
        ? 0
        : awayTop3.first.ratings.overall;

    final leaders = computeLeagueLeaders(
      franchise.seasonProgress.playedGames,
    );

    // Seat 1 stays the generic fallback until the franchise's own
    // narrative veteran has actually left the roster -- see
    // `Franchise.narrativeVeteranPlayerId`'s own doc comment for why
    // "not found in roster" reliably means "retired" today.
    final veteranStillActive = franchise.roster.any(
      (m) => m.player.id == franchise.narrativeVeteranPlayerId,
    );
    final veteranAppearance = franchise.narrativeVeteranAppearance;
    final seat1 = (veteranStillActive || veteranAppearance == null)
        ? kNarrativeVeteranSeatFallback
        : Analyst(
            name: franchise.narrativeVeteranName,
            appearance: asAnalystPortrait(veteranAppearance),
          );
    final panel = [
      seat1,
      kAnalystReyes,
      kAnalystShoemaker,
      kAnalystAdebayo,
      kAnalystValeJones,
    ];

    final verdicts = analystVerdicts(
      panel: panel,
      homeAbbreviation: game.homeTeamAbbreviation,
      awayAbbreviation: game.awayTeamAbbreviation,
      homeOffense: homeOffense,
      awayOffense: awayOffense,
      homeDefense: homeDefense,
      awayDefense: awayDefense,
      homePhysical: homePhysical,
      awayPhysical: awayPhysical,
      homeOverall: homeOverall,
      awayOverall: awayOverall,
      homeTopPlayerOverall: homeTopOverall,
      awayTopPlayerOverall: awayTopOverall,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AdBannerPlaceholder(),
            _MatchupHeader(game: game),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TeamCallouts(
                      awayTeam: awayTeam,
                      awayRecord: awayRecord,
                      awayForm: awayForm,
                      awayOverall: awayOverall,
                      homeTeam: homeTeam,
                      homeRecord: homeRecord,
                      homeForm: homeForm,
                      homeOverall: homeOverall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TeamStrengthSection(
                      awayTeam: awayTeam,
                      homeTeam: homeTeam,
                      awayOffense: awayOffense,
                      homeOffense: homeOffense,
                      awayDefense: awayDefense,
                      homeDefense: homeDefense,
                      awayPhysical: awayPhysical,
                      homePhysical: homePhysical,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TopContributorsSection(
                      awayTeam: awayTeam,
                      homeTeam: homeTeam,
                      awayTop3: awayTop3,
                      homeTop3: homeTop3,
                      leaders: leaders,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AnalystsSection(
                      franchise: franchise,
                      verdicts: verdicts,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isPlaying ? null : _playGame,
                  child: _isPlaying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Play Game'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playGame() async {
    setState(() => _isPlaying = true);
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceGameDay();
    if (!mounted) return;

    final ownAbbreviation = widget.franchise.team.abbreviation;
    GameResult? ownGame;
    if (results != null) {
      for (final result in results) {
        if (result.game.homeTeamAbbreviation == ownAbbreviation ||
            result.game.awayTeamAbbreviation == ownAbbreviation) {
          ownGame = result;
          break;
        }
      }
    }

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (!mounted) return;

    if (updatedFranchise == null || ownGame == null) {
      // Shouldn't normally happen -- this screen only ever gets pushed
      // when `nextOwnGame` found a game for today -- but fail safely back
      // to the Dashboard rather than leaving the button stuck spinning.
      setState(() => _isPlaying = false);
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            GameResultScreen(franchise: updatedFranchise, result: ownGame!),
      ),
    );
  }
}

/// Just a placeholder -- no ad SDK wired in yet (a direct GM call: "for
/// now, just a placeholder"). Fixed at the very top, above the header,
/// never part of the scrolling body below it.
class _AdBannerPlaceholder extends StatelessWidget {
  const _AdBannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
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

/// "Matchup Analysis" plus the game's type/week/date -- fixed, above the
/// scrolling body. Bold and accent-colored when [ScheduledGame.type]
/// doesn't count toward standings, same callout the screen always gave a
/// preseason/exhibition game.
class _MatchupHeader extends StatelessWidget {
  const _MatchupHeader({required this.game});

  final ScheduledGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Matchup Analysis', style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            '${game.typeLabel} · Week ${game.week} · '
            '${formatFictionalDate(game.week, game.day)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: game.countsTowardStandings
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              fontWeight: game.countsTowardStandings ? null : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoji, name, current record, and OVR rating for both sides on one row,
/// "@" between, with each side's last-5 form streak folded in underneath.
class _TeamCallouts extends StatelessWidget {
  const _TeamCallouts({
    required this.awayTeam,
    required this.awayRecord,
    required this.awayForm,
    required this.awayOverall,
    required this.homeTeam,
    required this.homeRecord,
    required this.homeForm,
    required this.homeOverall,
  });

  final Team awayTeam;
  final StandingsEntry awayRecord;
  final List<bool> awayForm;
  final int awayOverall;
  final Team homeTeam;
  final StandingsEntry homeRecord;
  final List<bool> homeForm;
  final int homeOverall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TeamCallout(
              team: awayTeam,
              record: awayRecord,
              overall: awayOverall,
              form: awayForm,
              alignEnd: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              '@',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _TeamCallout(
              team: homeTeam,
              record: homeRecord,
              overall: homeOverall,
              form: homeForm,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCallout extends StatelessWidget {
  const _TeamCallout({
    required this.team,
    required this.record,
    required this.overall,
    required this.form,
    required this.alignEnd,
  });

  final Team team;
  final StandingsEntry record;
  final int overall;
  final List<bool> form;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              Text(team.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                team.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                softWrap: true,
                textAlign: alignEnd ? TextAlign.right : TextAlign.left,
              ),
            ),
            if (alignEnd) ...[
              const SizedBox(width: 4),
              Text(team.emoji, style: const TextStyle(fontSize: 20)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignEnd) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$overall OVR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '${record.wins}-${record.losses}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!alignEnd) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$overall OVR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _FormDots(results: form, alignEnd: alignEnd),
      ],
    );
  }
}

/// Last-5 form streak, one dot per game (oldest first, matching
/// [recentResultsFor]'s own order) -- filled for a win, hollow for a
/// loss with high contrast colors.
class _FormDots extends StatelessWidget {
  const _FormDots({required this.results, required this.alignEnd});

  final List<bool> results;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      children: [
        for (final win in results)
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: win ? kFormWinColor : kFormLossColor,
              border: Border.all(
                color: Colors.black26,
                width: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// Offense/Defense/Physical, each a comparison bar split proportionally
/// between the two teams' [teamCompositeRating]s with high contrast colors
/// and a prominent 50% midpoint hashmark.
class _TeamStrengthSection extends StatelessWidget {
  const _TeamStrengthSection({
    required this.awayTeam,
    required this.homeTeam,
    required this.awayOffense,
    required this.homeOffense,
    required this.awayDefense,
    required this.homeDefense,
    required this.awayPhysical,
    required this.homePhysical,
  });

  final Team awayTeam;
  final Team homeTeam;
  final double awayOffense;
  final double homeOffense;
  final double awayDefense;
  final double homeDefense;
  final double awayPhysical;
  final double homePhysical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Team Strength', style: theme.textTheme.titleMedium),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAwayStrengthColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    awayTeam.abbreviation,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kHomeStrengthColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    homeTeam.abbreviation,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StrengthBar(
            label: 'Offense',
            awayValue: awayOffense,
            homeValue: homeOffense,
          ),
          _StrengthBar(
            label: 'Defense',
            awayValue: awayDefense,
            homeValue: homeDefense,
          ),
          _StrengthBar(
            label: 'Physical',
            awayValue: awayPhysical,
            homeValue: homePhysical,
          ),
        ],
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({
    required this.label,
    required this.awayValue,
    required this.homeValue,
  });

  final String label;
  final double awayValue;
  final double homeValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = awayValue + homeValue;
    final awayShare = total <= 0 ? 0.5 : awayValue / total;
    final awayPercent = (awayShare * 100).round().clamp(1, 99);
    final homePercent = 100 - awayPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${awayValue.round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kAwayStrengthColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                '${homeValue.round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kHomeStrengthColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: awayPercent,
                        child: Container(
                          height: 8,
                          color: kAwayStrengthColor,
                        ),
                      ),
                      Expanded(
                        flex: homePercent,
                        child: Container(
                          height: 8,
                          color: kHomeStrengthColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 50% Center Hashmark
                Center(
                  child: Container(
                    width: 2,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 1,
                        ),
                      ],
                    ),
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

/// Each side's best 3 players by overall with 2-line names, positions,
/// ratings, and their top 3 counting stats per game.
class _TopContributorsSection extends StatelessWidget {
  const _TopContributorsSection({
    required this.awayTeam,
    required this.homeTeam,
    required this.awayTop3,
    required this.homeTop3,
    required this.leaders,
  });

  final Team awayTeam;
  final Team homeTeam;
  final List<Player> awayTop3;
  final List<Player> homeTop3;
  final Map<String, PlayerSeasonTotals> leaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Top Contributors', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ContributorColumn(
                  team: awayTeam,
                  players: awayTop3,
                  leaders: leaders,
                ),
              ),
              Container(
                width: 1,
                height: 220,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _ContributorColumn(
                  team: homeTeam,
                  players: homeTop3,
                  leaders: leaders,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContributorColumn extends StatelessWidget {
  const _ContributorColumn({
    required this.team,
    required this.players,
    required this.leaders,
  });

  final Team team;
  final List<Player> players;
  final Map<String, PlayerSeasonTotals> leaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${team.emoji} ${team.name}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          softWrap: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < players.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _ContributorPlayerEntry(
            player: players[i],
            totals: leaders[players[i].id],
          ),
        ],
      ],
    );
  }
}

class _ContributorPlayerEntry extends StatelessWidget {
  const _ContributorPlayerEntry({
    required this.player,
    required this.totals,
  });

  final Player player;
  final PlayerSeasonTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PositionBadge(position: player.primaryPosition),
            const SizedBox(width: 4),
            Text(
              '${player.ratings.overall} OVR',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          player.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          softWrap: true,
        ),
        const SizedBox(height: 1),
        Text(
          topThreeStatLine(totals),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
          maxLines: 2,
          softWrap: true,
        ),
      ],
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        position.abbreviation,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 5 named panelists, each with a real in-game-generated portrait and a
/// pick shown as the team's emoji -- no reasoning surfaced (a direct GM
/// call from the design lab), plus a final tally.
class _AnalystsSection extends StatelessWidget {
  const _AnalystsSection({
    required this.franchise,
    required this.verdicts,
    required this.homeTeam,
    required this.awayTeam,
  });

  final Franchise franchise;
  final List<AnalystVerdict> verdicts;
  final Team homeTeam;
  final Team awayTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeCount = verdicts
        .where((v) => v.pickedTeamAbbreviation == homeTeam.abbreviation)
        .length;
    final awayCount = verdicts.length - homeCount;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('The Analysts', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < verdicts.length; i++)
            _AnalystRow(
              franchise: franchise,
              verdict: verdicts[i],
              // Seat 1's ownerId is keyed off the franchise's own
              // narrative-veteran id (even while she's still active and
              // the fallback look is showing) so a save's cached
              // portrait never collides with another save's -- see
              // `PortraitImage`'s own cache-key doc comment.
              ownerId: i == 0
                  ? 'analyst-seat1-${franchise.narrativeVeteranPlayerId}'
                  : 'analyst-${verdicts[i].analyst.name}',
              pickedTeam:
                  verdicts[i].pickedTeamAbbreviation == homeTeam.abbreviation
                  ? homeTeam
                  : awayTeam,
            ),
          const Divider(height: AppSpacing.md),
          Center(
            child: Text(
              '${homeTeam.emoji} $homeCount — $awayCount ${awayTeam.emoji}',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalystRow extends StatelessWidget {
  const _AnalystRow({
    required this.franchise,
    required this.verdict,
    required this.ownerId,
    required this.pickedTeam,
  });

  final Franchise franchise;
  final AnalystVerdict verdict;
  final String ownerId;
  final Team pickedTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipOval(
            child: PortraitImage(
              saveId: franchise.id,
              ownerId: ownerId,
              appearance: verdict.analyst.appearance,
              size: 36,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              verdict.analyst.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(pickedTeam.emoji, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
