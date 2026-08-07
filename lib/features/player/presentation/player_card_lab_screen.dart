import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import '../domain/trait.dart';
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
    final round2Player = _round2TestPlayer();

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
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Round 2: combining #2\'s OVR badge with #3\'s stat chips -- '
              'the two you called out -- on a made-up player with a long '
              'name and a trait, to stress-test what #2 alone couldn\'t '
              'show. "${round2Player.name}".',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _LabSection(
              label: '6. OVR Badge + Stat Chips',
              child: _CombinedCard(franchise: franchise, player: round2Player),
            ),
            _LabSection(
              label: '7. Lastname, First',
              child: _LastNameFirstCard(
                franchise: franchise,
                player: round2Player,
              ),
            ),
            _LabSection(
              label: '8. Jersey Badge on Photo',
              child: _JerseyOnPhotoCard(
                franchise: franchise,
                player: round2Player,
              ),
            ),
            _LabSection(
              label: '9. Jersey Gets Its Own Column',
              child: _JerseyColumnCard(
                franchise: franchise,
                player: round2Player,
              ),
            ),
            _LabSection(
              label: '10. Refined',
              child: _RefinedCard(franchise: franchise, player: round2Player),
            ),
          ],
        ),
      ),
    );
  }
}

/// A made-up player for Round 2 -- deliberately a long name and at least
/// one trait, since #1's feedback specifically worried a long name would
/// "look like junk" and asked whether traits were shown at all (#2/#3
/// weren't). No `appearance` (falls back to the placeholder portrait
/// `PortraitImage` already handles gracefully) -- this is about text
/// layout, not a real generated look.
Player _round2TestPlayer() {
  return Player(
    id: 'lab-round2',
    name: 'Alexandria Castellanos-Whitmore',
    age: 26,
    yearsOfService: 5,
    hometown: 'Fictional City',
    primaryPosition: Position.shootingGuard,
    handedness: Handedness.right,
    biography: '',
    ratings: const PlayerRatings(
      speed: 78,
      agility: 74,
      strength: 65,
      stamina: 80,
      ballControl: 70,
      passing: 68,
      interiorOffense: 60,
      perimeterOffense: 88,
      perimeterDefense: 75,
      interiorDefense: 55,
      disruption: 62,
      blocking: 40,
      potential: 90,
    ),
    heightInches: 71,
    archetype: Archetype.sniper,
    traits: const {Trait.leader, Trait.sharpshooter},
    jerseyNumber: 23,
  );
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

/// "EXP: 12" or "Rookie" at 0 -- years of service. Shared by every card
/// here. Swapped from "12 yrs WBL" after a round of feedback on the first
/// batch: shorter, and "Rookie" reads better than "0 yrs WBL" for a
/// player who hasn't debuted yet.
String _experienceLabel(Player player) {
  final years = player.yearsOfService;
  return years == 0 ? 'Rookie' : 'EXP: $years';
}

/// "#7" or '' -- jersey numbers are nullable until a player is actually
/// placed on a roster (shouldn't happen for anyone shown in this lab, but
/// graceful regardless).
String _jerseyLabel(Player player) =>
    player.jerseyNumber != null ? '#${player.jerseyNumber}' : '';

/// "Castellanos-Whitmore, Alexandria" -- last-name-first formatting, for
/// the one card in the second batch that tries it.
String _lastCommaFirst(Player player) {
  final parts = player.name.split(' ');
  if (parts.length < 2) return player.name;
  final last = parts.sublist(1).join(' ');
  return '$last, ${parts.first}';
}

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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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

/// Shared OVR badge -- the team-colored circle from #2, reused by every
/// Round 2 card.
class _OvrBubble extends StatelessWidget {
  const _OvrBubble({required this.overall, required this.color});

  final int overall;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$overall',
        style: theme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Shared stat-chip row -- the 3 colored pills from #3, reused by every
/// Round 2 card.
class _StatChipRow extends StatelessWidget {
  const _StatChipRow({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
    );
  }
}

/// Shared trait row -- omitted entirely by #2 and #3 in the first batch,
/// which is exactly the gap Round 2 closes.
class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    if (player.traits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [for (final trait in player.traits) TraitChip(trait: trait)],
      ),
    );
  }
}

