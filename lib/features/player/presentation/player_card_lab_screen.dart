import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import 'trait_chip.dart';

/// A dev-facing comparison screen: the GM's first roster player, rendered
/// via 4 differently-structured player-card layouts side by side, so the
/// GM can pick a direction before any of them replace the current roster
/// row -- built in direct response to "I don't like the current player
/// card, but I want options before I say what to fix." Not linked from
/// anywhere a normal playthrough would stumble into by accident, but not
/// hidden either -- reachable via the Team tab's "Card Lab" button.
class PlayerCardLabScreen extends StatelessWidget {
  const PlayerCardLabScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membership = franchise.roster.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Player Card Lab')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Same player, 4 different card layouts -- '
              '${membership.player.name}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _LabSection(
              label: '1. Compact Row (current roster-row style)',
              child: _CompactRowCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '2. Trading Card',
              child: _TradingCard(franchise: franchise, membership: membership),
            ),
            _LabSection(
              label: '3. Ticket Stat Strip',
              child: _TicketStatStripCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '4. Scoreboard Tile',
              child: _ScoreboardTileCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabSection extends StatelessWidget {
  const _LabSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

String _positionAbbreviation(Position position) {
  return switch (position) {
    Position.pointGuard => 'PG',
    Position.shootingGuard => 'SG',
    Position.smallForward => 'SF',
    Position.powerForward => 'PF',
    Position.center => 'C',
  };
}

/// 1. The existing roster-row shape (`team_roster_screen.dart`'s
/// `_PlayerRow`, reproduced here rather than shared -- this screen is a
/// throwaway comparison tool, not a place to route production code
/// through): portrait, position badge, name/archetype/age/height,
/// OFF/DEF/PHY summary, traits, OVR at the far end. Everything in one
/// dense horizontal line.
class _CompactRowCard extends StatelessWidget {
  const _CompactRowCard({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortraitImage(
            saveId: franchise.id,
            ownerId: player.id,
            appearance: player.appearance,
            jersey: parseHexColor(franchise.team.colors.primaryHex),
            size: 40,
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _positionAbbreviation(player.primaryPosition),
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: theme.textTheme.bodyLarge),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${formatHeightInches(player.heightInches)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'OFF ${player.ratings.offenseOverall} · '
                  'DEF ${player.ratings.defenseOverall} · '
                  'PHY ${player.ratings.physicalOverall}',
                  style: theme.textTheme.bodySmall,
                ),
                if (player.traits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final trait in player.traits)
                        TraitChip(trait: trait),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.ratings.overall}',
                style: theme.textTheme.titleMedium,
              ),
              Text('OVR', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Portrait-forward, vertical, sports-trading-card shaped: a big
/// centered portrait with the overall rating badged over its corner,
/// name/archetype/position centered underneath, then a 3-column
/// Physical/Offense/Defense stat block below a divider.
class _TradingCard extends StatelessWidget {
  const _TradingCard({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;
    final accentJersey = parseHexColor(franchise.team.colors.primaryHex);
    final accentColor = franchise.team.colors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              PortraitImage(
                saveId: franchise.id,
                ownerId: player.id,
                appearance: player.appearance,
                jersey: accentJersey,
                size: 100,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Text(
                  '${player.ratings.overall}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            player.name,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            '${_positionAbbreviation(player.primaryPosition)} · '
            '${player.archetype.label}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatColumn(label: 'PHY', value: player.ratings.physicalOverall),
              _StatColumn(label: 'OFF', value: player.ratings.offenseOverall),
              _StatColumn(label: 'DEF', value: player.ratings.defenseOverall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('$value', style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// 3. Overall rating as the dominant visual element -- a big numeral in
/// its own colored panel on the left, identity in the middle, and the
/// three category ratings as a compact labeled-bar stack on the right.
/// Reads left-to-right like a sports-ticket stub: "how good, who, how
/// they're good."
class _TicketStatStripCard extends StatelessWidget {
  const _TicketStatStripCard({
    required this.franchise,
    required this.membership,
  });

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;
    final accentColor = franchise.team.colors.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72,
              color: accentColor,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${player.ratings.overall}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'OVR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(player.name, style: theme.textTheme.titleSmall),
                          Text(
                            '${_positionAbbreviation(player.primaryPosition)} '
                            '· Age ${player.age}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            player.archetype.label,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _RatingBar(
                            label: 'PHY',
                            value: player.ratings.physicalOverall,
                            color: accentColor,
                          ),
                          _RatingBar(
                            label: 'OFF',
                            value: player.ratings.offenseOverall,
                            color: accentColor,
                          ),
                          _RatingBar(
                            label: 'DEF',
                            value: player.ratings.defenseOverall,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 99,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 20,
            child: Text(
              '$value',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. A near-square scoreboard tile: position badge and jersey number
/// pinned to opposite top corners, portrait centered, name below, and a
/// bottom row of the three category ratings as plain numbers -- the
/// "trading card sticker" shape, denser and more grid-like than card #2.
class _ScoreboardTileCard extends StatelessWidget {
  const _ScoreboardTileCard({
    required this.franchise,
    required this.membership,
  });

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return Center(
      child: SizedBox(
        width: 220,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _positionAbbreviation(player.primaryPosition),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  if (player.jerseyNumber != null)
                    Text(
                      '#${player.jerseyNumber}',
                      style: theme.textTheme.labelMedium,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              PortraitImage(
                saveId: franchise.id,
                ownerId: player.id,
                appearance: player.appearance,
                jersey: parseHexColor(franchise.team.colors.primaryHex),
                size: 72,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                player.name,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${player.ratings.overall} OVR',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(
                    label: 'PHY',
                    value: player.ratings.physicalOverall,
                  ),
                  _StatColumn(
                    label: 'OFF',
                    value: player.ratings.offenseOverall,
                  ),
                  _StatColumn(
                    label: 'DEF',
                    value: player.ratings.defenseOverall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
