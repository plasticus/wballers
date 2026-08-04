import 'dart:math';

import '../../../core/generation/name_pools.dart';
import '../../../core/ratings/rating_scale.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/generation/portrait_generator.dart';
import '../domain/coach.dart';
import '../domain/coach_stats.dart';

int _generateStat(Random random, int qualityCenter, int spread) {
  final jitter = random.nextInt(spread * 2 + 1) - spread;
  return (qualityCenter + jitter).clamp(kMinRating, kMaxRating);
}

/// Generates a coach with a random name and jittered stats around
/// [qualityCenter] -- a hired NPC, not a blank [CoachStats.neutral] clone,
/// so a new franchise's starting coach feels like a distinct individual
/// the same way a generated player does. Deterministic for a given
/// [random] stream.
///
/// [portraitWeights] is optional, same contract as `generatePlayer`'s: omit
/// it to leave [Coach.appearance] `null` without consuming any random
/// numbers for it. [portraitManifest] is separately optional -- without it,
/// a generated coach's [PortraitAppearance.shoulders] stays `null`, same as
/// before a manifest was threaded through at all.
Coach generateCoach(
  Random random, {
  int qualityCenter = 50,
  int qualitySpread = 15,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final firstName = kFirstNames[random.nextInt(kFirstNames.length)];
  final lastName = kLastNames[random.nextInt(kLastNames.length)];
  final appearance = portraitWeights == null
      ? null
      : generatePortraitAppearance(
          random,
          isCoach: true,
          weights: portraitWeights,
          manifest: portraitManifest,
        );

  return Coach(
    name: '$firstName $lastName',
    stats: CoachStats(
      offense: _generateStat(random, qualityCenter, qualitySpread),
      defense: _generateStat(random, qualityCenter, qualitySpread),
      development: _generateStat(random, qualityCenter, qualitySpread),
      motivation: _generateStat(random, qualityCenter, qualitySpread),
      management: _generateStat(random, qualityCenter, qualitySpread),
    ),
    appearance: appearance,
  );
}
