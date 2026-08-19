import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_preferences.dart';
import '../../../app/app_spacing.dart';
import '../../../core/widgets/ad_banner_placeholder.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../match/presentation/live_game_lab_screen.dart';
import '../../matchup/domain/analyst.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../matchup/domain/matchup_analysis.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player.dart';
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
/// [scroll: Team Callouts, Offensive Shape, Team Strength, Starting
///          Lineups, The Analysts, Defensive Tactic]
/// [Play Game]                <- fixed
/// ```
///
/// Play Game runs the same `advanceGameDay` the Dashboard's "Advance to
/// Next Game Day" button already calls (this screen only ever gets pushed
/// in place of that direct call, on a day `nextOwnGame` says the GM's own
/// team is playing), then hands off to `GameResultScreen`. Every other
/// team's game that game day is still simulated the same instant,
/// background-sim way it always was -- this only changes what the GM sees
/// for their own.
///
/// Two new sections (2026-08-14, a direct GM ask following the "Coach's
/// Board" design artifact,
/// https://claude.ai/code/artifact/6f075bb0-8dc8-416c-9db1-e29b2c8a4ea6):
/// **Offensive Shape** shows both teams' automatically-detected
/// `OffenseShape` (`offense_shape.dart`) -- nothing to pick, just what
/// each starting five's positions already determine. **Defensive
/// Tactic**, the last thing in the scrolling body (below The Analysts),
/// is the one real GM choice on this screen -- 4 `DefensiveTactic`
/// options (`defensive_tactic.dart`), always defaulting to
/// `DefensiveTactic.balanced` on open (this widget's own local `State`,
/// never persisted, so a fresh visit always starts there even if a
/// clearly-better option existed last game). `_playGame` threads the pick
/// into `advanceGameDay`'s new `ownDefenseTactic` param.
///
/// **Starting Lineups** (formerly "Top Contributors," best 3 by overall)
/// switched to each side's real 5-player starting five (2026-08-14, a
/// same-session follow-up GM ask): "otherwise you won't know what to
/// choose for your defense" -- the GM needs to see who's actually on the
/// floor to make the Defensive Tactic call below, not just who's rated
/// highest.
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
  var _tactic = DefensiveTactic.balanced;

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;
    final game = widget.game;

    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);

    final rosters = rostersByAbbreviation(franchise);
    final homePlayers = rosters[game.homeTeamAbbreviation] ?? const <Player>[];
    final awayPlayers = rosters[game.awayTeamAbbreviation] ?? const <Player>[];

    // Same bench-order-vs-auto-sort convention `_simulateOneGame` actually
    // uses for this exact game -- the GM's own side reads its real bench
    // order, the opponent falls back to the automatic overall-based sort
    // -- so the shape shown here always matches what's about to be
    // simulated. `startingFiveFor`, not `startingFiveByMinutes` (which
    // needs a resolved 12-player target-minutes map) -- a lightweight
    // preview shouldn't have to satisfy that assertion.
    final ownAbbreviation = franchise.team.abbreviation;
    final homeStartingFive = startingFiveFor(
      homePlayers,
      isBenchOrdered: game.homeTeamAbbreviation == ownAbbreviation,
    );
    final awayStartingFive = startingFiveFor(
      awayPlayers,
      isBenchOrdered: game.awayTeamAbbreviation == ownAbbreviation,
    );
    final homeShape = detectOffenseShape(homeStartingFive);
    final awayShape = detectOffenseShape(awayStartingFive);

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

    // Only feeds the Analysts' "best single player" pick below -- the
    // screen's own lineup display uses the real starting five instead,
    // see `homeStartingFive`/`awayStartingFive` above.
    final homeTop3 = topPlayersFor(homePlayers);
    final awayTop3 = topPlayersFor(awayPlayers);
    final homeTopOverall = homeTop3.isEmpty
        ? 0
        : homeTop3.first.ratings.overall;
    final awayTopOverall = awayTop3.isEmpty
        ? 0
        : awayTop3.first.ratings.overall;

    final leaders = computeLeagueLeaders(franchise.seasonProgress.playedGames);

    // Seat 1 stays the generic fallback until the franchise's own
    // narrative veteran has actually retired -- keyed off the real,
    // trade-proof `narrativeVeteranRetired` flag
    // (`retirement_advancer.dart`'s `resolveNarrativeVeteranRetirement`),
    // not "not found on the GM's own roster" -- that old proxy broke the
    // instant she was traded to another team, showing the retired look
    // for someone still actively playing (2026-08-19, a direct GM report:
    // "if the new player trades away their star player right away...").
    final veteranAppearance = franchise.narrativeVeteranAppearance;
    final seat1 =
        (!franchise.narrativeVeteranRetired || veteranAppearance == null)
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
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: AdBannerPlaceholder(),
            ),
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
                    _OffenseShapesSection(
                      awayTeam: awayTeam,
                      awayShape: awayShape,
                      homeTeam: homeTeam,
                      homeShape: homeShape,
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
                    _StartingLineupsSection(
                      awayTeam: awayTeam,
                      homeTeam: homeTeam,
                      awayLineup: awayStartingFive,
                      homeLineup: homeStartingFive,
                      leaders: leaders,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AnalystsSection(
                      franchise: franchise,
                      verdicts: verdicts,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DefensiveTacticPicker(
                      selected: _tactic,
                      onSelected: (tactic) => setState(() => _tactic = tactic),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // "A per-game toggle... next to Play Game" (`TODO.md`
                  // item 8's live-game architecture stage 5, a locked
                  // design call) -- sits right above the button it governs,
                  // in this same fixed (never-scrolling) area.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Watch Live',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Switch(
                        value: ref.watch(watchLiveProvider),
                        onChanged: _isPlaying
                            ? null
                            : (value) =>
                                  ref.read(watchLiveProvider.notifier).state =
                                      value,
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: _isPlaying ? null : _playGame,
                    child: _isPlaying
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Play Game'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playGame() async {
    // Watch Live hands off to its own screen entirely -- that screen
    // drives `simulateMatchLive` itself, then folds the result into the
    // rest of today's schedule and navigates to `GameResultScreen` on its
    // own once the GM's own game actually finishes (`LiveGameLabScreen`'s
    // own doc comment). This screen's `_isPlaying` spinner is only for the
    // Sim Instantly path below, which resolves everything in one call.
    if (ref.read(watchLiveProvider)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveGameLabScreen(
            franchise: widget.franchise,
            game: widget.game,
            ownDefenseTactic: _tactic,
          ),
        ),
      );
      return;
    }

    setState(() => _isPlaying = true);
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceGameDay(ownDefenseTactic: _tactic);
    if (!mounted) return;

    final ownAbbreviation = widget.franchise.team.abbreviation;
    final ownGame = ownGameResultFrom(results, ownAbbreviation);

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
            GameResultScreen(franchise: updatedFranchise, result: ownGame),
      ),
    );
  }
}

