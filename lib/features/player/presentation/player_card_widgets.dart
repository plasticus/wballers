import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/star_tier.dart';
import '../domain/player.dart';

/// Shared building blocks for showing a player's identity compactly --
/// photo, jersey number, OVR, and OFF/DEF/PHY -- landed after 3 rounds of
/// GM feedback in the Player Card Lab (`player_card_lab_screen.dart`,
/// reachable from the Team tab's "Card Lab" button, still kept around
/// as a comparison tool). `TeamRosterScreen`'s production roster row now
/// uses these directly, so a future lab pick doesn't mean redoing this
/// work a second time.

/// "EXP: 12" or "Rookie" at 0 -- years of service. Chosen over "12 yrs
/// WBL" after a round of card-lab feedback: shorter, and "Rookie" reads
/// better than "0 yrs WBL" for a player who hasn't debuted yet.
String experienceLabel(Player player) {
  final years = player.yearsOfService;
  return years == 0 ? 'Rookie' : 'EXP: $years';
}

/// A team-colored circular badge showing the player's overall rating --
/// the Card Lab's #2 "OVR Badge", one of the GM's two original favorites
/// ("I like having the OVR rating in a bubble so it really looks
/// important").
class OvrBubble extends StatelessWidget {
  const OvrBubble({required this.overall, required this.color, super.key});

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

/// [StarTier.of]'s tier as 0-4 filled ★ glyphs -- TODO.md's former "real
/// star-quality indicator" item, resolved 2026-08-10 once the tier bands
/// themselves settled (`star_system.md`: 4★ 90+, 3★ 80-89, 2★ 70-79, 1★
/// 60-69, no stars below 60). Repeated glyphs over a compact "N ⭐": at
/// most 4 characters, so there's no real length pressure, and a row of
/// stars reads at a glance the way a single number doesn't. Renders
/// nothing at all for [StarTier.noStars] rather than an empty row --
/// most of a roster sits below 60 OVR (only 6 slots per team can be
/// 3-star-or-better at all), so this is the common case, not an error
/// state, and remains genuinely space-free row-to-row.
///
/// Deliberately never a lone star *icon* anywhere near the identity line
/// -- `team_roster_screen.dart`'s `_StarterBadge` doc comment already
/// flagged that exact confusion risk ("a bare star here read as a
/// quality rating... since this app has a real star-quality concept
/// elsewhere"); this widget is that concept, finally built, and stays
/// anchored next to the OVR bubble specifically so the two badges are
/// never adjacent.
class StarTierBadge extends StatelessWidget {
  const StarTierBadge({required this.player, super.key});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final tier = StarTier.of(player);
    final count = switch (tier) {
      StarTier.fourStar => 4,
      StarTier.threeStar => 3,
      StarTier.twoStar => 2,
      StarTier.oneStar => 1,
      StarTier.noStars => 0,
    };
    if (count == 0) return const SizedBox.shrink();
    return Text(
      '★' * count,
      style: const TextStyle(color: Colors.amber, fontSize: 12, height: 1),
    );
  }
}

/// A portrait with the jersey number overlaid as a small team-colored
/// pill on its corner -- the Card Lab's #8 "Jersey Badge on Photo",
/// which the GM singled out as the favorite of 3 jersey treatments
/// tried ("I love #8's jersey badge on the photo").
class PhotoWithJerseyBadge extends StatelessWidget {
  const PhotoWithJerseyBadge({
    required this.franchise,
    required this.player,
    required this.accentColor,
    required this.jersey,
    this.size = 64,
    super.key,
  });

  final Franchise franchise;
  final Player player;
  final Color accentColor;

  /// The portrait's jersey-shirt tint. Every original caller (the
  /// production roster row) passes [franchise]'s own team color; a
  /// caller showing a player who isn't on that team -- a different AI
  /// team's player, or a free agent/draft prospect with no team at all
  /// (`market/presentation/player_market_screen.dart`) -- passes that
  /// team's color, or `null` for the portrait's neutral default.
  final RgbColor? jersey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PortraitImage(
          saveId: franchise.id,
          ownerId: player.id,
          appearance: player.appearance,
          jersey: jersey,
          size: size,
        ),
        if (player.jerseyNumber != null)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.surface, width: 2),
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
    );
  }
}

