import 'dart:math';

import '../domain/portrait_appearance.dart';
import '../domain/portrait_height_tier.dart';
import '../domain/portrait_manifest.dart';
import '../domain/portrait_weights.dart';

/// The baseline-height base sprite (`portraits.md`'s asset audit):
/// feminine, and the Flutter default for both athletes and coaches (coaches
/// have no height stat, so they always render at this tier).
const kDefaultBaseSprite = kBaselineBaseSprite;

/// "Goggles" read as athletic eyewear, not something a coach would wear on
/// the sideline -- the original portrait-creator tool (`player-edit.html`)
/// flags a coach with goggles as stale/wrong data via a diagnostic, even
/// though the schema doesn't structurally forbid it. Filtered out of the
/// pool before picking a coach's accessory; players draw from the full set.
Map<String, double> _coachEligibleAccessories(Map<String, double> pool) {
  return Map.fromEntries(
    pool.entries.where((entry) => !entry.key.startsWith('goggles')),
  );
}

/// Generates a portrait appearance from [weights]. Deterministic for a
/// given [random] stream.
///
/// Athletes never get facial hair (`portraits.md`); coaches roll one from
/// [PortraitWeights.facial] (which includes its own `none` outcome).
/// Neither ever rolls a special/neon top-hair color at generation time --
/// [PortraitWeights.neonHair] exists for a future unlock/achievement
/// system to draw on, not for random generation, per the doc's explicit
/// "select special hair colors only from unlocked cosmetic rules."
///
/// [manifest] is only needed for a coach's [PortraitAppearance.shoulders]
/// -- there's no weight table for it anywhere in the original tooling, so
/// it's a uniform pick over [PortraitManifest.shoulders] rather than a
/// [pickWeighted] draw. A coach without a manifest keeps the old
/// null-shoulders behavior rather than throwing; every real call site
/// passes one.
///
/// [heightTier] selects which base-sprite variant to render with --
/// defaults to [PortraitHeightTier.baseline], correct for a coach (no
/// height stat) or any caller that doesn't have a player's height handy.
/// Real athlete generation passes `portraitHeightTierForInches(heightInches)`.
PortraitAppearance generatePortraitAppearance(
  Random random, {
  required bool isCoach,
  required PortraitWeights weights,
  PortraitManifest? manifest,
  PortraitHeightTier heightTier = PortraitHeightTier.baseline,
}) {
  final skinTone = pickWeighted(random, weights.skinTone);
  final hairColor = pickWeighted(random, weights.hairColorByTone[skinTone]!);

  final hair = pickWeighted(random, weights.hair);
  final eyebrows = pickWeighted(random, weights.eyebrows);
  final accessoriesPool = isCoach
      ? _coachEligibleAccessories(weights.accessories)
      : weights.accessories;
  final accessories = pickWeighted(random, accessoriesPool);
  final facial = isCoach ? pickWeighted(random, weights.facial) : 'none';
  final shoulders = isCoach && manifest != null
      ? manifest.shoulders[random.nextInt(manifest.shoulders.length)]
      : null;

  return PortraitAppearance(
    baseSprite: heightTier.baseSpriteAsset,
    skinTone: skinTone,
    hair: hair == 'none' ? null : hair,
    hairColor: hairColor,
    eyes: pickWeighted(random, weights.eyes),
    eyebrows: eyebrows == 'none' ? null : eyebrows,
    nose: pickWeighted(random, weights.nose),
    mouth: pickWeighted(random, weights.mouth),
    accessories: accessories == 'none' ? null : accessories,
    isCoach: isCoach,
    shoulders: shoulders == null ? null : _stripExtension(shoulders),
    facial: facial == 'none' ? null : facial,
  );
}

String _stripExtension(String filename) => filename.endsWith('.png')
    ? filename.substring(0, filename.length - '.png'.length)
    : filename;
