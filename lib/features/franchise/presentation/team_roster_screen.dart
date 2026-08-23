import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../coach/domain/coach_archetype.dart';
import '../../coach/presentation/coach_detail_screen.dart';
import '../../league/domain/team.dart';
import '../../market/presentation/player_market_screen.dart';
import '../../player/domain/archetype.dart';
import '../../player/domain/player.dart';
import '../../player/domain/player_injury.dart';
import '../../player/presentation/player_card_widgets.dart';
import '../../player/presentation/player_detail_screen.dart';
import '../../player/presentation/trait_chip.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/presentation/team_calendar_screen.dart';
import '../../training/presentation/training_screen.dart';
import '../application/current_franchise_provider.dart';
import '../domain/franchise.dart';
import '../domain/franchise_legality.dart';
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

/// How the Active Roster section can be sorted (2026-08-10, a direct GM
/// ask: "give me a little drop-down to change how it's ordered"). Purely
/// a display convenience -- unlike Bench Order (`DepthChartScreen`),
/// which really is the order that drives target minutes, this never
/// gets persisted; it resets to [position] every time the screen opens.
enum _RosterSortOption {
  position('Position', _byPositionThenOverall),
  overall('OVR', _byOverallThenPosition),
  experience('Exp', _byExperienceThenOverall),
  age('Age', _byAgeThenOverall),
  potential('Potential', _byPotentialThenOverall);

  const _RosterSortOption(this.label, this.comparator);

  final String label;
  final int Function(RosterMembership, RosterMembership) comparator;
}

int _byOverallThenPosition(RosterMembership a, RosterMembership b) {
  final overallCompare = b.player.ratings.overall.compareTo(
    a.player.ratings.overall,
  );
  if (overallCompare != 0) return overallCompare;
  return Position.values
      .indexOf(a.player.primaryPosition)
      .compareTo(Position.values.indexOf(b.player.primaryPosition));
}

int _byExperienceThenOverall(RosterMembership a, RosterMembership b) {
  final expCompare = b.player.yearsOfService.compareTo(a.player.yearsOfService);
  if (expCompare != 0) return expCompare;
  return b.player.ratings.overall.compareTo(a.player.ratings.overall);
}

// Youngest first -- scanning for development prospects is the more
// common reason to sort by age at all; OVR/Exp/Potential already cover
// "who's my best/most established player" the other way.
int _byAgeThenOverall(RosterMembership a, RosterMembership b) {
  final ageCompare = a.player.age.compareTo(b.player.age);
  if (ageCompare != 0) return ageCompare;
  return b.player.ratings.overall.compareTo(a.player.ratings.overall);
}

int _byPotentialThenOverall(RosterMembership a, RosterMembership b) {
  final potentialCompare = b.player.ratings.potential.compareTo(
    a.player.ratings.potential,
  );
  if (potentialCompare != 0) return potentialCompare;
  return b.player.ratings.overall.compareTo(a.player.ratings.overall);
}

class _RosterView extends StatefulWidget {
  const _RosterView({required this.franchise});

  final Franchise franchise;

