import 'dart:math';

import '../../../core/generation/name_pools.dart';
import '../../../core/ratings/rating_scale.dart';
import '../../portrait/domain/portrait_height_tier.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/generation/portrait_generator.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import 'archetype_generator.dart';
import 'player_generator_data.dart';

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

/// Rating adjustments layered on top of the position bias once an
/// archetype is picked, so a "Sniper" actually ends up with high
/// perimeter offense instead of the position bias alone deciding
/// everything -- `archetypes.md`'s previously-open rating-correlation
/// item. Smaller magnitudes than the position table since these are
/// fine-tuning on top of an already-plausible position baseline, not a
/// second full personality.
const Map<Archetype, _RatingDeltas> _archetypeBias = {
  // Point guard
  Archetype.floorGeneral: (
    speed: 0,
    agility: 0,
    strength: 0,
    stamina: 0,
    ballControl: 8,
    passing: 12,
    interiorOffense: 0,
    perimeterOffense: -2,
    perimeterDefense: 2,
    interiorDefense: 0,
    disruption: 2,
    blocking: 0,
  ),
  Archetype.scoringPoint: (
    speed: 0,
    agility: 2,
    strength: 0,
    stamina: 0,
    ballControl: 4,
    passing: -4,
    interiorOffense: 2,
    perimeterOffense: 12,
    perimeterDefense: -2,
    interiorDefense: 0,
    disruption: 0,
    blocking: 0,
  ),
  Archetype.comboGuard: (
    speed: 2,
    agility: 2,
    strength: 0,
    stamina: 0,
    ballControl: 6,
    passing: 4,
    interiorOffense: 0,
    perimeterOffense: 6,
    perimeterDefense: 4,
    interiorDefense: 0,
    disruption: 2,
    blocking: 0,
  ),

  // Shared guard/wing
  Archetype.scoringSpecialist: (
    speed: 0,
    agility: 2,
    strength: 0,
    stamina: 0,
    ballControl: 2,
    passing: -4,
    interiorOffense: 4,
    perimeterOffense: 12,
    perimeterDefense: -4,
    interiorDefense: 0,
    disruption: -2,
    blocking: 0,
  ),
  Archetype.threeAndD: (
    speed: 0,
    agility: 0,
    strength: 0,
    stamina: 0,
    ballControl: 0,
    passing: 0,
    interiorOffense: 0,
    perimeterOffense: 8,
    perimeterDefense: 10,
    interiorDefense: 2,
    disruption: 4,
    blocking: 0,
  ),
  Archetype.sniper: (
    speed: -2,
    agility: 0,
    strength: -2,
    stamina: 0,
    ballControl: 0,
    passing: 0,
    interiorOffense: -2,
    perimeterOffense: 16,
    perimeterDefense: -4,
    interiorDefense: -2,
    disruption: -2,
    blocking: -2,
  ),
  Archetype.defensiveSpecialist: (
    speed: 2,
    agility: 2,
    strength: 2,
    stamina: 0,
    ballControl: -2,
    passing: 0,
    interiorOffense: -4,
    perimeterOffense: -6,
    perimeterDefense: 10,
    interiorDefense: 8,
    disruption: 10,
    blocking: 4,
  ),

  // Shared forward
  Archetype.versatileForward: (
    speed: 0,
    agility: 0,
    strength: 0,
    stamina: 2,
    ballControl: 4,
    passing: 4,
    interiorOffense: 2,
    perimeterOffense: 4,
    perimeterDefense: 2,
    interiorDefense: 2,
    disruption: 0,
    blocking: 0,
  ),
  Archetype.pointForward: (
    speed: 0,
    agility: 0,
    strength: 0,
    stamina: 0,
    ballControl: 8,
    passing: 12,
    interiorOffense: -2,
    perimeterOffense: 0,
    perimeterDefense: 2,
    interiorDefense: -2,
    disruption: 2,
    blocking: -2,
  ),
  Archetype.reboundKing: (
    speed: -2,
    agility: -2,
    strength: 10,
    stamina: 0,
    ballControl: -4,
    passing: -4,
    interiorOffense: 6,
    perimeterOffense: -6,
    perimeterDefense: -2,
    interiorDefense: 8,
    disruption: -2,
    blocking: 4,
  ),
  Archetype.lowPostMonster: (
    speed: -4,
    agility: -4,
    strength: 10,
    stamina: 0,
    ballControl: -4,
    passing: -4,
    interiorOffense: 16,
    perimeterOffense: -10,
    perimeterDefense: -4,
    interiorDefense: 4,
    disruption: -2,
    blocking: 2,
  ),
  Archetype.stretchFour: (
    speed: 0,
    agility: 0,
    strength: -2,
    stamina: 0,
    ballControl: 2,
    passing: 0,
    interiorOffense: -6,
    perimeterOffense: 14,
    perimeterDefense: 0,
    interiorDefense: -4,
    disruption: -2,
    blocking: -2,
  ),

  // Center
  Archetype.rimRunner: (
    speed: 4,
    agility: 4,
    strength: 2,
    stamina: 2,
    ballControl: 0,
    passing: 0,
    interiorOffense: 10,
    perimeterOffense: -4,
    perimeterDefense: -2,
    interiorDefense: 2,
    disruption: 0,
    blocking: 2,
  ),
  Archetype.shotBlocker: (
    speed: -2,
    agility: -2,
    strength: 4,
    stamina: 0,
    ballControl: -2,
    passing: -2,
    interiorOffense: -2,
    perimeterOffense: -6,
    perimeterDefense: 0,
    interiorDefense: 8,
    disruption: 4,
    blocking: 16,
  ),
  Archetype.stretchFive: (
    speed: -2,
    agility: -2,
    strength: -2,
    stamina: 0,
    ballControl: 2,
    passing: 0,
    interiorOffense: -8,
    perimeterOffense: 16,
    perimeterDefense: -2,
    interiorDefense: -4,
    disruption: -2,
    blocking: -4,
  ),
};

