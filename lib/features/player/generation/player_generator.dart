import 'dart:math';

import '../../../core/generation/name_pools.dart';
import '../../../core/ratings/rating_scale.dart';
import '../../portrait/domain/portrait_height_tier.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/generation/portrait_generator.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import 'archetype_generator.dart';
import 'player_generator_data.dart';
import 'trait_generator.dart';

/// Per-position rating adjustments, layered on top of a random base value
/// before clamping to the 1-99 scale. Reflects standard basketball
/// archetypes (point guards handle/pass, centers protect the rim) so
/// generated rosters read as basketball players, not identical clones with
/// a label attached. Zero for stats a position has no particular lean on.
typedef _RatingDeltas = ({
  int speed,
  int agility,
  int strength,
  int stamina,
  int ballControl,
  int passing,
  int interiorOffense,
  int perimeterOffense,
  int perimeterDefense,
  int interiorDefense,
  int disruption,
  int blocking,
});

const _zeroDeltas = (
  speed: 0,
  agility: 0,
  strength: 0,
  stamina: 0,
  ballControl: 0,
  passing: 0,
  interiorOffense: 0,
  perimeterOffense: 0,
  perimeterDefense: 0,
  interiorDefense: 0,
  disruption: 0,
  blocking: 0,
);

const Map<Position, _RatingDeltas> _positionBias = {
  Position.pointGuard: (
    speed: 8,
    agility: 6,
    strength: -10,
    stamina: 2,
    ballControl: 12,
    passing: 12,
    interiorOffense: -6,
    perimeterOffense: 2,
    perimeterDefense: 2,
    interiorDefense: -6,
    disruption: 4,
    blocking: -8,
  ),
  Position.shootingGuard: (
    speed: 4,
    agility: 6,
    strength: -4,
    stamina: 0,
    ballControl: 4,
    passing: 0,
    interiorOffense: -2,
    perimeterOffense: 10,
    perimeterDefense: 4,
    interiorDefense: -4,
    disruption: 2,
    blocking: -6,
  ),
  Position.smallForward: (
    speed: 2,
    agility: 2,
    strength: 0,
    stamina: 2,
    ballControl: 0,
    passing: 0,
    interiorOffense: 2,
    perimeterOffense: 2,
    perimeterDefense: 2,
    interiorDefense: 2,
    disruption: 0,
    blocking: 0,
  ),
  Position.powerForward: (
    speed: -4,
    agility: -2,
    strength: 8,
    stamina: 0,
    ballControl: -4,
    passing: -2,
    interiorOffense: 4,
    perimeterOffense: -6,
    perimeterDefense: -2,
    interiorDefense: 8,
    disruption: -2,
    blocking: 6,
  ),
  Position.center: (
    speed: -8,
    agility: -6,
    strength: 12,
    stamina: -2,
    ballControl: -8,
    passing: -4,
    interiorOffense: 6,
    perimeterOffense: -12,
    perimeterDefense: -6,
    interiorDefense: 10,
    disruption: -4,
    blocking: 10,
  ),
};

int _generateStat(Random random, int qualityCenter, int spread, int bias) {
  final jitter = random.nextInt(spread * 2 + 1) - spread;
  return (qualityCenter + bias + jitter).clamp(kMinRating, kMaxRating);
}

/// Per-position height centers in inches, roughly following real
/// professional women's basketball height distributions. [_generateHeight]
/// jitters around these by [_heightJitterInches], so a generated player's
/// actual height can meaningfully deviate from their position's norm (a
/// tall point guard, a shorter center) rather than being implied by
/// position alone.
const Map<Position, int> _heightCenterInches = {
  Position.pointGuard: 70, // 5'10"
  Position.shootingGuard: 71, // 5'11"
  Position.smallForward: 73, // 6'1"
  Position.powerForward: 75, // 6'3"
  Position.center: 77, // 6'5"
};
const _heightJitterInches = 4;

int _generateHeight(Random random, Position position) {
  final center = _heightCenterInches[position]!;
  final jitter =
      random.nextInt(_heightJitterInches * 2 + 1) - _heightJitterInches;
  return (center + jitter).clamp(kMinHeightInches, kMaxHeightInches);
}

