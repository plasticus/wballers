import 'dart:math';

import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';
import 'roster_position_plan.dart';

/// Target composition for a freshly generated AI team (`0B_Planned.md`):
/// exactly one 5-star player, leaning veteran, plus three 4-star players
/// with a young/mid/old age spread -- four four-star-or-better total,
/// comfortably inside `star_system.md`'s caps (<=2 five-star, <=6
/// four-star-or-better combined). The other eight are role players,
/// centered well below the four-star threshold so the roster still reads
/// as a real team with a top-heavy shape, not 12 similar bodies.
const _starQualityCenter = 94;
const _starQualitySpread = 3;
const _starMinAge = 29;
const _starMaxAge = 34;

const _quarterStarQualityCenter = 83;
const _quarterStarQualitySpread = 5;

/// (minAge, maxAge) for the three 4-star slots, in order: young, mid-career,
/// veteran -- "a mixed young/mid/old spread" rather than three same-aged
/// players.
const _quarterStarAgeRanges = <(int, int)>[(20, 24), (25, 29), (30, 34)];

const _roleQualityCenter = 54;
const _roleQualitySpread = 10;

/// Generates one AI-controlled team's 12-player active roster. Deterministic
/// for a given [random] stream, same contract as `generateStartingRoster`
/// -- pass the same stream across multiple teams to generate a whole
/// league's rosters from one seed.
///
/// Positions are drawn from `kTwelvePlayerPositionPlan`, shuffled first so
/// which position ends up with the star/quality slots varies -- otherwise
/// every AI team's best player would always play the same position.
List<RosterMembership> generateAiRoster(
  Random random, {
  PortraitWeights? portraitWeights,
}) {
  final positions = List<Position>.of(kTwelvePlayerPositionPlan)
    ..shuffle(random);

  RosterMembership build(
    Position position, {
    required int qualityCenter,
    required int qualitySpread,
    required int minAge,
    required int maxAge,
  }) {
    return RosterMembership(
      player: generatePlayer(
        random,
        primaryPosition: position,
        qualityCenter: qualityCenter,
        qualitySpread: qualitySpread,
        minAge: minAge,
        maxAge: maxAge,
        portraitWeights: portraitWeights,
      ),
      status: RosterStatus.active,
    );
  }

  final roster = <RosterMembership>[
    build(
      positions[0],
      qualityCenter: _starQualityCenter,
      qualitySpread: _starQualitySpread,
      minAge: _starMinAge,
      maxAge: _starMaxAge,
    ),
  ];

  for (var i = 0; i < _quarterStarAgeRanges.length; i++) {
    final (minAge, maxAge) = _quarterStarAgeRanges[i];
    roster.add(
      build(
        positions[1 + i],
        qualityCenter: _quarterStarQualityCenter,
        qualitySpread: _quarterStarQualitySpread,
        minAge: minAge,
        maxAge: maxAge,
      ),
    );
  }

  for (var i = 1 + _quarterStarAgeRanges.length; i < positions.length; i++) {
    roster.add(
      build(
        positions[i],
        qualityCenter: _roleQualityCenter,
        qualitySpread: _roleQualitySpread,
        minAge: 20,
        maxAge: 34,
      ),
    );
  }

  return roster;
}