_RatingDeltas _combineDeltas(_RatingDeltas a, _RatingDeltas b) {
  return (
    speed: a.speed + b.speed,
    agility: a.agility + b.agility,
    strength: a.strength + b.strength,
    stamina: a.stamina + b.stamina,
    ballControl: a.ballControl + b.ballControl,
    passing: a.passing + b.passing,
    interiorOffense: a.interiorOffense + b.interiorOffense,
    perimeterOffense: a.perimeterOffense + b.perimeterOffense,
    perimeterDefense: a.perimeterDefense + b.perimeterDefense,
    interiorDefense: a.interiorDefense + b.interiorDefense,
    disruption: a.disruption + b.disruption,
    blocking: a.blocking + b.blocking,
  );
}

int _generateStat(Random random, int qualityCenter, int spread, int bias) {
  final jitter = random.nextInt(spread * 2 + 1) - spread;
  return (qualityCenter + bias + jitter).clamp(kMinRating, kMaxRating);
}

/// How far a freshly generated player's [PlayerRatings.potential] sits
/// above their just-generated [overall] -- never below it. A brand-new,
/// never-trained player hasn't had the chance to close any gap to their
/// ceiling yet, so potential starting under current ability reads as a
/// generation bug, not a real player (a real GM complaint this was fixed
/// in response to: a 22-year-old with OVR 52 and potential 40). Banded by
/// [age], mirroring the age curve `features/training/`'s growth engine
/// already uses (fastest growth 20-23, tapering through 26-27, plateau
/// 27-29, decline from 30) -- a young player has a wide-open gap to grow
/// into, a veteran has little to none left, but even a veteran's
/// potential still starts at or above their current overall. `runTraining`
/// is the only place potential ever moves after this, and even then only
/// rarely (trades, minutes trends, earned identity) -- this is strictly
/// the at-generation starting gap.
int _generatePotentialOffset(Random random, int age) {
  final (min, max) = switch (age) {
    <= 23 => (8, 35),
    <= 26 => (4, 22),
    <= 29 => (0, 12),
    _ => (0, 6),
  };
  return min + random.nextInt(max - min + 1);
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
/// The archetype is rolled *first*, before ratings -- `archetype.dart`'s
/// previously-open item. [qualityCenter] is roughly where this player's
/// current-ability stats will cluster before per-stat jitter, positional
/// bias, and the chosen archetype's bias (`_archetypeBias`) are applied;
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
///
/// [yearsOfService] defaults to `null`, meaning "derive it from a randomly
/// rolled debut age" (19-28, covering late debuts) -- the normal behavior
/// for filling out an existing roster. Pass `0` explicitly for a freshly
/// drafted prospect, who by definition hasn't played professionally yet
/// regardless of what a random debut age would otherwise imply
/// (`draft_generator.dart`).
///
/// [potentialOverride] skips [_generatePotentialOffset] entirely and
/// instead jitters potential around that exact value (spread
/// [potentialOverrideSpread]), still floored at [overall] just like the
/// normal path -- a hand-placed narrative player can have her potential
/// pinned tight to a specific story beat (a vet's upper-80s peak, a
/// prospect's 90s ceiling) without reopening the potential-below-overall
/// bug this same file fixed for the general population
/// (`starting_roster_generator.dart`).
Player generatePlayer(
  Random random, {
  required Position primaryPosition,
  int qualityCenter = 50,
  int qualitySpread = 12,
  int? yearsOfService,
  int minAge = 20,
  int maxAge = 34,
  int? potentialOverride,
  int potentialOverrideSpread = 3,
  PortraitWeights? portraitWeights,
}) {
  final archetype = generateArchetype(random, primaryPosition);
  final positionBias = _positionBias[primaryPosition] ?? _zeroDeltas;
  final archetypeBias = _archetypeBias[archetype] ?? _zeroDeltas;
  final bias = _combineDeltas(positionBias, archetypeBias);

  // Rolled before the ratings themselves -- [_generatePotentialOffset]
  // needs it, and nothing about ratings generation depends on age.
  final age = minAge + random.nextInt(maxAge - minAge + 1);
  // Only roll a debut age (and consume a random draw for it) when the
  // caller didn't already pin yearsOfService.
  final resolvedYearsOfService =
      yearsOfService ?? max(0, age - (19 + random.nextInt(10)));

  final speed = _generateStat(random, qualityCenter, qualitySpread, bias.speed);
  final agility = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.agility,
  );
  final strength = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.strength,
  );
  final stamina = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.stamina,
  );
  final ballControl = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.ballControl,
  );
  final passing = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.passing,
  );
  final interiorOffense = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.interiorOffense,
  );
  final perimeterOffense = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.perimeterOffense,
  );
  final perimeterDefense = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.perimeterDefense,
  );
  final interiorDefense = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.interiorDefense,
  );
  final disruption = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.disruption,
  );
  final blocking = _generateStat(
    random,
    qualityCenter,
    qualitySpread,
    bias.blocking,
  );

  // Same unweighted-average formula as `PlayerRatings.overall` -- computed
  // here, ahead of time, because potential is generated *relative to* it
  // (see `_generatePotentialOffset`), not independently.
  final overall =
      ((speed +
                  agility +
                  strength +
                  stamina +
                  ballControl +
                  passing +
                  interiorOffense +
                  perimeterOffense +
                  perimeterDefense +
                  interiorDefense +
                  disruption +
                  blocking) /
              12)
          .round();
  final potential = potentialOverride != null
      ? max(
          overall,
          _generateStat(random, potentialOverride, potentialOverrideSpread, 0),
        )
      : (overall + _generatePotentialOffset(random, age)).clamp(
          kMinRating,
          kMaxRating,
        );

  final ratings = PlayerRatings(
    speed: speed,
    agility: agility,
    strength: strength,
    stamina: stamina,
    ballControl: ballControl,
    passing: passing,
    interiorOffense: interiorOffense,
    perimeterOffense: perimeterOffense,
    perimeterDefense: perimeterDefense,
    interiorDefense: interiorDefense,
    disruption: disruption,
    blocking: blocking,
    potential: potential,
  );

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
    yearsOfService: resolvedYearsOfService,
    hometown: hometown,
    primaryPosition: primaryPosition,
    handedness: handedness,
    biography: '$hometown-born ${_positionLabel(primaryPosition)}.',
    ratings: ratings,
    heightInches: heightInches,
    archetype: archetype,
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
