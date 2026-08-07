import 'dart:math';

import '../../player/generation/player_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';
import 'jersey_number_assignment.dart';
import 'roster_position_plan.dart';
import 'trait_distribution.dart';

/// A new expansion franchise's roster should sit on the lower end of the
/// league (`0B_Planned.md`'s team-overall-rebalance entry: "I don't want
/// them winning the championship in year 1!") while still respecting the
/// same star-tier caps every other roster does -- no special exemption,
/// just a lower-quality draw. `generateAiRoster`'s league average lands in
/// the low-to-mid 70s; this generator targets the mid-to-high 60s, clearly
/// below it, without ever exceeding the caps.
///
/// **11 players, not 12** (changed 2026-08-07) -- a direct GM ask for a
/// real Day-0 hook: the roster starts one player short of
/// [kActiveRosterSize] on purpose, and the GM has to sign a free agent
/// (an Assistant GM mail nudges toward doing exactly that,
/// `dashboard/dashboard_screen.dart`) before the season can advance at
/// all. `kElevenPlayerPositionPlan` (not the shared 12-player plan every
/// AI roster still uses) keeps every position at 2+ players even with the
/// gap.
///
/// Three of the eleven slots are hand-placed narrative players rather than
/// drawn from the same flat distribution as the rest of the roster --
/// the GM's own request was for "valuable pieces to train" and "bargaining
/// chips," not just eleven interchangeable unknowns:
///  - one grizzled vet, already near her ceiling and about to age out
///  - one boom-or-bust 21-year-old, a real potential superstar buried on
///    the bench today
///  - one more promising youngster a tier below the boom-or-bust pick
///    (a second one at this tier was cut when the roster dropped from 12
///    to 11 -- "I had you making 2 with potential in the 80s -- drop one
///    of those")
///
/// The other eight are generic role players, centered low enough that the
/// full 11-player average lands in the target range even after the three
/// narrative players (who skew the mean upward) are added in.
const _veteranQualityCenter = 87;
const _veteranQualitySpread = 3;
const _veteranMinAge = 33;
const _veteranMaxAge = 34;
const _veteranPotential = 88;
const _veteranPotentialSpread = 2;

const _prospectQualityCenter = 70;
const _prospectQualitySpread = 3;
const _prospectAge = 21;
const _prospectPotential = 92;
const _prospectPotentialSpread = 2;

const _youngsterAQualityCenter = 63;
const _youngsterAQualitySpread = 4;
const _youngsterAMinAge = 21;
const _youngsterAMaxAge = 23;
const _youngsterAPotential = 83;
const _youngsterAPotentialSpread = 3;

const _genericQualityCenter = 62;
const _genericQualitySpread = 12;

/// Generates a new expansion franchise's starting active roster.
/// Deterministic: the same [seed] always produces the same 11 players in
/// the same order (positions are shuffled from the seeded stream, so which
/// position gets which narrative slot varies by franchise too, not just
/// the ratings). [portraitWeights] is optional and threads straight
/// through to `generatePlayer` -- see its doc comment.
///
/// Traits are assigned team-wide after all 11 players exist, not per
/// player during generation -- see `distributeTraits`. Jersey numbers are
/// assigned the same way, after generation -- see `assignJerseyNumbers`.
List<RosterMembership> generateStartingRoster(
  int seed, {
  PortraitWeights? portraitWeights,
}) {
  final random = Random(seed);
  final positions = List.of(kElevenPlayerPositionPlan)..shuffle(random);

  RosterMembership build(
    int index, {
    required int qualityCenter,
    required int qualitySpread,
    int minAge = 20,
    int maxAge = 34,
    int? potentialOverride,
    int potentialOverrideSpread = 3,
  }) {
    return RosterMembership(
      player: generatePlayer(
        random,
        primaryPosition: positions[index],
        qualityCenter: qualityCenter,
        qualitySpread: qualitySpread,
        minAge: minAge,
        maxAge: maxAge,
        potentialOverride: potentialOverride,
        potentialOverrideSpread: potentialOverrideSpread,
        portraitWeights: portraitWeights,
      ),
      status: RosterStatus.active,
    );
  }

  final roster = <RosterMembership>[
    build(
      0,
      qualityCenter: _veteranQualityCenter,
      qualitySpread: _veteranQualitySpread,
      minAge: _veteranMinAge,
      maxAge: _veteranMaxAge,
      potentialOverride: _veteranPotential,
      potentialOverrideSpread: _veteranPotentialSpread,
    ),
    build(
      1,
      qualityCenter: _prospectQualityCenter,
      qualitySpread: _prospectQualitySpread,
      minAge: _prospectAge,
      maxAge: _prospectAge,
      potentialOverride: _prospectPotential,
      potentialOverrideSpread: _prospectPotentialSpread,
    ),
    build(
      2,
      qualityCenter: _youngsterAQualityCenter,
      qualitySpread: _youngsterAQualitySpread,
      minAge: _youngsterAMinAge,
      maxAge: _youngsterAMaxAge,
      potentialOverride: _youngsterAPotential,
      potentialOverrideSpread: _youngsterAPotentialSpread,
    ),
    for (var i = 3; i < positions.length; i++)
      build(
        i,
        qualityCenter: _genericQualityCenter,
        qualitySpread: _genericQualitySpread,
      ),
  ];

  return assignJerseyNumbers(random, distributeTraits(random, roster));
}
