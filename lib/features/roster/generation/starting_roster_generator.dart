import 'dart:math';

import '../../player/domain/position.dart';
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
/// just a lower-quality draw. `generateAiRoster`'s league average now
/// spreads roughly 69-76 (`Aug9bugs.md` #11); this generator targets the
/// high-60s for these 11 alone, landing around 69 once the GM signs the
/// Day-0 free-agent pool's planted "decent" prospect
/// (`free_agent_pool_generator.dart`) to fill the 12th spot -- clearly
/// below the AI average without the 7-9-point gap a direct GM bug report
/// found the previous, lower target produced ("my OVR is 66, and all
/// other teams are 73-75. I'm getting trounced so bad").
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
/// **Four of the eleven slots are hand-placed narrative players** (revised
/// 2026-08-14, a direct GM ask -- "let's redo the rules a bit," replacing
/// the original three-slot version below) rather than drawn from the same
/// flat distribution as the rest of the roster:
///  - one franchise vet, a real star (~95 OVR) with 1-2 seasons left
///    before she starts aging down hard
///  - one boom-or-bust 21-year-old, starting in the mid-60s OVR but with
///    a genuine superstar ceiling (95+ potential)
///  - one solid 21-23-year-old, already good today (mid-70s OVR) with a
///    real but non-superstar ceiling (83-87 potential) -- worth training,
///    not a franchise cornerstone
///  - one second vet, age 26 and already at her ceiling (~80 OVR, no
///    real gap to potential) -- worth starting today, not worth spending
///    training time on
///
/// These 4 are assigned 4 distinct standard positions (randomized per
/// franchise -- see [_narrativeAndGenericPositions]), deliberately leaving
/// exactly one of the 5 standard positions uncovered. [missingStartingPosition]
/// reads that gap back out so `expansion_franchise_factory.dart` can target
/// the Day-0 free agent at it, completing a real starting five spread
/// across all 5 narrative-tier players (the 4 here plus the free agent)
/// instead of leaving it to chance.
///
/// The other seven are generic role players, centered so the full
/// 11-player average -- together with the four narrative players above,
/// now stronger than the original three-slot version -- still lands in
/// the same target range as before (`Aug9bugs.md` #11's original ~69
/// target; center dropped from 65 to 63 on the 2026-08-14 revision to
/// hold that line against the stronger narrative core, tuned empirically
/// same as the original).
const _veteranQualityCenter = 95;
const _veteranQualitySpread = 2;
const _veteranMinAge = 33;
const _veteranMaxAge = 34;
const _veteranPotential = 95;
const _veteranPotentialSpread = 2;

const _prospectQualityCenter = 64;
const _prospectQualitySpread = 3;
const _prospectAge = 21;
const _prospectPotential = 96;
const _prospectPotentialSpread = 2;

const _youngsterAQualityCenter = 75;
const _youngsterAQualitySpread = 3;
const _youngsterAMinAge = 21;
const _youngsterAMaxAge = 23;
const _youngsterAPotential = 85;
const _youngsterAPotentialSpread = 2;

/// The new 4th narrative slot (2026-08-14) -- a second vet already at her
/// ceiling. Potential is centered on the same value as current ability
/// (rather than meaningfully above it, like every other narrative slot)
/// so training her yields next to nothing -- `generatePlayer` still
/// floors potential at whatever overall actually rolls, so she'll always
/// read as at-or-just-above her current level, never below it.
const _primeVetQualityCenter = 80;
const _primeVetQualitySpread = 2;
const _primeVetAge = 26;
const _primeVetPotential = 80;
const _primeVetPotentialSpread = 2;

const _genericQualityCenter = 63;
const _genericQualitySpread = 10;

/// Splits [kElevenPlayerPositionPlan]'s 11 slots into the 4 distinct
/// standard positions the narrative slots occupy (the first 4 entries of
/// the returned list, randomized per franchise) and the 7 remaining slots
/// the generic role players fill (the rest). Whichever of the 5 standard
/// positions doesn't make the narrative-slot cut is deliberately left
/// generic-only -- see [missingStartingPosition], which reads that gap
/// back out for the Day-0 free agent to target.
List<Position> _narrativeAndGenericPositions(Random random) {
  final narrativeFour = (List.of(
    Position.values,
  )..shuffle(random)).sublist(0, 4);

  // `List.remove` drops only the first match, exactly what's needed here
  // -- one plan slot per narrative position claimed, leaving the rest
  // (including every slot of the one position none of the 4 claimed).
  final genericPositions = List.of(kElevenPlayerPositionPlan);
  for (final position in narrativeFour) {
    genericPositions.remove(position);
  }
  genericPositions.shuffle(random);

  return [...narrativeFour, ...genericPositions];
}

/// The one standard position none of the 4 narrative players occupies --
/// always roster indices 0-3, per [generateStartingRoster]'s own doc
/// comment and [_narrativeAndGenericPositions]. A direct GM ask
/// (2026-08-14): the Day-0 free agent should be generated to specifically
/// fill this position, so she completes a real starting five alongside
/// the 4 narrative slots instead of landing wherever chance puts her.
/// `expansion_franchise_factory.dart` reads this and threads it into
/// `generateFreeAgentPool`.
Position missingStartingPosition(List<RosterMembership> roster) {
  final narrativePositions = roster
      .take(4)
      .map((membership) => membership.player.primaryPosition)
      .toSet();
  return Position.values.firstWhere(
    (position) => !narrativePositions.contains(position),
  );
}

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
  final positions = _narrativeAndGenericPositions(random);

  // Every surname already placed on this roster so far -- threaded into
  // each [generatePlayer] call below so it rerolls away from a repeat
  // (2026-08-11, TODO.md: "no duplicate surnames allowed on a single
  // team").
  final usedSurnames = <String>{};

  RosterMembership build(
    int index, {
    required int qualityCenter,
    required int qualitySpread,
    int minAge = 20,
    int maxAge = 34,
    int? potentialOverride,
    int potentialOverrideSpread = 3,
  }) {
    final player = generatePlayer(
      random,
      primaryPosition: positions[index],
      qualityCenter: qualityCenter,
      qualitySpread: qualitySpread,
      minAge: minAge,
      maxAge: maxAge,
      potentialOverride: potentialOverride,
      potentialOverrideSpread: potentialOverrideSpread,
      portraitWeights: portraitWeights,
      excludeSurnames: usedSurnames,
    );
    usedSurnames.add(player.name.split(' ').skip(1).join(' '));
    return RosterMembership(player: player, status: RosterStatus.active);
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
    build(
      3,
      qualityCenter: _primeVetQualityCenter,
      qualitySpread: _primeVetQualitySpread,
      minAge: _primeVetAge,
      maxAge: _primeVetAge,
      potentialOverride: _primeVetPotential,
      potentialOverrideSpread: _primeVetPotentialSpread,
    ),
    for (var i = 4; i < positions.length; i++)
      build(
        i,
        qualityCenter: _genericQualityCenter,
        qualitySpread: _genericQualitySpread,
      ),
  ];

  return assignJerseyNumbers(random, distributeTraits(random, roster));
}
