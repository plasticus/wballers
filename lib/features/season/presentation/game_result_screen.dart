import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/injury_report_entry.dart';
import '../../league/domain/team.dart';
import '../../match/domain/player_box_score.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player_injury.dart';
import '../../player/domain/position.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/team_overall.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_result.dart';
import '../domain/scheduled_game.dart';

/// The final result of one game, shown right after it's simulated -- box
/// score and all. This is the transient window `GameDayAdvance.gamesPlayed`
/// exists for: once this screen is gone, only the lean `PlayedGame`
/// (fixture + final score) survives in the save, so this is the one place
/// a full box score is ever visible for a given game.
class GameResultScreen extends StatelessWidget {
  const GameResultScreen({
    required this.franchise,
    required this.result,
    required this.ownDefenseTactic,
    super.key,
  });

  final Franchise franchise;
  final GameResult result;

  /// The Defensive Tactic actually applied to the GM's own side of this
  /// game -- every real call site already knows this (either the GM's own
  /// pick off `MatchPreviewScreen`'s tactic picker, or the implicit
  /// [DefensiveTactic.balanced] default a Dashboard-triggered advance
  /// never overrides), so it's threaded straight through rather than
  /// re-derived. 2026-08-20, `TODO.md` item 6/7 -- "the GM picks a tactic
  /// pre-game and it's applied for real, but nothing on GameResultScreen
  /// afterward says which one was used."
  final DefensiveTactic ownDefenseTactic;

  @override
  Widget build(BuildContext context) {
    final homeTeam = teamByAbbreviation(
      franchise,
      result.game.homeTeamAbbreviation,
    );
    final awayTeam = teamByAbbreviation(
      franchise,
      result.game.awayTeamAbbreviation,
    );
    final rosters = rostersByAbbreviation(franchise);
    final homeRoster = rosters[result.game.homeTeamAbbreviation] ?? const [];
    final awayRoster = rosters[result.game.awayTeamAbbreviation] ?? const [];

    // Same bench-order-vs-auto-sort convention `MatchPreviewScreen`'s own
    // Offensive Shape section uses, and the exact same real inputs
    // `_simulateOneGame` just used to actually simulate this game --
    // nothing has changed since (this screen only ever shows immediately
    // after simulation), so recomputing here reproduces exactly what was
    // used rather than needing a new persisted field on `MatchResult`.
    final ownAbbreviation = franchise.team.abbreviation;
    final homeShape = detectOffenseShape(
      startingFiveFor(
        homeRoster,
        isBenchOrdered: result.game.homeTeamAbbreviation == ownAbbreviation,
      ),
    );
    final awayShape = detectOffenseShape(
      startingFiveFor(
        awayRoster,
        isBenchOrdered: result.game.awayTeamAbbreviation == ownAbbreviation,
      ),
    );
    final boxScore = computeBoxScore(
      result.match,
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );
    final homeLines =
        boxScore.where((line) => homeRoster.contains(line.player)).toList()
          ..sort((a, b) => b.points.compareTo(a.points));
    final awayLines =
        boxScore.where((line) => awayRoster.contains(line.player)).toList()
          ..sort((a, b) => b.points.compareTo(a.points));

    // The GM's own team's box score always leads, home or away -- a
    // direct GM bug report ("it lists all the individuals' stats...
    // should list the player's team first, then the other team after")
    // against the old fixed home-then-away order. The score card above
    // is unaffected (its away-then-home order matches the real
    // scoreboard convention and wasn't part of the complaint).
    final ownIsHome =
        result.game.homeTeamAbbreviation == franchise.team.abbreviation;
    final firstSection = _BoxScoreSection(
      franchise: franchise,
      team: ownIsHome ? homeTeam : awayTeam,
      lines: ownIsHome ? homeLines : awayLines,
    );
    final secondSection = _BoxScoreSection(
      franchise: franchise,
      team: ownIsHome ? awayTeam : homeTeam,
      lines: ownIsHome ? awayLines : homeLines,
    );

    // Any brand-new injury from *this specific game* -- matched by the
    // exact same (week, day) plus one of the 2 teams actually playing
    // here, since a real game day can hold several other league games'
    // worth of entries too (2026-08-20, a direct GM ask: "it absolutely
    // needs to be on the game result screen... big and bold" -- the
    // original `TODO.md` spec note this closes: an injury has to be
    // impossible to miss, not buried in a quiet 0-minutes box-score line).
    final gameInjuries = franchise.injuryReports
        .where(
          (entry) =>
              entry.week == result.game.week &&
              entry.day == result.game.day &&
              (entry.teamAbbreviation == result.game.homeTeamAbbreviation ||
                  entry.teamAbbreviation == result.game.awayTeamAbbreviation),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Game Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScoreCard(
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              homeOverall: teamOverallForPlayers(homeRoster),
              awayOverall: teamOverallForPlayers(awayRoster),
              result: result,
            ),
            if (gameInjuries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _InjuryAlertCard(entries: gameInjuries),
            ],
            const SizedBox(height: AppSpacing.md),
            _StrategyRecapCard(
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              homeShape: homeShape,
              awayShape: awayShape,
              ownDefenseTactic: ownDefenseTactic,
            ),
            const SizedBox(height: AppSpacing.md),
            // Right-aligned, between the box score and the individual
            // player stats (2026-08-10, a direct GM ask) -- this screen
            // is always pushed on top of the Dashboard (never popUntil),
            // so a plain pop lands right back there.
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Advance'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            firstSection,
            const SizedBox(height: AppSpacing.lg),
            secondSection,
          ],
        ),
      ),
    );
  }
}