  @override
  State<_RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<_RosterView> {
  var _activeSort = _RosterSortOption.position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise = widget.franchise;

    // Bench Order's own list position defines both target minutes and
    // starters now -- the top 5 in that real order are the starters, no
    // separate position-locked lineup to keep in sync with it. Captured
    // before the display sort below, which is purely a viewing
    // convenience and isn't the order that matters here.
    final startersInBenchOrder = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .take(5)
        .map((m) => m.player.id)
        .toSet();

    final active =
        franchise.roster.where((m) => m.status == RosterStatus.active).toList()
          ..sort(_activeSort.comparator);
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
        _RosterLegalityWarning(franchise: franchise),
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
                builder: (_) => PlayerMarketScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Player Market'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamCalendarScreen(franchise: franchise),
              ),
            );
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Calendar'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RosterSection(
          franchise: franchise,
          title: 'Active Roster (${active.length})',
          members: active,
          starterIds: startersInBenchOrder,
          trailing: _SortDropdown(
            value: _activeSort,
            onChanged: (option) => setState(() => _activeSort = option),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SlotSection(
          franchise: franchise,
          title: 'Development Slots',
          status: RosterStatus.developmental,
          slotCount: kMaxDevelopmentalRosterSpots,
          members: developmental,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SlotSection(
          franchise: franchise,
          title: 'Injured/Inactive Slots',
          status: RosterStatus.reserveInactive,
          slotCount: kMaxInactiveRosterSpots,
          members: reserve,
        ),
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final _RosterSortOption value;
  final ValueChanged<_RosterSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<_RosterSortOption>(
      value: value,
      underline: const SizedBox.shrink(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
      icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
      items: [
        for (final option in _RosterSortOption.values)
          DropdownMenuItem(value: option, child: Text('Sort: ${option.label}')),
      ],
      onChanged: (option) {
        if (option != null) onChanged(option);
      },
    );
  }
}

/// A warning card listing every current [RosterLegality] violation,
/// straight off [RosterLegality.violationMessages] -- empty (renders
/// nothing) when the roster is legal. 2026-08-20, a direct GM ask: "I
/// think we need to build in more notifications of roster legality...
/// haven't started the preseason yet, haven't seen anything about
/// legality." Same information [RosterLegalityMailItem] surfaces in Mail,
/// just visible right where the GM is already looking while managing the
/// roster, not only in the inbox.
class _RosterLegalityWarning extends StatelessWidget {
  const _RosterLegalityWarning({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final messages = evaluateFranchiseLegality(franchise).violationMessages;
    if (messages.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Roster Legality Issue',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $message', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
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
        // Leads to the full detail screen now, same "row leads to a
        // detail screen" pattern every player row already uses -- a
        // direct GM ask (2026-08-19): "Head coach needs a detail
        // screen." Portrait editing (this row's old sole destination)
        // moves to a tap on the portrait itself, inside that screen,
        // mirroring `PlayerDetailScreen`'s own header exactly.
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CoachDetailScreen(franchise: franchise),
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
                  Text(
                    '${coach.archetype.label} · Age ${coach.age}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
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
    this.trailing,
  });

  final Franchise franchise;
  final String title;
  final List<RosterMembership> members;
  final Set<String> starterIds;

  /// The sort dropdown, on the Active Roster section only -- `null`
  /// everywhere else.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ?trailing,
          ],
        ),
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

/// [slotCount] fixed slot cards -- always exactly that many, whether or
/// not they're all filled -- rather than the old "only show a section if
/// non-empty" list. A direct GM ask (2026-08-10): "I need a way to
/// denote that I have 2 Development slots... and also two Inactive
/// slots." An empty slot is still a real, visible fact about the
/// roster (an open spot the GM could fill), not a gap to hide.
class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.franchise,
    required this.title,
    required this.status,
    required this.slotCount,
    required this.members,
  });

  final Franchise franchise;
  final String title;
  final RosterStatus status;
  final int slotCount;
  final List<RosterMembership> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${members.length}/$slotCount)',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < slotCount; i++) ...[
                i < members.length
                    ? _OccupiedSlot(
                        franchise: franchise,
                        membership: members[i],
                      )
                    : _EmptySlot(franchise: franchise, status: status),
                if (i != slotCount - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A filled Development/Inactive slot -- the exact same `_PlayerRow`
/// treatment every other roster row gets (portrait, stat chips, traits;
/// nothing about this player's own information should read as "less"
/// just because of where they sit on the roster), with a move-player
/// menu attached as [_PlayerRow.trailing].
class _OccupiedSlot extends ConsumerWidget {
  const _OccupiedSlot({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = membership.player;
    // The other 2 statuses this player could move to -- each disabled
    // (with a reason) if its own slot has no room, rather than letting
    // the GM pick it and silently nothing happen.
    final destinations = RosterStatus.values.where(
      (s) => s != membership.status,
    );

    return _PlayerRow(
      franchise: franchise,
      membership: membership,
      trailing: PopupMenuButton<RosterStatus>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Move player',
        onSelected: (newStatus) => ref
            .read(currentFranchiseProvider.notifier)
            .moveRosterStatus(player.id, newStatus),
        itemBuilder: (context) => [
          for (final destination in destinations)
            PopupMenuItem(
              value: destination,
              enabled: _hasRoomFor(franchise, destination, player),
              child: Text(
                _hasRoomFor(franchise, destination, player)
                    ? 'Move to ${destination.label}'
                    : 'Move to ${destination.label} (full)',
              ),
            ),
        ],
      ),
    );
  }
}

/// An open Development/Inactive slot -- names the status plainly and
/// offers an "Assign" action rather than looking like a gap in the list.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.franchise, required this.status});

  final Franchise franchise;
  final RosterStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.person_add_alt_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Empty slot',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  _AssignPlayerSheet(franchise: franchise, status: status),
            );
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

