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
import '../../portrait/presentation/portrait_image.dart';
import '../../roster/domain/team_overall.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/game_result.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import 'game_result_screen.dart';

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
/// [scroll: Team Callouts, Team Strength, Top 3, The Analysts]
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
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TeamCallouts(
                      awayTeam: awayTeam,
                      awayRecord: awayRecord,
                      awayForm: awayForm,
                      homeTeam: homeTeam,
                      homeRecord: homeRecord,
                      homeForm: homeForm,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TeamStrengthSection(
                      awayOffense: awayOffense,
                      homeOffense: homeOffense,
                      awayDefense: awayDefense,
                      homeDefense: homeDefense,
                      awayPhysical: awayPhysical,
                      homePhysical: homePhysical,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TopThreeSection(awayTop3: awayTop3, homeTop3: homeTop3),
                    const SizedBox(height: AppSpacing.lg),
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
              padding: const EdgeInsets.all(AppSpacing.lg),
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
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
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
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
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

/// Emoji, name, and current record for both sides on one row, "@"
/// between -- round 1's own layout, the GM's confirmed favorite -- with
/// each side's last-5 form streak folded in underneath (round 2's own
/// addition).
class _TeamCallouts extends StatelessWidget {
  const _TeamCallouts({
    required this.awayTeam,
    required this.awayRecord,
    required this.awayForm,
    required this.homeTeam,
    required this.homeRecord,
    required this.homeForm,
  });

  final Team awayTeam;
  final StandingsEntry awayRecord;
  final List<bool> awayForm;
  final Team homeTeam;
  final StandingsEntry homeRecord;
  final List<bool> homeForm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamCallout(
                team: awayTeam,
                record: awayRecord,
                form: awayForm,
                alignEnd: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('@', style: Theme.of(context).textTheme.labelMedium),
            ),
            Expanded(
              child: _TeamCallout(
                team: homeTeam,
                record: homeRecord,
                form: homeForm,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCallout extends StatelessWidget {
  const _TeamCallout({
    required this.team,
    required this.record,
    required this.form,
    required this.alignEnd,
  });

  final Team team;
  final StandingsEntry record;
  final List<bool> form;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final row = [
      Text(team.emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          team.name,
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: alignEnd ? row.reversed.toList() : row,
        ),
        const SizedBox(height: 2),
        Text(
          '${record.wins}-${record.losses}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        _FormDots(results: form, alignEnd: alignEnd),
      ],
    );
  }
}

/// Last-5 form streak, one dot per game (oldest first, matching
/// [recentResultsFor]'s own order) -- filled for a win, hollow for a
/// loss.
class _FormDots extends StatelessWidget {
  const _FormDots({required this.results, required this.alignEnd});

  final List<bool> results;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      children: [
        for (final win in results)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: win ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

/// Offense/Defense/Physical, each a comparison bar split proportionally
/// between the two teams' [teamCompositeRating]s.
class _TeamStrengthSection extends StatelessWidget {
  const _TeamStrengthSection({
    required this.awayOffense,
    required this.homeOffense,
    required this.awayDefense,
    required this.homeDefense,
    required this.awayPhysical,
    required this.homePhysical,
  });

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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Team Strength', style: theme.textTheme.titleMedium),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: awayPercent,
                  child: Container(
                    height: 8,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Expanded(
                  flex: homePercent,
                  child: Container(height: 8, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Each side's best 3 players by overall, name/position/rating lined up
/// name-outside-stat-centered -- an alignment bug (names crowding the
/// other team's numbers) caught and fixed during the design lab.
class _TopThreeSection extends StatelessWidget {
  const _TopThreeSection({required this.awayTop3, required this.homeTop3});

  final List<Player> awayTop3;
  final List<Player> homeTop3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowCount = awayTop3.length > homeTop3.length
        ? awayTop3.length
        : homeTop3.length;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Top 3, Head to Head', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < rowCount; i++)
              _TopThreeRow(
                away: i < awayTop3.length ? awayTop3[i] : null,
                home: i < homeTop3.length ? homeTop3[i] : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopThreeRow extends StatelessWidget {
  const _TopThreeRow({required this.away, required this.home});

  final Player? away;
  final Player? home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: away == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      _PositionBadge(position: away!.primaryPosition),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          away!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              away == null ? '' : '${away!.ratings.overall}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              home == null ? '' : '${home!.ratings.overall}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: home == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          home!.name,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PositionBadge(position: home!.primaryPosition),
                    ],
                  ),
          ),
        ],
      ),
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
      child: Padding(
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
            const Divider(height: AppSpacing.lg),
            Center(
              child: Text(
                '${homeTeam.emoji} $homeCount — $awayCount ${awayTeam.emoji}',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
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
