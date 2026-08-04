import 'dart:math';

import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';

/// Positions for a new expansion franchise's 12-player active roster.
/// Guarantees at least two players at every position so a legal starting
/// five and bench can always be fielded; guards and forwards get a third
/// body since those rotations run deepest in practice.
const _startingRosterPositionPlan = <Position>[
  Position.pointGuard,
  Position.pointGuard,
  Position.shootingGuard,
  Position.shootingGuard,
  Position.shootingGuard,
  Position.smallForward,
  Position.smallForward,
  Position.smallForward,
  Position.powerForward,
  Position.powerForward,
  Position.center,
  Position.center,
];

/// A new expansion franchise's roster should be weak — below the four-star
/// threshold (see `star_system.md`) — and, per the Phase 1 plan,
/// "meaningfully different" between franchises. Centering generation well
/// below that threshold with a wide spread satisfies both: every player
/// here should land as three-star-or-below, but where in that range varies
/// by seed.
const _startingRosterQualityCenter = 48;
const _startingRosterQualitySpread = 14;

/// Generates a new expansion franchise's starting active roster.
/// Deterministic: the same [seed] always produces the same 12 players in
/// the same order. [portraitWeights] is optional and threads straight
/// through to `generatePlayer` -- see its doc comment.
List<RosterMembership> generateStartingRoster(
  int seed, {
  PortraitWeights? portraitWeights,
}) {
  final random = Random(seed);

  return [
    for (final position in _startingRosterPositionPlan)
      RosterMembership(
        player: generatePlayer(
          random,
          primaryPosition: position,
          qualityCenter: _startingRosterQualityCenter,
          qualitySpread: _startingRosterQualitySpread,
          portraitWeights: portraitWeights,
        ),
        status: RosterStatus.active,
      ),
  ];
}
