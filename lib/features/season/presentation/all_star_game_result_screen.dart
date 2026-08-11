import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../application/franchise_rosters.dart';
import '../domain/played_game.dart';
import '../domain/played_game_stat_line.dart';
import '../generation/all_star_advancer.dart';

/// The All-Star Game's final box score, shown right after it resolves --
/// same "post-game report" ask as the Skills Competition
/// (2026-08-10, TODO.md item 5). Built entirely off [playedGame] and
/// [squads] (both already persisted -- `Franchise.seasonProgress.playedGames`
/// and `SkillsCompetitionResult.squads`) rather than the transient
/// `GameResult`/`MatchResult` a normal game's result screen uses, so this
/// screen looks identical whether it's reached fresh, right after
/// advancing, or later from the Mail tab.
class AllStarGameResultScreen extends StatelessWidget {
  const AllStarGameResultScreen({
    required this.franchise,
    required this.playedGame,
    required this.squads,
    super.key,
  });

  final Franchise franchise;
  final PlayedGame playedGame;
  final Map<Conference, List<String>> squads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playersById = {
      for (final roster in rostersByAbbreviation(franchise).values)
        for (final player in roster) player.id: player,
    };
    final ownIds = {for (final m in franchise.roster) m.player.id};
    final honoreeIds = {
      ...squads[Conference.atlantic]!,
      ...squads[Conference.pacific]!,
    };
    final mvpId = allStarGameMvp(playedGame, honoreeIds: honoreeIds);

    List<MapEntry<String, PlayedGameStatLine>> linesFor(Conference conference) {
      final ids = squads[conference]!.toSet();
      return playedGame.boxScoreByPlayerId.entries
          .where((entry) => ids.contains(entry.key))
          .toList()
        ..sort((a, b) => b.value.points.compareTo(a.value.points));
    }

    final atlanticLines = linesFor(Conference.atlantic);
    final pacificLines = linesFor(Conference.pacific);
    // The GM's own squad (if they have honorees at all) leads, same
    // "your team first" convention `GameResultScreen` already
    // established -- falls back to Atlantic-then-Pacific if the GM has
    // no All-Star this year.
    final ownIsAtlantic = atlanticLines.any((e) => ownIds.contains(e.key));
    final firstConference = ownIsAtlantic || pacificLines.isEmpty
        ? Conference.atlantic
        : Conference.pacific;
    final secondConference = firstConference == Conference.atlantic
        ? Conference.pacific
        : Conference.atlantic;
    final linesByConference = {
      Conference.atlantic: atlanticLines,
      Conference.pacific: pacificLines,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('All-Star Game')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScoreCard(playedGame: playedGame),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${playersById[mvpId]?.name ?? 'Former Player'} is the '
                      'All-Star Game MVP'
                      '${ownIds.contains(mvpId) ? ' -- your player!' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SquadSection(
              franchise: franchise,
              title:
                  '${firstConference.label.replaceFirst(' Conference', '')} '
                  'All-Stars',
              lines: linesByConference[firstConference]!,
              playersById: playersById,
              ownIds: ownIds,
              mvpId: mvpId,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SquadSection(
              franchise: franchise,
              title:
                  '${secondConference.label.replaceFirst(' Conference', '')} '
                  'All-Stars',
              lines: linesByConference[secondConference]!,
              playersById: playersById,
              ownIds: ownIds,
              mvpId: mvpId,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.playedGame});

  final PlayedGame playedGame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atlanticWon = playedGame.homeScore > playedGame.awayScore;
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
            label: 'Pacific All-Stars',
            score: playedGame.awayScore,
            won: !atlanticWon,
          ),
          const SizedBox(height: AppSpacing.xs),
          _TeamScoreRow(
            label: 'Atlantic All-Stars',
            score: playedGame.homeScore,
            won: atlanticWon,
          ),
        ],
      ),
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.label,
    required this.score,
    required this.won,
  });

  final String label;
  final int score;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
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

class _SquadSection extends StatelessWidget {
  const _SquadSection({
    required this.franchise,
    required this.title,
    required this.lines,
    required this.playersById,
    required this.ownIds,
    required this.mvpId,
  });

  final Franchise franchise;
  final String title;
  final List<MapEntry<String, PlayedGameStatLine>> lines;
  final Map<String, Player> playersById;
  final Set<String> ownIds;
  final String mvpId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                _BoxScoreRow(
                  franchise: franchise,
                  playerId: lines[i].key,
                  player: playersById[lines[i].key],
                  line: lines[i].value,
                  isOwn: ownIds.contains(lines[i].key),
                  isMvp: lines[i].key == mvpId,
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
    required this.playerId,
    required this.player,
    required this.line,
    required this.isOwn,
    required this.isMvp,
  });

  final Franchise franchise;
  final String playerId;
  final Player? player;
  final PlayedGameStatLine line;
  final bool isOwn;
  final bool isMvp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Shouldn't happen -- every box score entry comes from a player who
    // was on a squad at the moment the game resolved -- but a label beats
    // a crash, same fallback every other id-lookup in this codebase uses.
    final name = player?.name ?? 'Former Player';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortraitImage(
          saveId: franchise.id,
          ownerId: playerId,
          appearance: player?.appearance,
          size: 40,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isOwn ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isMvp) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ],
                  if (isOwn) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.star,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${line.points} PTS - ${line.assists} AST - '
                '${line.totalRebounds} REB',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${line.blocks} BLK - ${line.steals} STL - '
                '${line.minutesPlayed.round()} MIN',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
