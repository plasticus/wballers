import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../roster/domain/team_overall.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_result.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import 'game_result_screen.dart';

/// Shown before the GM's own scheduled game actually simulates -- a direct
/// GM ask ("there should be some kind of splash before my games, not just
/// straight to the result"). Both teams, their current record and team
/// overall, and a single "Play Game" button, which is the one thing that
/// actually does anything here: it runs the same `advanceGameDay` the
/// Dashboard's "Advance to Next Game Day" button already calls (this
/// screen only ever gets pushed in place of that direct call, on a day
/// `nextOwnGame` says the GM's own team is playing), then hands off to
/// `GameResultScreen`. Every other team's game that game day is still
/// simulated the same instant, background-sim way it always was --
/// this only changes what the GM sees for their own.
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
    final theme = Theme.of(context);
    final franchise = widget.franchise;
    final game = widget.game;

    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);
    final rosters = rostersByAbbreviation(franchise);
    final homeOverall = teamOverallForPlayers(
      rosters[game.homeTeamAbbreviation] ?? const [],
    );
    final awayOverall = teamOverallForPlayers(
      rosters[game.awayTeamAbbreviation] ?? const [],
    );
    final standings = currentStandings(
      franchise.seasonProgress,
      allLeagueTeams(franchise),
    );
    final homeRecord = recordFor(game.homeTeamAbbreviation, standings);
    final awayRecord = recordFor(game.awayTeamAbbreviation, standings);

    return Scaffold(
      appBar: AppBar(title: const Text('Next Game')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                game.typeLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: game.countsTowardStandings
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                  fontWeight: game.countsTowardStandings
                      ? null
                      : FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    _MatchupTeamRow(
                      team: awayTeam,
                      overall: awayOverall,
                      record: awayRecord,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        '@',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    _MatchupTeamRow(
                      team: homeTeam,
                      overall: homeOverall,
                      record: homeRecord,
                    ),
                  ],
                ),
              ),
              const Spacer(),
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

class _MatchupTeamRow extends StatelessWidget {
  const _MatchupTeamRow({
    required this.team,
    required this.overall,
    required this.record,
  });

  final Team team;
  final int overall;
  final StandingsEntry record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(team.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(team.name, style: theme.textTheme.titleMedium),
              Text(
                '${team.location} · $overall OVR',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          '${record.wins}-${record.losses}',
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
