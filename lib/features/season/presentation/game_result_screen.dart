import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../match/domain/player_box_score.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_result.dart';

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
    final boxScore = computeBoxScore(
      result.match,
      homeRoster: rosters[result.game.homeTeamAbbreviation] ?? const [],
      awayRoster: rosters[result.game.awayTeamAbbreviation] ?? const [],
    );
    final homePlayers = rosters[result.game.homeTeamAbbreviation] ?? const [];
    final homeLines =
        boxScore.where((line) => homePlayers.contains(line.player)).toList()
          ..sort((a, b) => b.points.compareTo(a.points));
    final awayLines =
        boxScore.where((line) => !homePlayers.contains(line.player)).toList()
          ..sort((a, b) => b.points.compareTo(a.points));

    return Scaffold(
      appBar: AppBar(title: const Text('Game Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScoreCard(homeTeam: homeTeam, awayTeam: awayTeam, result: result),
            const SizedBox(height: AppSpacing.lg),
            _BoxScoreSection(team: homeTeam, lines: homeLines),
            const SizedBox(height: AppSpacing.lg),
            _BoxScoreSection(team: awayTeam, lines: awayLines),
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
    required this.result,
  });

  final Team homeTeam;
  final Team awayTeam;
  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = result.match;
    final periodCount = match.homeScoreByQuarter.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FINAL',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TeamScoreRow(
            team: awayTeam,
            score: match.awayScore,
            won: match.awayScore > match.homeScore,
          ),
          const SizedBox(height: AppSpacing.xs),
          _TeamScoreRow(
            team: homeTeam,
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
    required this.score,
    required this.won,
  });

  final Team team;
  final int score;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${team.location} ${team.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: won ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
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
  const _BoxScoreSection({required this.team, required this.lines});

  final Team team;
  final List<PlayerBoxScore> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${team.location} ${team.name}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                _BoxScoreRow(line: lines[i]),
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
  const _BoxScoreRow({required this.line});

  final PlayerBoxScore line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.player.name, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${line.minutesPlayed.round()} MIN · ${line.points} PTS · '
          '${line.totalRebounds} REB · ${line.assists} AST · '
          '${line.steals} STL · ${line.blocks} BLK · ${line.turnovers} TO',
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          'FG ${line.fieldGoalsMade}/${line.fieldGoalAttempts} · '
          '3PT ${line.threePointersMade}/${line.threePointAttempts} · '
          'FT ${line.freeThrowsMade}/${line.freeThrowAttempts}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