/// Generates one fictional player. Deterministic for a given [random]
/// stream — the same seeded [Random], called in the same order, always
/// produces the same player.
///
/// [qualityCenter] is roughly where this player's current-ability stats
/// will cluster before per-stat jitter and positional bias are applied;
/// [qualitySpread] controls how much a single stat can wander from that
/// center. [potential] gets its own wider, upward-skewed jitter so even a
/// generated player with modest current ability can turn out to be a
/// hidden gem.
///
/// [portraitWeights] is optional -- when omitted, [Player.appearance] stays
/// `null` and no random numbers are consumed for it, so existing callers
/// and their determinism tests are unaffected. Pass it (loaded from the
/// bundled `weights.json` via `portraitWeightsProvider`) to also generate a
/// portrait.
///
/// [minAge]/[maxAge] default to the full 20-34 range; a caller building a
/// deliberately young, mid-career, or veteran player (e.g. league-wide AI
/// roster generation) can narrow them.
Player generatePlayer(
  Random random, {
  required Position primaryPosition,
  int qualityCenter = 50,
  int qualitySpread = 12,
  int minAge = 20,
  int maxAge = 34,
  PortraitWeights? portraitWeights,
}) {
  final bias = _positionBias[primaryPosition] ?? _zeroDeltas;

  final ratings = PlayerRatings(
    speed: _generateStat(random, qualityCenter, qualitySpread, bias.speed),
    agility: _generateStat(random, qualityCenter, qualitySpread, bias.agility),
    strength: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.strength,
    ),
    stamina: _generateStat(random, qualityCenter, qualitySpread, bias.stamina),
    ballControl: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.ballControl,
    ),
    passing: _generateStat(random, qualityCenter, qualitySpread, bias.passing),
    interiorOffense: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.interiorOffense,
    ),
    perimeterOffense: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.perimeterOffense,
    ),
    perimeterDefense: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.perimeterDefense,
    ),
    interiorDefense: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.interiorDefense,
    ),
    disruption: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.disruption,
    ),
    blocking: _generateStat(
      random,
      qualityCenter,
      qualitySpread,
      bias.blocking,
    ),
    // Wider and skewed upward: a player's ceiling should lean above their
    // current ability more often than below it.
    potential: _generateStat(random, qualityCenter + 10, qualitySpread + 10, 0),
  );

  final age = minAge + random.nextInt(maxAge - minAge + 1);
  final debutAge = 19 + random.nextInt(10); // 19-28, covers late debuts
  final yearsOfService = max(0, age - debutAge);

  final handedness = random.nextDouble() < 0.85
      ? Handedness.right
      : Handedness.left;

  final firstName = kFirstNames[random.nextInt(kFirstNames.length)];
  final lastName = kLastNames[random.nextInt(kLastNames.length)];
  final hometown = kHometowns[random.nextInt(kHometowns.length)];
  // Practically-unique within one franchise's roster, not globally --
  // that's all a lineup slot reference needs.
  final id = random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

  final heightInches = _generateHeight(random, primaryPosition);
  final archetype = generateArchetype(random, primaryPosition);
  final traits = generateTraits(random);
  final appearance = portraitWeights == null
      ? null
      : generatePortraitAppearance(
          random,
          isCoach: false,
          weights: portraitWeights,
          heightTier: portraitHeightTierForInches(heightInches),
        );

  return Player(
    id: id,
    name: '$firstName $lastName',
    age: age,
    yearsOfService: yearsOfService,
    hometown: hometown,
    primaryPosition: primaryPosition,
    handedness: handedness,
    biography: '$hometown-born ${_positionLabel(primaryPosition)}.',
    ratings: ratings,
    heightInches: heightInches,
    archetype: archetype,
    traits: traits,
    appearance: appearance,
  );
}

String _positionLabel(Position position) {
  return switch (position) {
    Position.pointGuard => 'point guard',
    Position.shootingGuard => 'shooting guard',
    Position.smallForward => 'small forward',
    Position.powerForward => 'power forward',
    Position.center => 'center',
  };
}