/// One or more brand-new injuries from this exact game, right below the
/// score -- deliberately loud (a filled error-tone card, a medical emoji,
/// bold text) rather than folded quietly into the box score, per the
/// GM's own original spec (`TODO.md`'s Player Health item): "an injury
/// needs to show up *prominently* on the post-game report... something
/// the GM can't miss."
class _InjuryAlertCard extends StatelessWidget {
  const _InjuryAlertCard({required this.entries});

  final List<InjuryReportEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚑', style: TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                entries.length == 1 ? 'Injury Report' : 'Injury Reports',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${entry.name} (${entry.teamAbbreviation}) -- '
                '${entry.severity.label} injury, out '
                '${entry.severity.baseDurationGames} games',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Both teams' detected Offensive Shape plus the GM's own Defensive
/// Tactic pick, right below the score -- the "did that actually work?"
/// feedback loop `TODO.md` item 7 called out as missing (only the GM's
/// own tactic is shown, not the opponent's -- AI always defends
/// [DefensiveTactic.balanced], and calling that out by name for every
/// single game would just be noise).
class _StrategyRecapCard extends StatelessWidget {
  const _StrategyRecapCard({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeShape,
    required this.awayShape,
    required this.ownDefenseTactic,
  });

  final Team homeTeam;
  final Team awayTeam;
  final OffenseShape homeShape;
  final OffenseShape awayShape;
  final DefensiveTactic ownDefenseTactic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Offensive Shape', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ShapeColumn(team: awayTeam, shape: awayShape),
              ),
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _ShapeColumn(team: homeTeam, shape: homeShape),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          Text(
            'Your Defensive Tactic: ${ownDefenseTactic.label}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ShapeColumn extends StatelessWidget {
  const _ShapeColumn({required this.team, required this.shape});

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
        Text(shape.label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeOverall,
    required this.awayOverall,
    required this.result,
  });

  final Team homeTeam;
  final Team awayTeam;
  final int homeOverall;
  final int awayOverall;
  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = result.match;
    final periodCount = match.homeScoreByQuarter.length;
    final game = result.game;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FINAL',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!game.countsTowardStandings)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  // Just the plain type label, no "doesn't count toward
                  // your record" qualifier -- a preseason game already
                  // got this simplification (2026-08-07, "people know
                  // what that means"); a direct GM ask (2026-08-10)
                  // extended it to Cup/postseason games too: "if it's
                  // declared a Cup game, they'll figure it out."
                  child: Text(
                    game.typeLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TeamScoreRow(
            team: awayTeam,
            overall: awayOverall,
            score: match.awayScore,
            won: match.awayScore > match.homeScore,
          ),
          const SizedBox(height: AppSpacing.xs),
          _TeamScoreRow(
            team: homeTeam,
            overall: homeOverall,
            score: match.homeScore,
            won: match.homeScore > match.awayScore,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox.shrink()),
              for (var i = 0; i < periodCount; i++)
                Expanded(
                  child: Text(
                    _periodLabel(i),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          _QuarterScoreRow(
            label: awayTeam.abbreviation,
            scores: match.awayScoreByQuarter,
          ),
          _QuarterScoreRow(
            label: homeTeam.abbreviation,
            scores: match.homeScoreByQuarter,
          ),
        ],
      ),
    );
  }

  static String _periodLabel(int index) =>
      index < 4 ? 'Q${index + 1}' : 'OT${index - 3}';
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.team,
    required this.overall,
    required this.score,
    required this.won,
  });

  final Team team;
  final int overall;
  final int score;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(team.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            team.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: won ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '$overall OVR',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$score',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: won ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _QuarterScoreRow extends StatelessWidget {
  const _QuarterScoreRow({required this.label, required this.scores});

  final String label;
  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        for (final score in scores)
          Expanded(
            child: Text(
              '$score',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _BoxScoreSection extends StatelessWidget {
  const _BoxScoreSection({
    required this.franchise,
    required this.team,
    required this.lines,
  });

  final Franchise franchise;
  final Team team;
  final List<PlayerBoxScore> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(team.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.xs),
            Text(team.name, style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                _BoxScoreRow(
                  franchise: franchise,
                  jersey: parseHexColor(team.colors.primaryHex),
                  line: lines[i],
                ),
                if (i != lines.length - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BoxScoreRow extends StatelessWidget {
  const _BoxScoreRow({
    required this.franchise,
    required this.jersey,
    required this.line,
  });

  final Franchise franchise;
  final RgbColor jersey;
  final PlayerBoxScore line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = line.player;
    final jerseyNumber = player.jerseyNumber != null
        ? '#${player.jerseyNumber}'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortraitImage(
          saveId: franchise.id,
          ownerId: player.id,
          appearance: player.appearance,
          jersey: jersey,
          size: 40,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${player.primaryPosition.abbreviation} $jerseyNumber '
                '${player.name}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${line.points} PTS - ${line.assists} AST - '
                '${line.totalRebounds} REB',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${line.blocks} BLK - ${line.steals} STL - '
                '${line.turnovers} TO',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'FG ${line.fieldGoalsMade}/${line.fieldGoalAttempts} · '
                '3PT ${line.threePointersMade}/${line.threePointAttempts} · '
                'FT ${line.freeThrowsMade}/${line.freeThrowAttempts} · '
                '${line.minutesPlayed.round()} MIN',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