/// Whether [franchise] has room for [player] at [destination] -- mirrors
/// `current_franchise_provider.dart`'s own private `_hasOpenSlot` guard
/// (see that one's own doc comment for why [RosterStatus.active] always
/// has room -- a legality warning, not a structural cap, handles it
/// instead), duplicated here (rather than shared) purely so this screen
/// can show *why* a move is disabled instead of just silently no-op-ing
/// on tap.
bool _hasRoomFor(Franchise franchise, RosterStatus destination, Player player) {
  final count = franchise.roster.where((m) => m.status == destination).length;
  return switch (destination) {
    RosterStatus.active => true,
    RosterStatus.developmental =>
      count < kMaxDevelopmentalRosterSpots && isDevelopmentalEligible(player),
    RosterStatus.reserveInactive => count < kMaxInactiveRosterSpots,
  };
}

/// The bottom sheet an empty Development/Inactive slot's "Assign" button
/// opens -- every eligible candidate to fill it, roster players first
/// (anyone not already at [status]) then free agents, tap to place them.
/// A direct GM ask included signing a free agent straight into a dev
/// slot ("So I could potentially sign a young FA into one of my dev
/// slots") -- both paths land here rather than needing two different
/// flows.
class _AssignPlayerSheet extends ConsumerWidget {
  const _AssignPlayerSheet({required this.franchise, required this.status});

  final Franchise franchise;
  final RosterStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    bool eligible(Player player) =>
        status != RosterStatus.developmental || isDevelopmentalEligible(player);

    // Injured candidates first (2026-08-21, a direct GM ask -- this sheet
    // is exactly where a GM goes looking for who to park while they heal),
    // best overall first within each of those 2 groups.
    final rosterCandidates =
        franchise.roster
            .where((m) => m.status != status && eligible(m.player))
            .toList()
          ..sort((a, b) {
            final injuredCompare = (b.injury != null ? 1 : 0).compareTo(
              a.injury != null ? 1 : 0,
            );
            if (injuredCompare != 0) return injuredCompare;
            return b.player.ratings.overall.compareTo(a.player.ratings.overall);
          });
    final freeAgentCandidates = franchise.freeAgents.where(eligible).toList()
      ..sort((a, b) => b.ratings.potential.compareTo(a.ratings.potential));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign to ${status.label}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (rosterCandidates.isEmpty && freeAgentCandidates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('No eligible players right now.'),
                    ),
                  if (rosterCandidates.isNotEmpty) ...[
                    Text('On Your Roster', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    for (final membership in rosterCandidates)
                      _CandidateRow(
                        player: membership.player,
                        subtitle:
                            '${membership.injury != null ? '🚑 ' : ''}'
                            'Currently ${membership.status.label}',
                        onTap: () async {
                          await ref
                              .read(currentFranchiseProvider.notifier)
                              .moveRosterStatus(membership.player.id, status);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                  ],
                  if (freeAgentCandidates.isNotEmpty) ...[
                    if (rosterCandidates.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    Text('Free Agents', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    for (final player in freeAgentCandidates)
                      _CandidateRow(
                        player: player,
                        subtitle: 'Free Agent',
                        onTap: () async {
                          await ref
                              .read(currentFranchiseProvider.notifier)
                              .signFreeAgent(player.id, status: status);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.player,
    required this.subtitle,
    required this.onTap,
  });

  final Player player;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        '${player.primaryPosition.abbreviation} ${player.lastName} '
        '(${player.ratings.overall} OVR, ${player.ratings.potential} POT)',
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.add_circle_outline),
    );
  }
}

/// The production roster row -- Player Card Lab's #11 "Left Rail: Badge +
/// Bubble" (`player_card_lab_screen.dart`), the design the GM picked
/// after 3 rounds of feedback: jersey badge on the photo, OVR bubble
/// underneath it (not on the right, which left too little room for the
/// identity block and forced long names to truncate), and OFF/DEF/PHY as
/// colored stat chips, plus a POT chip (2026-08-11, a direct GM ask --
/// `StatChipRow`'s `extra` param, same one Player Market's rows already
/// used). The identity line has no `maxLines`/ellipsis -- nothing here
/// ever cuts a name off.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.franchise,
    required this.membership,
    this.isStarter = false,
    this.trailing,
  });

