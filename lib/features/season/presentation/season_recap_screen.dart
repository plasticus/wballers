import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../application/franchise_rosters.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import '../generation/postseason_generator.dart' show seasonChampion;

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
                ],
              ),
            ),
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
                    'Results and News tabs.',
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
