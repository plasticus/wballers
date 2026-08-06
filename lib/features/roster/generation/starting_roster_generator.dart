import 'dart:math';

import '../../player/generation/player_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';
import 'jersey_number_assignment.dart';
import 'roster_position_plan.dart';
import 'trait_distribution.dart';

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
///
/// Traits are assigned team-wide after all 12 players exist, not per
/// player during generation -- see `distributeTraits`. Jersey numbers are
/// assigned the same way, after generation -- see `assignJerseyNumbers`.
List<RosterMembership> generateStartingRoster(
  int seed, {
  PortraitWeights? portraitWeights,
}) {
  final random = Random(seed);

  final roster = [
    for (final position in kTwelvePlayerPositionPlan)
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

  return assignJerseyNumbers(random, distributeTraits(random, roster));
}
