import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../league/domain/team.dart';
import '../../player/domain/archetype.dart';
import '../../player/domain/player.dart';
import '../../portrait/presentation/portrait_editor_screen.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/domain/star_tier.dart';
import '../application/current_franchise_provider.dart';
import '../domain/franchise.dart';
import '../onboarding/onboarding_screen.dart';
import 'lineup_editor_screen.dart';

/// "Inspect a complete roster" -- the Team tab. Read-only aside from the
/// starting-lineup entry point; player comparison, search/filtering, and
/// the player detail screen are separate, later work.
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
                builder: (_) => LineupEditorScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Starting Lineup'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RosterSection(
          franchise: franchise,
          title: 'Active Roster (${active.length})',
          members: active,
          starterIds: franchise.startingLineup.startersByPosition.values
              .toSet(),
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
    final tier = StarTier.of(player);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PortraitEditorScreen(franchise: franchise, playerId: player.id),
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
            Text(
              _positionAbbreviation(player.primaryPosition),
              style: theme.textTheme.labelLarge,
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
                          player.name,
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
                    '${_starTierLabel(tier)}',
                    style: theme.textTheme.bodySmall,
                  ),
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

String _positionAbbreviation(Position position) {
  return switch (position) {
    Position.pointGuard => 'PG',
    Position.shootingGuard => 'SG',
    Position.smallForward => 'SF',
    Position.powerForward => 'PF',
    Position.center => 'C',
  };
}

String _starTierLabel(StarTier tier) {
  return switch (tier) {
    StarTier.fiveStar => '5★',
    StarTier.fourStar => '4★',
    StarTier.belowFourStar => '3★ & below',
  };
}
