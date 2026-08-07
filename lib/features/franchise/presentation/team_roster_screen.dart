import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../league/domain/team.dart';
import '../../player/domain/archetype.dart';
import '../../player/domain/player.dart';
import '../../player/presentation/player_card_lab_screen.dart';
import '../../player/presentation/player_detail_screen.dart';
import '../../player/presentation/trait_chip.dart';
import '../../portrait/presentation/portrait_editor_screen.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../training/presentation/training_screen.dart';
import '../application/current_franchise_provider.dart';
import '../domain/franchise.dart';
import '../onboarding/onboarding_screen.dart';
import 'depth_chart_screen.dart';

/// "Inspect a complete roster" -- the Team tab. Read-only aside from the
/// Bench Order entry point; each row leads to `PlayerDetailScreen` for a
/// full profile. Player comparison and search/filtering are still
/// separate, later work.
class TeamRosterScreen extends ConsumerWidget {
  const TeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _RosterView(franchise: value),
      AsyncData() => const _NoFranchiseView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading your roster…'),
    };
  }
}

class _NoFranchiseView extends StatelessWidget {
  const _NoFranchiseView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.groups_outlined,
      message: 'Create an expansion franchise to see your roster.',
      action: FilledButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        },
        child: const Text('Create Expansion Franchise'),
      ),
    );
  }
}

int _byPositionThenOverall(RosterMembership a, RosterMembership b) {
  final positionCompare = Position.values
      .indexOf(a.player.primaryPosition)
      .compareTo(Position.values.indexOf(b.player.primaryPosition));
  if (positionCompare != 0) return positionCompare;
  return b.player.ratings.overall.compareTo(a.player.ratings.overall);
}

class _RosterView extends StatelessWidget {
  const _RosterView({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bench Order's own list position defines both target minutes and
    // starters now -- the top 5 in that real order are the starters, no
    // separate position-locked lineup to keep in sync with it. Captured
    // before the position-grouped sort below, which is purely a display
    // convenience and isn't the order that matters here.
    final startersInBenchOrder = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .take(5)
        .map((m) => m.player.id)
        .toSet();

    final active =
        franchise.roster.where((m) => m.status == RosterStatus.active).toList()
          ..sort(_byPositionThenOverall);
    final developmental =
        franchise.roster
            .where((m) => m.status == RosterStatus.developmental)
            .toList()
          ..sort(_byPositionThenOverall);
    final reserve =
        franchise.roster
            .where((m) => m.status == RosterStatus.reserveInactive)
            .toList()
          ..sort(_byPositionThenOverall);

    return ListView(
      children: [
        Text(franchise.team.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text('${franchise.team.location} · ${franchise.team.conference.label}'),
        const SizedBox(height: AppSpacing.md),
        _CoachRow(franchise: franchise),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DepthChartScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.format_list_numbered),
          label: const Text('Bench Order'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrainingScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.fitness_center_outlined),
          label: const Text('Training'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerCardLabScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.style_outlined),
          label: const Text('Card Lab'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RosterSection(
          franchise: franchise,
          title: 'Active Roster (${active.length})',
          members: active,
          starterIds: startersInBenchOrder,
        ),
        if (developmental.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _RosterSection(
            franchise: franchise,
            title: 'Developmental (${developmental.length})',
            members: developmental,
          ),
        ],
        if (reserve.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _RosterSection(
            franchise: franchise,
            title: 'Reserve / Inactive (${reserve.length})',
            members: reserve,
          ),
        ],
      ],
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coach = franchise.coach;

    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PortraitEditorScreen(franchise: franchise),
            ),
          );
        },
        child: Row(
          children: [
            PortraitImage(
              saveId: franchise.id,
              ownerId: 'coach',
              appearance: coach.appearance,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Head Coach', style: theme.textTheme.labelSmall),
                  Text(coach.name, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _RosterSection extends StatelessWidget {
  const _RosterSection({
    required this.franchise,
    required this.title,
    required this.members,
    this.starterIds = const {},
  });

  final Franchise franchise;
  final String title;
  final List<RosterMembership> members;
  final Set<String> starterIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < members.length; i++) ...[
                _PlayerRow(
                  franchise: franchise,
                  membership: members[i],
                  isStarter: starterIds.contains(members[i].player.id),
                ),
                if (i != members.length - 1)
                  const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.franchise,
    required this.membership,
    this.isStarter = false,
  });

  final Franchise franchise;
  final RosterMembership membership;
  final bool isStarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PlayerDetailScreen(franchise: franchise, playerId: player.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                color: _positionColor(
                  player.primaryPosition,
                ).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                player.primaryPosition.abbreviation,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _positionColor(player.primaryPosition),
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                          [
                            if (player.jerseyNumber != null)
                              '#${player.jerseyNumber}',
                            player.nickname == null
                                ? player.name
                                : '${player.name} "${player.nickname}"',
                          ].join(' '),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (isStarter) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: theme.colorScheme.primary,
                          semanticLabel: 'Starter',
                        ),
                      ],
                    ],
                  ),
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
      ),
    );
  }
}

/// A subtle per-position accent, purely decorative -- the position
/// abbreviation text next to it already conveys the position on its own,
/// so color isn't the only signal (accessibility rule in ARCHITECTURE.md).
Color _positionColor(Position position) {
  return switch (position) {
    Position.pointGuard => Colors.blue,
    Position.shootingGuard => Colors.teal,
    Position.smallForward => Colors.green,
    Position.powerForward => Colors.orange,
    Position.center => Colors.purple,
  };
}
