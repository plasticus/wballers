import 'position.dart';

/// Position-specific play-style labels (`archetypes.md`). Distinct from
/// [Trait], which describes psychology/career, not playing style.
///
/// [generateArchetype] still picks the archetype uniformly at random among
/// the options valid for a player's position -- but `generatePlayer` now
/// rolls it *first* and biases [PlayerRatings] generation to actually fit
/// it (`_archetypeBias`, `player_generator.dart`), so a "Sniper" ends up
/// with high perimeter offense instead of the position bias alone
/// deciding everything.
enum Archetype {
  // Point guard
  floorGeneral,
  scoringPoint,
  comboGuard,

  // Shared guard/wing
  scoringSpecialist,
  threeAndD,
  sniper,
  defensiveSpecialist,

  // Shared forward
  versatileForward,
  pointForward,
  reboundKing,
  lowPostMonster,
  stretchFour,

  // Center
  rimRunner,
  shotBlocker,
  stretchFive,
}

extension ArchetypeLabel on Archetype {
  String get label => switch (this) {
    Archetype.floorGeneral => 'Floor General',
    Archetype.scoringPoint => 'Scoring Point',
    Archetype.comboGuard => 'Combo Guard',
    Archetype.scoringSpecialist => 'Scoring Specialist',
    Archetype.threeAndD => '3&D',
    Archetype.sniper => 'Sniper',
    Archetype.defensiveSpecialist => 'Defensive Specialist',
    Archetype.versatileForward => 'Versatile Forward',
    Archetype.pointForward => 'Point Forward',
    Archetype.reboundKing => 'Rebound King',
    Archetype.lowPostMonster => 'Low Post Monster',
    Archetype.stretchFour => 'Stretch-4',
    Archetype.rimRunner => 'Rim Runner',
    Archetype.shotBlocker => 'Shot Blocker',
    Archetype.stretchFive => 'Stretch-5',
  };
}

/// Which archetypes are valid for a given position (`archetypes.md`'s
/// table). Several names repeat across positions (e.g. "3&D" for SG and
/// SF) -- these are the same archetype concept in a different position
/// context, not distinct values.
const Map<Position, List<Archetype>> kArchetypesByPosition = {
  Position.pointGuard: [
    Archetype.floorGeneral,
    Archetype.scoringPoint,
    Archetype.comboGuard,
  ],
  Position.shootingGuard: [
    Archetype.scoringSpecialist,
    Archetype.threeAndD,
    Archetype.sniper,
    Archetype.defensiveSpecialist,
  ],
  Position.smallForward: [
    Archetype.versatileForward,
    Archetype.threeAndD,
    Archetype.sniper,
    Archetype.pointForward,
    Archetype.defensiveSpecialist,
  ],
  Position.powerForward: [
    Archetype.versatileForward,
    Archetype.pointForward,
    Archetype.reboundKing,
    Archetype.defensiveSpecialist,
    Archetype.lowPostMonster,
    Archetype.stretchFour,
  ],
  Position.center: [
    Archetype.rimRunner,
    Archetype.lowPostMonster,
    Archetype.reboundKing,
    Archetype.shotBlocker,
    Archetype.stretchFive,
  ],
};

bool isArchetypeValidForPosition(Archetype archetype, Position position) {
  return kArchetypesByPosition[position]!.contains(archetype);
}
