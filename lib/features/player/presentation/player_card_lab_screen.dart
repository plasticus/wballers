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
/// via 5 variations on the compact-row shape, so the GM can pick a
/// direction before one replaces the current roster row. Second pass --
/// the first lab tried 4 wildly different shapes (a vertical trading
/// card, a ticket stub, a scoreboard tile), and the compact row was the
/// only one that landed: "I like the photo on the left, OVR on the
/// right." This lab stays inside that shape and varies the details
/// instead -- bigger photo, jersey number, years of WBL experience, and
/// how much weight OVR carries -- since "I'm still not quite there, and I
/// can't describe what I want very well" called for closer, not
/// different, options. Not linked from anywhere a normal playthrough
/// would stumble into by accident, but not hidden either -- reachable via
/// the Team tab's "Card Lab" button.
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
              'Same player, 5 variations on the compact row -- '
              '${membership.player.name}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _LabSection(
              label: '1. Bigger, Same Shape',
              child: _BiggerSameShapeCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '2. OVR Badge',
              child: _OvrBadgeCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '3. Stat Chips',
              child: _StatChipsCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '4. Two-Line Header',
              child: _TwoLineHeaderCard(
                franchise: franchise,
                membership: membership,
              ),
            ),
            _LabSection(
              label: '5. Minimal',
              child: _MinimalCard(franchise: franchise, membership: membership),
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

/// "3 yr WBL" / "1 yr WBL" -- years of service, singular-aware. Shared by
/// every card here since it's a new requirement across all 5, not just
/// one variation.
String _experienceLabel(Player player) {
  final years = player.yearsOfService;
  return '$years ${years == 1 ? 'yr' : 'yrs'} WBL';
}

/// "#7" or '' -- jersey numbers are nullable until a player is actually
/// placed on a roster (shouldn't happen for anyone shown in this lab, but
/// graceful regardless).
String _jerseyLabel(Player player) =>
    player.jerseyNumber != null ? '#${player.jerseyNumber}' : '';

/// 1. A direct scale-up of the original compact row: bigger portrait
/// (64px, up from 40px), jersey number folded into the position badge,
/// years of WBL experience added to the identity line, and OVR bumped
/// from `titleMedium` to a bold `headlineSmall` on the right -- every
/// literal ask from the GM's feedback, minimal structural change.
class _BiggerSameShapeCard extends StatelessWidget {
  const _BiggerSameShapeCard({
    required this.franchise,
    required this.membership,
  });

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
            size: 64,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} '
                  '${_jerseyLabel(player)} ${player.name}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('OVR', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Same identity block as #1, but OVR gets real visual weight: a big
/// team-colored circular badge on the right instead of plain text --
/// "Overall Score should be a bigger number than other stuff" taken as
/// far as a compact row reasonably allows.
class _OvrBadgeCard extends StatelessWidget {
  const _OvrBadgeCard({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;
    final accentColor = franchise.team.colors.primary;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PortraitImage(
            saveId: franchise.id,
            ownerId: player.id,
            appearance: player.appearance,
            jersey: parseHexColor(franchise.team.colors.primaryHex),
            size: 60,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} '
                  '${_jerseyLabel(player)} ${player.name}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'OFF ${player.ratings.offenseOverall} · '
                  'DEF ${player.ratings.defenseOverall} · '
                  'PHY ${player.ratings.physicalOverall}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${player.ratings.overall}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. OFF/DEF/PHY as small colored chips instead of a plain text line --
/// more scannable at a glance than three numbers run together, same
/// visual language the trait chips already use.
class _StatChipsCard extends StatelessWidget {
  const _StatChipsCard({required this.franchise, required this.membership});

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
            size: 64,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} '
                  '${_jerseyLabel(player)} ${player.name}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _StatChip(
                      label: 'OFF',
                      value: player.ratings.offenseOverall,
                      color: Colors.orange.shade700,
                    ),
                    _StatChip(
                      label: 'DEF',
                      value: player.ratings.defenseOverall,
                      color: Colors.blue.shade700,
                    ),
                    _StatChip(
                      label: 'PHY',
                      value: player.ratings.physicalOverall,
                      color: Colors.green.shade700,
                    ),
                  ],
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('OVR', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 4. The identity block splits into two deliberate lines -- a bold
/// header ("PG #7 Kayla Silva") and a plain subtitle (archetype, age,
/// experience) -- and OVR drops its "OVR" caption entirely, just a big
/// number, on the theory that position in the layout already says what
/// it is. The most OVR-dominant of the 5 -- no badge chrome around it,
/// just size.
class _TwoLineHeaderCard extends StatelessWidget {
  const _TwoLineHeaderCard({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PortraitImage(
            saveId: franchise.id,
            ownerId: player.id,
            appearance: player.appearance,
            jersey: parseHexColor(franchise.team.colors.primaryHex),
            size: 68,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} '
                  '${_jerseyLabel(player)} ${player.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
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
          const SizedBox(width: AppSpacing.md),
          Text(
            '${player.ratings.overall}',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: franchise.team.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Deliberately the lightest of the 5 -- no OFF/DEF/PHY breakdown at
/// all, just identity and traits next to a big photo and a big OVR. A
/// clean contrast against the denser options above, for a GM who wants
/// the roster row to read fast rather than show everything at once.
class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.franchise, required this.membership});

  final Franchise franchise;
  final RosterMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PortraitImage(
            saveId: franchise.id,
            ownerId: player.id,
            appearance: player.appearance,
            jersey: parseHexColor(franchise.team.colors.primaryHex),
            size: 56,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} '
                  '${_jerseyLabel(player)} ${player.name}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Age ${player.age} · ${_experienceLabel(player)}',
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
          Text(
            '${player.ratings.overall}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
