import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../../player/presentation/player_detail_screen.dart';
import '../application/franchise_rosters.dart';
import '../domain/skills_competition.dart';

/// The Skills Competition's full result, shown right after it resolves --
/// all 3 events, standings and all (2026-08-10, TODO.md item 6, a direct
/// GM ask: "both of those events need post-game reports"). Reachable
/// again later via the Mail tab, same as a `TrainingReportScreen`.
class SkillsCompetitionResultScreen extends StatelessWidget {
  const SkillsCompetitionResultScreen({
    required this.franchise,
    required this.result,
    super.key,
  });

  final Franchise franchise;
  final SkillsCompetitionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playersById = {
      for (final roster in rostersByAbbreviation(franchise).values)
        for (final player in roster) player.id: player,
    };
    final teamAbbreviations = teamAbbreviationByPlayerId(franchise);
    final ownIds = {for (final m in franchise.roster) m.player.id};
    final ownEventWins = [
      for (final event in result.events)
        if (ownIds.contains(event.winnerPlayerId)) event,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Skills Competition')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (ownEventWins.isNotEmpty) ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        ownEventWins.length == 1
                            ? 'Your player won the '
                                  '${ownEventWins.first.event.label}!'
                            : 'Your players won '
                                  '${ownEventWins.length} events!',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (var i = 0; i < result.events.length; i++) ...[
              _EventCard(
                franchise: franchise,
                result: result.events[i],
                playersById: playersById,
                teamAbbreviations: teamAbbreviations,
                ownIds: ownIds,
              ),
              if (i != result.events.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.franchise,
    required this.result,
    required this.playersById,
    required this.teamAbbreviations,
    required this.ownIds,
  });

  final Franchise franchise;
  final SkillsEventResult result;
  final Map<String, Player> playersById;
  final Map<String, String> teamAbbreviations;
  final Set<String> ownIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.event.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < result.standings.length; i++) ...[
            _StandingRow(
              franchise: franchise,
              rank: i + 1,
              standing: result.standings[i],
              player: playersById[result.standings[i].playerId],
              teamAbbreviation: teamAbbreviations[result.standings[i].playerId],
              isOwn: ownIds.contains(result.standings[i].playerId),
            ),
            if (i != result.standings.length - 1)
              const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.franchise,
    required this.rank,
    required this.standing,
    required this.player,
    required this.teamAbbreviation,
    required this.isOwn,
  });

  final Franchise franchise;
  final int rank;
  final SkillsEventStanding standing;
  final Player? player;

  /// The 3-letter team this player actually plays for -- shown after
  /// their name (2026-08-11, a direct GM ask) since All-Star honorees mix
  /// players from every team in the conference, and the name alone
  /// doesn't say who they normally play for.
  final String? teamAbbreviation;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "Former Player" shouldn't happen (every standing entry comes from
    // this event's own honoree pool, all still on their roster at the
    // moment this resolved) but a label beats a crash, same posture every
    // other id-lookup fallback in this codebase already takes.
    final player = this.player;
    final name = player?.name ?? 'Former Player';
    final label = teamAbbreviation == null ? name : '$name ($teamAbbreviation)';
    final row = Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            rank == 1 ? '🥇' : '#$rank',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isOwn ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isOwn) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
        Text(
          standing.score.toStringAsFixed(1),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    // No id worth navigating to for the "Former Player" fallback case --
    // left untappable rather than opening a "Player Not Found" screen
    // (same posture the Stats screen's own player rows already take).
    if (player == null) return row;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlayerDetailScreen(franchise: franchise, playerId: player.id),
        ),
      ),
      child: row,
    );
  }
}