/// The left rail: `PhotoWithJerseyBadge` stacked over an `OvrBubble`.
/// Landed via the Card Lab's Round 3 (#11 "Left Rail: Badge + Bubble")
/// after Round 2's OVR-bubble-on-the-right left too little horizontal
/// room for the identity block, forcing long names to truncate ("in
/// every single one of these, the name is cut off... feels
/// dehumanizing") -- moving OVR underneath the photo instead fixed that,
/// and is what the GM picked to ship.
class PhotoOvrRail extends StatelessWidget {
  const PhotoOvrRail({
    required this.franchise,
    required this.player,
    required this.accentColor,
    required this.jersey,
    this.size = 64,
    this.cornerBadge,
    super.key,
  });

  final Franchise franchise;
  final Player player;
  final Color accentColor;
  final RgbColor? jersey;
  final double size;

  /// An optional small badge pinned to the photo's own lower-right corner
  /// -- `null` everywhere by default (every existing call site keeps its
  /// exact old look). `team_roster_screen.dart`'s `_PlayerRow` is the one
  /// caller that passes one, an ambulance emoji for an injured player
  /// (2026-08-21, a direct GM ask: "put the ambulance emoji in the lower
  /// right of their portrait").
  final Widget? cornerBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PhotoWithJerseyBadge(
              franchise: franchise,
              player: player,
              accentColor: accentColor,
              jersey: jersey,
              size: size,
            ),
            if (cornerBadge != null)
              Positioned(bottom: -2, right: -2, child: cornerBadge!),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OvrBubble(overall: player.ratings.overall, color: accentColor),
        const SizedBox(height: 2),
        StarTierBadge(player: player),
      ],
    );
  }
}

/// A stat chip's identity color, adjusted for legibility against the
/// current theme's card background -- `shade700` reads fine on light
/// theme's near-white cards, but the same shade sits too close in
/// luminance to dark theme's navy panel (`AppTheme.dark`'s `_panel`) to
/// read comfortably (2026-08-11, a direct GM report tied to their known
/// low-vision needs: "purple font on a dark blue background... really
/// hard for me to read"). A lighter shade in dark mode keeps the same
/// hue identity (orange/blue/green/purple) while actually holding
/// contrast; light mode is untouched since `shade700` was never the
/// problem there.
Color statChipTone(BuildContext context, MaterialColor swatch) {
  return Theme.of(context).brightness == Brightness.dark
      ? swatch.shade200
      : swatch.shade700;
}

/// A single OFF/DEF/PHY stat as a small colored pill -- the Card Lab's
/// #3 "Stat Chips", the GM's other original favorite ("I like the 3
/// colors on the stats, that'd make it nice to scroll through"). Pass
/// [label] as `''` for a bare number with no unit text at all -- the
/// Coach Picker's collapsed/selected picker state uses this (2026-08-11,
/// TODO.md's Coach Picker Lab item: "have all three chips just as
/// numbers when a player is selected").
class StatChip extends StatelessWidget {
  const StatChip({
    required this.label,
    required this.value,
    required this.color,
    super.key,
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
        label.isEmpty ? '$value' : '$label $value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// OFF/DEF/PHY as 3 `StatChip`s in a row, plus whatever [extra] chips a
/// caller wants tacked onto the same `Wrap` -- e.g. Player Market's rows
/// (`market/presentation/player_market_screen.dart`) add a POT chip here
/// rather than this widget always showing one, since potential matters
/// most exactly where a GM is evaluating someone *not* already on the
/// roster (a free agent, a trade target, a draft prospect) -- the
/// production roster row (`team_roster_screen.dart`) and Card Lab both
/// call this with no [extra] and are unaffected.
class StatChipRow extends StatelessWidget {
  const StatChipRow({required this.player, this.extra = const [], super.key});

  final Player player;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatChip(
          label: 'OFF',
          value: player.ratings.offenseOverall,
          color: statChipTone(context, Colors.orange),
        ),
        StatChip(
          label: 'DEF',
          value: player.ratings.defenseOverall,
          color: statChipTone(context, Colors.blue),
        ),
        StatChip(
          label: 'PHY',
          value: player.ratings.physicalOverall,
          color: statChipTone(context, Colors.green),
        ),
        ...extra,
      ],
    );
  }
}
