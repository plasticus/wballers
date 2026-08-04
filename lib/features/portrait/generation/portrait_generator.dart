import 'dart:math';

import '../domain/portrait_appearance.dart';
import '../domain/portrait_weights.dart';

/// The only base sprite currently available (`portraits.md`'s asset
/// audit): feminine, and the Flutter default for both athletes and
/// coaches.
const kDefaultBaseSprite = 'BlankBaldwoman32.png';

/// Generates a portrait appearance from [weights]. Deterministic for a
/// given [random] stream.
///
/// Athletes never get facial hair (`portraits.md`); coaches roll one from
/// [PortraitWeights.facial] (which includes its own `none` outcome).
/// Neither ever rolls a special/neon top-hair color at generation time --
/// [PortraitWeights.neonHair] exists for a future unlock/achievement
/// system to draw on, not for random generation, per the doc's explicit
/// "select special hair colors only from unlocked cosmetic rules."
PortraitAppearance generatePortraitAppearance(
  Random random, {
  required bool isCoach,
  required PortraitWeights weights,
}) {
  final skinTone = pickWeighted(random, weights.skinTone);
  final hairColor = pickWeighted(random, weights.hairColorByTone[skinTone]!);

  final hair = pickWeighted(random, weights.hair);
  final eyebrows = pickWeighted(random, weights.eyebrows);
  final accessories = pickWeighted(random, weights.accessories);
  final facial = isCoach ? pickWeighted(random, weights.facial) : 'none';

  return PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: skinTone,
    hair: hair == 'none' ? null : hair,
    hairColor: hairColor,
    eyes: pickWeighted(random, weights.eyes),
    eyebrows: eyebrows == 'none' ? null : eyebrows,
    nose: pickWeighted(random, weights.nose),
    mouth: pickWeighted(random, weights.mouth),
    accessories: accessories == 'none' ? null : accessories,
    isCoach: isCoach,
    facial: facial == 'none' ? null : facial,
  );
}
