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
/// Nobody generated here ever gets facial hair -- athletes never did
/// (`portraits.md`), and coaches were briefly generating one from
/// [PortraitWeights.facial] (a beard/mustache/stubble pool with no
/// feminine-presenting options) before a GM playtest surfaced the obvious
/// bug: every character in this game is a woman (`kDefaultBaseSprite`'s
/// own doc comment already says as much), so a coach growing a mustache
/// read as broken, not as a coach with facial hair being a real design
/// option. [PortraitWeights.facial] and [PortraitManifest] still carry the
/// data (the original portrait-creator tool this was ported from supports
/// it), it's just never drawn from at generation time -- kept rather than
/// deleted in case a future customization screen wants to let a GM opt a
/// coach into it deliberately, which is a different thing than the RNG
/// picking it for them.
///
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
///
/// [skinToneOverride], when given, replaces [PortraitWeights.skinTone] as
/// the table [pickWeighted] draws a skin tone from -- `player_generator.dart`
/// passes a player's country-specific table (falling back to the flat
/// [PortraitWeights.skinTone] itself if the country isn't in
/// [PortraitWeights.skinToneByCountry]), optionally with pale/light
/// already filtered out for a `kSkinToneFlooredGivenNames` first name.
/// `null` (every coach, and any player call before country wiring
/// existed) keeps the old flat-table behavior exactly.
PortraitAppearance generatePortraitAppearance(
  Random random, {
  required bool isCoach,
  required PortraitWeights weights,
  PortraitManifest? manifest,
  PortraitHeightTier heightTier = PortraitHeightTier.baseline,
  Map<String, double>? skinToneOverride,
}) {
  final skinTone = pickWeighted(random, skinToneOverride ?? weights.skinTone);
  final hairColor = pickWeighted(random, weights.hairColorByTone[skinTone]!);

  final hair = pickWeighted(random, weights.hair);
  final eyebrows = pickWeighted(random, weights.eyebrows);
  final accessoriesPool = isCoach
      ? _coachEligibleAccessories(weights.accessories)
      : weights.accessories;
  final accessories = pickWeighted(random, accessoriesPool);
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
    facial: null,
  );
}

String _stripExtension(String filename) => filename.endsWith('.png')
    ? filename.substring(0, filename.length - '.png'.length)
    : filename;