/// 6. The direct combo: #2's OVR badge plus #3's stat chips, with traits
/// added back in (neither #2 nor #3 had them) and the identity line made
/// ellipsis-safe -- a real answer to "I worry with longer names that it's
/// going to look like junk."
class _CombinedCard extends StatelessWidget {
  const _CombinedCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatChipRow(player: player),
                _TraitRow(player: player),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OvrBubble(
            overall: player.ratings.overall,
            color: franchise.team.colors.primary,
          ),
        ],
      ),
    );
  }
}

/// 7. Same as #6, but the name reads "Lastname, First" -- a specific ask
/// to try, and a real test of whether it reads worse or better with a
/// hyphenated surname.
class _LastNameFirstCard extends StatelessWidget {
  const _LastNameFirstCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  '${_jerseyLabel(player)} ${_lastCommaFirst(player)}',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatChipRow(player: player),
                _TraitRow(player: player),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OvrBubble(
            overall: player.ratings.overall,
            color: franchise.team.colors.primary,
          ),
        ],
      ),
    );
  }
}

/// 8. The jersey number moves off the text line entirely and onto the
/// portrait itself, as a small team-colored badge over its corner -- one
/// of the "make the jersey number stand out" attempts. Frees the name
/// line up too, which now reads just "SG Alexandria Castellanos-Whitmore".
class _JerseyOnPhotoCard extends StatelessWidget {
  const _JerseyOnPhotoCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = franchise.team.colors.primary;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PortraitImage(
                saveId: franchise.id,
                ownerId: player.id,
                appearance: player.appearance,
                jersey: parseHexColor(franchise.team.colors.primaryHex),
                size: 64,
              ),
              if (player.jerseyNumber != null)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 1,
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
                      '#${player.jerseyNumber}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} ${player.name}',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatChipRow(player: player),
                _TraitRow(player: player),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OvrBubble(overall: player.ratings.overall, color: accentColor),
        ],
      ),
    );
  }
}

/// 9. The other "make the jersey stand out" attempt: instead of a badge
/// on the photo, the jersey number gets its own big standalone column
/// between the photo and the identity block -- a second, smaller number
/// next to OVR's big one, rather than folded into a text line.
class _JerseyColumnCard extends StatelessWidget {
  const _JerseyColumnCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = franchise.team.colors.primary;
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
          const SizedBox(width: AppSpacing.sm),
          if (player.jerseyNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
              child: Column(
                children: [
                  Text(
                    '#${player.jerseyNumber}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} ${player.name}',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatChipRow(player: player),
                _TraitRow(player: player),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OvrBubble(overall: player.ratings.overall, color: accentColor),
        ],
      ),
    );
  }
}

/// 10. The polished version: ellipsis-safe name, EXP:/Rookie formatting,
/// OVR bubble, stat chips, traits, and the jersey number stands out
/// through color and weight inline rather than a separate badge/column --
/// a lighter-touch third option after #8 and #9's more literal attempts.
class _RefinedCard extends StatelessWidget {
  const _RefinedCard({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = franchise.team.colors.primary;
    final jerseyStyle = theme.textTheme.titleMedium?.copyWith(
      color: accentColor,
      fontWeight: FontWeight.bold,
    );

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
                Row(
                  children: [
                    Text(
                      player.primaryPosition.abbreviation,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (player.jerseyNumber != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text('#${player.jerseyNumber}', style: jerseyStyle),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        player.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${player.archetype.label} · Age ${player.age} · '
                  '${_experienceLabel(player)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatChipRow(player: player),
                _TraitRow(player: player),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OvrBubble(overall: player.ratings.overall, color: accentColor),
        ],
      ),
    );
  }
}
