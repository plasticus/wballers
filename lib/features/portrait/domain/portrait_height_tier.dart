import '../../player/domain/player.dart';

/// The tallest height (inclusive) that still counts as [PortraitHeightTier.baseline].
const kBaselineMaxHeightInches = 72; // 6'0"

/// The tallest height (inclusive) that still counts as [PortraitHeightTier.tall].
/// Anything above this is [PortraitHeightTier.tallest].
const kTallMaxHeightInches = 76; // 6'4"

/// The three base-sprite assets, one per [PortraitHeightTier]. Plain
/// top-level consts (rather than values computed inside
/// [PortraitHeightTierAsset.baseSpriteAsset]) so `portrait_generator.dart`'s
/// `kDefaultBaseSprite` can stay a genuine compile-time constant -- needed
/// since several `const PortraitAppearance(...)` fixtures reference it.
const kBaselineBaseSprite = 'base/BlankBaldwoman32H0.png';
const kTallBaseSprite = 'base/BlankBaldwoman32H1.png';
const kTallestBaseSprite = 'base/BlankBaldwoman32H2.png';

/// Which base-sprite variant (`base/BlankBaldwoman32H0/H1/H2.png`) and
/// overlay-layer shift a player's portrait should use, derived from their
/// actual [Player.heightInches] rather than their position -- see
/// `0B_Planned.md`'s height-shift-by-position item.
///
/// Cutoffs come from the real distribution `generatePlayer` produces, not a
/// guess: ~42% baseline, ~38% tall, ~20% tallest, roughly matching real
/// WNBA height spread (mostly 5'8"-6'7") while keeping the tallest tier
/// the rarest, same shape as the real league.
enum PortraitHeightTier {
  baseline,
  tall,
  tallest;

  static PortraitHeightTier of(Player player) =>
      portraitHeightTierForInches(player.heightInches);
}

/// The classification logic behind [PortraitHeightTier.of], usable during
/// player generation before a full [Player] exists to check.
PortraitHeightTier portraitHeightTierForInches(int heightInches) {
  if (heightInches <= kBaselineMaxHeightInches) {
    return PortraitHeightTier.baseline;
  }
  if (heightInches <= kTallMaxHeightInches) return PortraitHeightTier.tall;
  return PortraitHeightTier.tallest;
}

extension PortraitHeightTierAsset on PortraitHeightTier {
  /// The base-sprite asset this tier renders with. The sprite alone
  /// accounts for the height difference (taller body/shoulders baked into
  /// the art) -- see [overlayShiftPixels] for what the *other* layers need.
  String get baseSpriteAsset => switch (this) {
    PortraitHeightTier.baseline => kBaselineBaseSprite,
    PortraitHeightTier.tall => kTallBaseSprite,
    PortraitHeightTier.tallest => kTallestBaseSprite,
  };

  /// How many pixels the overlay layers (hair, eyes, eyebrows, nose, mouth,
  /// accessories -- everything above the base sprite except a coach's
  /// shoulders, which stay anchored to the body) must shift up to align
  /// with this tier's base sprite. Measured directly from the art: each
  /// taller variant's head silhouette starts exactly this many pixels
  /// higher than [PortraitHeightTier.baseline]'s.
  int get overlayShiftPixels => switch (this) {
    PortraitHeightTier.baseline => 0,
    PortraitHeightTier.tall => 1,
    PortraitHeightTier.tallest => 2,
  };
}

/// Reverse lookup from a stored [PortraitAppearance.baseSprite] path back to
/// the tier it represents, so the renderer can derive the overlay shift
/// purely from already-persisted appearance data rather than needing a
/// second field kept in sync with it. Unrecognized paths (shouldn't happen
/// for real data) fall back to [PortraitHeightTier.baseline], i.e. no shift.
PortraitHeightTier portraitHeightTierForBaseSprite(String baseSprite) {
  for (final tier in PortraitHeightTier.values) {
    if (tier.baseSpriteAsset == baseSprite) return tier;
  }
  return PortraitHeightTier.baseline;
}
