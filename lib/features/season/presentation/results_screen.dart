import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/played_game.dart';
import '../domain/played_game_stat_line.dart';
import '../domain/scheduled_game.dart';
import '../generation/season_schedule_generator.dart' show weekLabel;

/// Every game played so far this season, across the whole league --
/// newest first -- closing out `0B_Planned.md`'s Results-page spec.
/// Unlike the transient `GameResultScreen` (shown once, right when a game
/// is simulated), this reads straight from `Franchise.seasonProgress.playedGames`,
/// so it survives the moment a game was actually played. Box scores here
/// come from `PlayedGame.boxScoreByPlayerId`, computed once at play time
/// and persisted -- not re-simulated on open, which wouldn't reliably
/// reproduce the original result once `features/training/` has mutated
/// roster ratings since (see `PlayedGame.boxScoreByPlayerId`'s doc
/// comment). No quarter-by-quarter breakdown here -- that's not part of
/// what a `PlayedGame` persists, unlike the live `GameResultScreen`.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final games = franchise.seasonProgress.playedGames.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SafeArea(
        child: games.isEmpty
            ? const EmptyStateView(
                icon: Icons.scoreboard_outlined,
                message: 'No games played yet.',
              )
            // .builder, not a plain ListView -- a full season can run to
            // ~300+ games leaguewide, unlike every other list in this app.
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: games.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ResultRow(franchise: franchise, played: games[index]),
                ),
              ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.franchise, required this.played});

  final Franchise franchise;
  final PlayedGame played;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = played.game;
    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);
    final homeWon = played.homeScore > played.awayScore;

    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PlayedGameDetailScreen(franchise: franchise, played: played),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (game.type) {
                GameType.preseason =>
                  '${weekLabel(game.week)} · ${game.day.label} · Preseason',
                // Same unmissable treatment Schedule already gives Cup
                // games -- a direct GM ask (2026-08-15): games results
                // weren't noted as Cup games at all here, so a bye-day
                // "why is the league still simulating" question had
                // nowhere on this screen to answer itself either.
                GameType.continentalCup =>
                  '${weekLabel(game.week)} · ${game.day.label} · '
                      '🏆 WBL Continental Cup',
                _ => '${weekLabel(game.week)} · ${game.day.label}',
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    game.type == GameType.preseason ||
                        game.type == GameType.continentalCup
                    ? theme.colorScheme.primary
                    : null,
                fontWeight:
                    game.type == GameType.preseason ||
                        game.type == GameType.continentalCup
                    ? FontWeight.bold
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${awayTeam.emoji} ${awayTeam.name}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: homeWon ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                Text('${played.awayScore}', style: theme.textTheme.titleMedium),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${homeTeam.emoji} ${homeTeam.name}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: homeWon ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Text('${played.homeScore}', style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One past game's full box score, reconstructed from
/// `PlayedGame.boxScoreByPlayerId` rather than re-simulated -- see
/// `ResultsScreen`'s doc comment for why. Public (not the usual private
/// `_`-prefixed pushed screen) so other screens that already have a
/// `PlayedGame` in hand (`ScheduleScreen`) can link straight to it.
class PlayedGameDetailScreen extends StatelessWidget {
  const PlayedGameDetailScreen({
    required this.franchise,
    required this.played,
    super.key,
  });

  final Franchise franchise;
  final PlayedGame played;

  @override
  Widget build(BuildContext context) {
    final game = played.game;
    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);
    final rosters = rostersByAbbreviation(franchise);
    final homeIds = {
      for (final player
          in rosters[game.homeTeamAbbreviation] ?? const <Player>[])
        player.id,
    };
    // Keyed by id rather than carried on PlayedGameStatLine itself -- the
    // lean persisted box score is stats only (`played_game_stat_line.dart`),
    // so anything about the player as a person (name, jersey, portrait)
    // comes from the *current* roster. Fine here since nothing can move a
    // player to a different team yet (no trades) -- if that ever changes,
    // this join stops being reliably correct for an old game.
    final playerById = <String, Player>{
      for (final player in [
        ...rosters[game.homeTeamAbbreviation] ?? const <Player>[],
        ...rosters[game.awayTeamAbbreviation] ?? const <Player>[],
      ])
        player.id: player,
    };

    final homeLines = <MapEntry<String, PlayedGameStatLine>>[];
    final awayLines = <MapEntry<String, PlayedGameStatLine>>[];
    for (final entry in played.boxScoreByPlayerId.entries) {
      (homeIds.contains(entry.key) ? homeLines : awayLines).add(entry);
    }
    homeLines.sort((a, b) => b.value.points.compareTo(a.value.points));
    awayLines.sort((a, b) => b.value.points.compareTo(a.value.points));

    // The GM's own team's box score always leads, home or away -- a
    // direct GM bug report against the old fixed away-then-home order
    // ("it lists all the individuals' stats... should list the player's
    // team first, then the other team after"). A game the GM's own team
    // isn't even part of (any other league game, browsed from the
    // Results screen) falls back to the original away-then-home order --
    // there's no "own team" to prioritize.
    final ownIsHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
    final firstSection = _BoxScoreSection(
      franchise: franchise,
      team: ownIsHome ? homeTeam : awayTeam,
      lines: ownIsHome ? homeLines : awayLines,
      playerById: playerById,
    );
    final secondSection = _BoxScoreSection(
      franchise: franchise,
      team: ownIsHome ? awayTeam : homeTeam,
      lines: ownIsHome ? awayLines : homeLines,
      playerById: playerById,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScoreCard(
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              homeScore: played.homeScore,
              awayScore: played.awayScore,
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
    required this.homeScore,
    required this.awayScore,
  });

  final Team homeTeam;
  final Team awayTeam;
  final int homeScore;
  final int awayScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            score: awayScore,
            won: awayScore > homeScore,
          ),
          const SizedBox(height: AppSpacing.xs),
          _TeamScoreRow(
            team: homeTeam,
            score: homeScore,
            won: homeScore > awayScore,
          ),
        ],
      ),
    );
  }
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
          '$score',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: won ? FontWeight.bold : FontWeight.normal,
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
    required this.playerById,
  });

  final Franchise franchise;
  final Team team;
  final List<MapEntry<String, PlayedGameStatLine>> lines;
  final Map<String, Player> playerById;

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
        if (lines.isEmpty)
          const AppCard(child: Text('No box score recorded for this game.'))
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  _BoxScoreRow(
                    franchise: franchise,
                    jersey: parseHexColor(team.colors.primaryHex),
                    player: playerById[lines[i].key],
                    line: lines[i].value,
                  ),
                  if (i != lines.length - 1)
                    const Divider(height: AppSpacing.lg),
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
    required this.player,
    required this.line,
  });

  final Franchise franchise;
  final RgbColor jersey;

  /// `null` if this player has since left the current roster (traded,
  /// waived) -- no trade system exists yet, but this stays graceful rather
  /// than throwing if that ever changes.
  final Player? player;
  final PlayedGameStatLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = this.player;
    final jerseyNumber = player?.jerseyNumber != null
        ? '#${player!.jerseyNumber} '
        : '';
    final position = player != null
        ? '${player.primaryPosition.abbreviation} '
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (player != null) ...[
          PortraitImage(
            saveId: franchise.id,
            ownerId: player.id,
            appearance: player.appearance,
            jersey: jersey,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$position$jerseyNumber${player?.name ?? 'Unknown Player'}',
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
