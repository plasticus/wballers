import 'dart:math';

import '../../../core/generation/name_pools.dart';
import '../../../core/ratings/rating_scale.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/generation/portrait_generator.dart';
import '../domain/coach.dart';
import '../domain/coach_archetype.dart';
import '../domain/coach_stats.dart';

/// Per-stat adjustments layered on top of a coach's random base value
/// before clamping to the 1-99 scale -- same "archetype rolled first, then
/// biases the stat block" shape `player_generator.dart` uses, just with no
/// second bias source to combine (coaches have no position-equivalent
/// concept). Magnitudes are the only thing separating one archetype from
/// another, so they run a bit larger than a player archetype's on-top-of-
/// position bias -- initial guess, not yet calibrated against anything.
typedef _StatDeltas = ({
  int offense,
  int defense,
  int development,
  int motivation,
  int management,
});

const _zeroDeltas = (
  offense: 0,
  defense: 0,
  development: 0,
  motivation: 0,
  management: 0,
);

const Map<CoachArchetype, _StatDeltas> _archetypeBias = {
  CoachArchetype.offensiveInnovator: (
    offense: 14,
    defense: -6,
    development: 0,
    motivation: 2,
    management: 0,
  ),
  CoachArchetype.defensiveMastermind: (
    offense: -6,
    defense: 14,
    development: 0,
    motivation: 2,
    management: 0,
  ),
  CoachArchetype.playersCoach: (
    offense: 0,
    defense: 0,
    development: 8,
    motivation: 14,
    management: -6,
  ),
  CoachArchetype.talentDeveloper: (
    offense: 0,
    defense: 0,
    development: 14,
    motivation: -6,
    management: 0,
  ),
  CoachArchetype.programBuilder: (
    offense: 0,
    defense: 0,
    development: -4,
    motivation: -6,
    management: 14,
  ),
  CoachArchetype.oldSchoolDisciplinarian: (
    offense: -8,
    defense: 10,
    development: -2,
    motivation: 10,
    management: -2,
  ),
  CoachArchetype.fieryCompetitor: (
    offense: 4,
    defense: 4,
    development: -10,
    motivation: 14,
    management: -4,
  ),
  // Deliberately zero -- a "no real weakness, no real standout" generalist
  // is its own legitimate archetype, not a missing entry.
  CoachArchetype.steadyHand: _zeroDeltas,
};

int _generateStat(Random random, int qualityCenter, int spread, int bias) {
  final jitter = random.nextInt(spread * 2 + 1) - spread;
  return (qualityCenter + bias + jitter).clamp(kMinRating, kMaxRating);
}

/// Generates a coach with a random name, a rolled [CoachArchetype], and
/// jittered stats around [qualityCenter] biased to fit that archetype --
/// a hired NPC, not a blank [CoachStats.neutral] clone, so a new
/// franchise's starting coach feels like a distinct individual the same
/// way a generated player does. Deterministic for a given [random] stream.
///
/// [archetype] defaults to a random roll; pass one explicitly to force a
/// specific style instead -- what [generateCoachCandidates] does to build
/// a set of head-coach options the GM picks between at onboarding, each
/// with a different, already-known philosophy rather than another random
/// roll.
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
  CoachArchetype? archetype,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final resolvedArchetype =
      archetype ??
      CoachArchetype.values[random.nextInt(CoachArchetype.values.length)];
  final bias = _archetypeBias[resolvedArchetype] ?? _zeroDeltas;

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
      offense: _generateStat(
        random,
        qualityCenter,
        qualitySpread,
        bias.offense,
      ),
      defense: _generateStat(
        random,
        qualityCenter,
        qualitySpread,
        bias.defense,
      ),
      development: _generateStat(
        random,
        qualityCenter,
        qualitySpread,
        bias.development,
      ),
      motivation: _generateStat(
        random,
        qualityCenter,
        qualitySpread,
        bias.motivation,
      ),
      management: _generateStat(
        random,
        qualityCenter,
        qualitySpread,
        bias.management,
      ),
    ),
    archetype: resolvedArchetype,
    appearance: appearance,
  );
}

/// A set of [count] head-coach candidates for the GM to choose between at
/// onboarding, each a different, already-known [CoachArchetype] (a
/// shuffle of [CoachArchetype.values], not [count] independent random
/// rolls, so two candidates never duplicate a philosophy) -- one
/// offense-minded, one defense-minded, one player-development-minded,
/// whatever the shuffle happens to land on, "pull from the archetypes at
/// random" per the GM's own framing. [qualitySpread] defaults tighter
/// than [generateCoach]'s own default so the archetype's philosophy
/// reads clearly rather than getting drowned out by jitter noise --
/// candidates should feel "super comparable, just different goals," not
/// randomly stronger or weaker than each other.
List<Coach> generateCoachCandidates(
  Random random, {
  int count = 3,
  int qualityCenter = 50,
  int qualitySpread = 6,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final archetypes = [...CoachArchetype.values]..shuffle(random);
  return [
    for (final archetype in archetypes.take(count))
      generateCoach(
        random,
        qualityCenter: qualityCenter,
        qualitySpread: qualitySpread,
        archetype: archetype,
        portraitWeights: portraitWeights,
        portraitManifest: portraitManifest,
      ),
  ];
}