/// Just a placeholder -- no ad SDK wired in yet (a direct GM call: "for
/// now, just a placeholder"). Fixed at the very top, above the header,
/// never part of the scrolling body below it.

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
              border: Border.all(color: Colors.black26, width: 0.5),
            ),
          ),
      ],
    );
  }
}

/// Both teams' automatically-detected [OffenseShape] side by side --
/// nothing for the GM to pick, just what each starting five's real
/// positions already determine (2026-08-14, a direct GM ask). Kept
/// visually separate from [_TeamStrengthSection] below on purpose: this
/// is a play-style explainer, not a roster-quality number.
class _OffenseShapesSection extends StatelessWidget {
  const _OffenseShapesSection({
    required this.awayTeam,
    required this.awayShape,
    required this.homeTeam,
    required this.homeShape,
  });

  final Team awayTeam;
  final OffenseShape awayShape;
  final Team homeTeam;
  final OffenseShape homeShape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Offensive Shape," not the bare "Offense" `_TeamStrengthSection`
          // already uses for its own bar label -- two different sections
          // both saying just "Offense" collides for anything that finds
          // by text.
          Text('Offensive Shape', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OffenseShapeColumn(team: awayTeam, shape: awayShape),
              ),
              Container(
                width: 1,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _OffenseShapeColumn(team: homeTeam, shape: homeShape),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OffenseShapeColumn extends StatelessWidget {
  const _OffenseShapeColumn({required this.team, required this.shape});

  final Team team;
  final OffenseShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${team.emoji} ${team.abbreviation}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          shape.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          shape.why,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
    // Scaled rating differential relative to 50% midpoint:
    // A 1-point rating difference translates to a 2% bar width shift,
    // so a 7-point gap (e.g. 69 vs 76) clearly shows as 36% vs 64%.
    final diff = awayValue - homeValue;
    final awayPercent = (50 + (diff * 2.0)).round().clamp(10, 90);
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
                        child: Container(height: 8, color: kAwayStrengthColor),
                      ),
                      Expanded(
                        flex: homePercent,
                        child: Container(height: 8, color: kHomeStrengthColor),
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
                        BoxShadow(color: Colors.black45, blurRadius: 1),
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

/// Each side's real 5-player starting lineup (same [startingFiveFor] the
/// Offensive Shape section and the match engine itself both read --
/// bench order for the GM's own team, best-by-overall for an AI
/// opponent), 2-line names, positions, ratings, and each player's top 3
/// counting stats per game. Was "Top Contributors" (best 3 by overall,
/// `topPlayersFor`) until a direct GM ask (2026-08-14): seeing who's
/// actually on the floor -- not just who's best -- is what a defensive
/// tactic pick (below) actually needs.
class _StartingLineupsSection extends StatelessWidget {
  const _StartingLineupsSection({
    required this.awayTeam,
    required this.homeTeam,
    required this.awayLineup,
    required this.homeLineup,
    required this.leaders,
  });

  final Team awayTeam;
  final Team homeTeam;
  final List<Player> awayLineup;
  final List<Player> homeLineup;
  final Map<String, PlayerSeasonTotals> leaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Starting Lineups', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          // IntrinsicHeight, not a fixed divider height -- 5 rows a side
          // need real room, and this way the divider always matches
          // whatever the content actually needs instead of a guessed
          // number.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LineupColumn(
                    team: awayTeam,
                    players: awayLineup,
                    leaders: leaders,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: _LineupColumn(
                    team: homeTeam,
                    players: homeLineup,
                    leaders: leaders,
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

class _LineupColumn extends StatelessWidget {
  const _LineupColumn({
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
          _LineupPlayerEntry(
            player: players[i],
            totals: leaders[players[i].id],
          ),
        ],
      ],
    );
  }
}

class _LineupPlayerEntry extends StatelessWidget {
  const _LineupPlayerEntry({required this.player, required this.totals});

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

/// The GM's one real choice on this screen -- 4 [DefensiveTactic] options,
/// each a tappable card carrying its own name and a quick shorthand of
/// what it is and when to use it (a direct GM ask, 2026-08-14: "I'd like
/// it if the choices had a quick shorthand... when you should use them" --
/// every option's blurb is visible at once, not hidden behind a tap). Not
/// a `SegmentedButton` (this codebase's usual 3-4-option picker, e.g.
/// Training Focus) on purpose -- that pattern only shows short labels, not
/// the descriptive text this specifically needs.
class _DefensiveTacticPicker extends StatelessWidget {
  const _DefensiveTacticPicker({
    required this.selected,
    required this.onSelected,
  });

  final DefensiveTactic selected;
  final ValueChanged<DefensiveTactic> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Defensive Tactic', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Always starts on Balanced -- pick something else only if you '
            'see a real edge.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final tactic in DefensiveTactic.values) ...[
            if (tactic != DefensiveTactic.values.first)
              const SizedBox(height: AppSpacing.xs),
            _TacticOption(
              tactic: tactic,
              isSelected: tactic == selected,
              onTap: () => onSelected(tactic),
            ),
          ],
        ],
      ),
    );
  }
}

class _TacticOption extends StatelessWidget {
  const _TacticOption({
    required this.tactic,
    required this.isSelected,
    required this.onTap,
  });

  final DefensiveTactic tactic;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tactic.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tactic.shorthand,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
