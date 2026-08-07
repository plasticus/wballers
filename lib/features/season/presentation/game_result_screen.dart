import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../match/domain/player_box_score.dart';
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
    super.key,
  });

  final Franchise franchise;
  final GameResult result;

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
            const SizedBox(height: AppSpacing.lg),
            firstSection,
            const SizedBox(height: AppSpacing.lg),
            secondSection,
          ],
        ),
      ),
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
                  child: Text(
                    game.type == GameType.preseason
                        ? game.typeLabel
                        : '${game.typeLabel} -- doesn\'t count toward your '
                              'record',
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
