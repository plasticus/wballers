import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/presentation/portrait_editor_screen.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../season/domain/played_game_stat_line.dart';
import '../../training/domain/player_rating_field.dart';
import '../domain/achievement.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import 'trait_chip.dart';

/// One player's full profile: ratings, traits, this season's stats, and
/// awards -- the screen `0B_Planned.md` pulled forward as an early Phase 2
/// prerequisite (spec, 2026-08-05), reachable from a roster row. Prior-
/// seasons history is spec'd too but has nothing to show yet -- there's no
/// multi-season concept on `Franchise` at all (no season/year field, no
/// "start next season" flow), so that section is an honest placeholder
/// rather than missing silently.
class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({
    required this.franchise,
    required this.playerId,
    super.key,
  });

  final Franchise franchise;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final membership = franchise.roster.firstWhere(
      (m) => m.player.id == playerId,
    );
    final player = membership.player;

    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeaderCard(franchise: franchise, player: player),
            const SizedBox(height: AppSpacing.lg),
            if (player.traits.isNotEmpty) ...[
              Text('Traits', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final trait in player.traits) TraitChip(trait: trait),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('Ratings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _RatingsCard(player: player),
            const SizedBox(height: AppSpacing.lg),
            Text('This Season', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _SeasonStatsCard(franchise: franchise, playerId: playerId),
            const SizedBox(height: AppSpacing.lg),
            Text('Awards', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _AwardsCard(player: player),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Season History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppCard(
              child: Text(
                'Season-by-season history will appear here once a season '
                'can actually be completed and a new one started.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PortraitEditorScreen(
                    franchise: franchise,
                    playerId: player.id,
                  ),
                ),
              );
            },
            child: PortraitImage(
              saveId: franchise.id,
              ownerId: player.id,
              appearance: player.appearance,
              jersey: parseHexColor(franchise.team.colors.primaryHex),
              size: 64,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (player.jerseyNumber != null) '#${player.jerseyNumber}',
                    player.nickname == null
                        ? player.name
                        : '${player.name} "${player.nickname}"',
                  ].join(' '),
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '${player.archetype.label} · '
                  '${player.primaryPosition.name}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Age ${player.age} · ${formatHeightInches(player.heightInches)} '
                  '· ${player.hometown}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.ratings.overall}',
                style: theme.textTheme.titleLarge,
              ),
              Text('OVR', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingsCard extends StatelessWidget {
  const _RatingsCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RatingGroup(
            label: 'Physical',
            overall: player.ratings.physicalOverall,
            fields: kPhysicalFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          _RatingGroup(
            label: 'Offense',
            overall: player.ratings.offenseOverall,
            fields: kOffenseFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          _RatingGroup(
            label: 'Defense',
            overall: player.ratings.defenseOverall,
            fields: kDefenseFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Potential',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                '${player.ratings.potential}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingGroup extends StatelessWidget {
  const _RatingGroup({
    required this.label,
    required this.overall,
    required this.fields,
    required this.ratings,
  });

  final String label;
  final int overall;
  final Set<PlayerRatingField> fields;
  final PlayerRatings ratings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text('$overall', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(field.label, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${ratings.valueOf(field)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeasonStatsCard extends StatelessWidget {
  const _SeasonStatsCard({required this.franchise, required this.playerId});

  final Franchise franchise;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      for (final played in franchise.seasonProgress.playedGames)
        ?played.boxScoreByPlayerId[playerId],
    ];

    if (lines.isEmpty) {
      return const AppCard(child: Text('No games played yet this season.'));
    }

    final gamesPlayed = lines.length;
    double total(int Function(PlayedGameStatLine) selector) =>
        lines.fold(0, (sum, line) => sum + selector(line));
    double perGame(int Function(PlayedGameStatLine) selector) =>
        total(selector) / gamesPlayed;

    final fgMade = total((l) => l.fieldGoalsMade);
    final fgAttempts = total((l) => l.fieldGoalAttempts);
    final threeMade = total((l) => l.threePointersMade);
    final threeAttempts = total((l) => l.threePointAttempts);
    final ftMade = total((l) => l.freeThrowsMade);
    final ftAttempts = total((l) => l.freeThrowAttempts);

    String pct(double made, double attempts) =>
        attempts == 0 ? '--' : '${(made / attempts * 100).round()}%';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$gamesPlayed games played', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${perGame((l) => l.points).toStringAsFixed(1)} PPG · '
            '${perGame((l) => l.totalRebounds).toStringAsFixed(1)} RPG · '
            '${perGame((l) => l.assists).toStringAsFixed(1)} APG · '
            '${perGame((l) => l.steals).toStringAsFixed(1)} SPG · '
            '${perGame((l) => l.blocks).toStringAsFixed(1)} BPG',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'FG ${pct(fgMade, fgAttempts)} · '
            '3PT ${pct(threeMade, threeAttempts)} · '
            'FT ${pct(ftMade, ftAttempts)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AwardsCard extends StatelessWidget {
  const _AwardsCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    if (player.achievements.isEmpty) {
      return const AppCard(child: Text('No awards earned yet.'));
    }
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < player.achievements.length; i++) ...[
            Text(
              '${player.achievements[i].achievement.label} '
              '(Season ${player.achievements[i].season})',
              style: theme.textTheme.bodyLarge,
            ),
            if (i != player.achievements.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