  final Franchise franchise;
  final RosterMembership membership;
  final bool isStarter;

  /// An extra action alongside the identity line -- the Development/
  /// Inactive slots' move-player menu (2026-08-10). `null` everywhere
  /// else (the Active section has no per-row action).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;
    final accentColor = franchise.team.colors.primary;

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
            PhotoOvrRail(
              franchise: franchise,
              player: player,
              accentColor: accentColor,
              jersey: parseHexColor(franchise.team.colors.primaryHex),
              cornerBadge: membership.injury == null
                  ? null
                  : const Text('🚑', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${player.primaryPosition.abbreviation} '
                          '${player.nickname == null ? player.name : '${player.name} "${player.nickname}"'}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isStarter) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const _StarterBadge(),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        trailing!,
                      ],
                    ],
                  ),
                  Text(
                    '${player.archetype.label} · Age ${player.age} · '
                    '${experienceLabel(player)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  StatChipRow(
                    player: player,
                    extra: [
                      StatChip(
                        label: 'POT',
                        value: player.ratings.potential,
                        color: statChipTone(context, Colors.purple),
                      ),
                    ],
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
                  if (membership.injury != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _InjuryLine(injury: membership.injury!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks a player among the top 5 in roster order (see [_PlayerRow]'s
/// [_PlayerRow.isStarter]). A small text badge instead of a lone star icon
/// (2026-08-09, a direct GM ask) -- a bare star here read as a quality
/// rating to the GM at a glance, since this app has a real star-quality
/// concept elsewhere and nothing distinguished the two. Text can't be
/// misread the same way. Same rounded-pill treatment the Dashboard's
/// PRESEASON tag uses (`dashboard_screen.dart`'s `_UpcomingGameRow`), just
/// primary-tinted rather than neutral gray -- this is meant to read as a
/// highlight, the same spirit the League tab's "Your Team" tint carries,
/// not a plain informational fact.
/// A full-width line below a player's trait chips -- [membership.injury]'s
/// severity and games-remaining, led with the ambulance emoji
/// (2026-08-21, a direct GM ask: "It should be super obvious that they
/// are injured" -- the small inline pill this replaced sat quietly next
/// to the name; this is deliberately its own line, same spot a trait row
/// would sit, so it can't be missed). [PhotoOvrRail]'s own corner badge
/// (`_PlayerRow`'s `cornerBadge`) repeats the same ambulance emoji right
/// on the portrait, a second, even harder-to-miss signal. Plain facts
/// only, same "for flavor text vs formula, I'm fine with just facts
/// only" tone the whole injuries system already set (2026-08-20).
class _InjuryLine extends StatelessWidget {
  const _InjuryLine({required this.injury});

  final PlayerInjury injury;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Text('🚑', style: TextStyle(fontSize: 14)),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${injury.severity.label} injury -- '
          '${injury.gamesRemainingAtSeverity} game'
          '${injury.gamesRemainingAtSeverity == 1 ? '' : 's'} until recovery',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StarterBadge extends StatelessWidget {
  const _StarterBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'STARTER',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
