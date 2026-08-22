import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../player/domain/player.dart';
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
///    before she starts aging down hard -- potential is pinned to exactly
///    her own rolled overall (not a separate jittered value), a same-day
///    tightening once a rolled example showed her a few points under her
///    own potential: "Star Vet needs to be AT her potential... No wiggle
///    room, I don't want anyone to think she should be trained more."
///  - one boom-or-bust 21-year-old, starting in the mid-60s OVR but with
///    a genuine superstar ceiling (95+ potential)
///  - one solid 21-23-year-old, already good today (mid-70s OVR) with a
///    real but non-superstar ceiling (83-87 potential, +/-5 -- widened
///    same-day from +/-2, a GM preference after seeing sample rosters) --
///    worth training, not a franchise cornerstone
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
/// instead of leaving it to chance. [_promoteMissingPositionStarter] (a
/// same-day fix, a real GM report: "I have 2x PFs in the starting 5... if
/// either had been a Center, I would have been okay") makes sure that
/// 5th position is actually filled in the roster's *default bench-order
/// top 5* too, not just present somewhere in the 12-man roster -- indices
/// 0-4 are always exactly one player per standard position out of the
/// box, before the GM ever touches Bench Order.
///
/// The other seven are generic role players, centered so the full
/// 11-player average -- together with the four narrative players above,
/// now stronger than the original three-slot version -- still lands in
/// the same target range as before (`Aug9bugs.md` #11's original ~69
/// target). Center re-tuned twice the same day the 4-slot version shipped:
/// first to 63 to hold the ~69 line against the stronger narrative core,
/// then to 59 once a real sampled sweep showed 63 actually averaging
/// ~71.3, not ~69 -- "I worry I creeped them up a bit" turned out to be
/// right (300-seed sweep: 63->71.3, 61->70.2, 59->69.1 team overall,
/// post-signing). Every generic filler's own potential is also capped
/// now -- see [_genericPotentialCap]'s own doc comment for why.
const _veteranQualityCenter = 95;
const _veteranQualitySpread = 2;
const _veteranMinAge = 33;
const _veteranMaxAge = 34;

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
// A 10-point-wide window (2026-08-14, a GM preference after seeing sample
// rosters: "I think I prefer the 10 point spread for her, wherever her
// numbers land") -- was +/-2, now +/-5.
const _youngsterAPotentialSpread = 5;

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

const _genericQualityCenter = 59;
const _genericQualitySpread = 10;

/// Caps a generic filler's potential regardless of age -- without this, a
/// filler who happens to roll young (`generatePlayer`'s own age-based
/// [_generatePotentialOffset], 8-35 points wide for age <=23) can roll a
/// real prospect-looking gap purely by chance, with no narrative intent
/// behind it. A direct GM report (2026-08-14, a real rolled roster): 3 of
/// 7 generic fillers read as "worth training" alongside the real 3
/// narrative-tier prospects (rookie/young-solid/free agent) -- "I don't
/// want that for the opening season. Too much choice for a head coach to
/// make when they're just learning the game." Same exact numbers
/// `free_agent_pool_generator.dart`'s own `_fillerPotentialCap`/
/// `_fillerPotentialCapSpread` already use for its fillers, for the same
/// reason -- confirmed via sampled rosters this keeps every generic
/// filler's gap-to-potential comfortably below the real narrative-tier
/// prospects', every time.
const _genericPotentialCap = 66;
const _genericPotentialCapSpread = 6;

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

/// Moves whichever of [roster]'s generic fillers (indices 4+) plays
/// [missingStartingPosition]'s position into index 4 -- the better of the
/// two by overall, if both are still generic fillers at this point --
/// completing a real, legal, standard 5-position starting five in the
/// default bench order itself (indices 0-4), not just somewhere in the
/// 12-man roster. A real GM report (2026-08-14): "I have 2x PFs in the
/// starting 5... if either had been a Center, I would have been okay" --
/// the 4 narrative slots already guaranteed 4 distinct positions
/// *exist on the roster*, but nothing previously guaranteed the
/// *default bench order's own top 5* actually included all 5 -- index 4
/// was just whichever generic position happened to shuffle in first,
/// which could easily double up a position the narrative slots already
/// covered while the truly uncovered position sat buried in the bench.
/// Only ever touches index 4 -- indices 0-3 (the narrative slots) are
/// untouched, so [missingStartingPosition]'s own "always indices 0-3"
/// contract still holds after this runs.
List<RosterMembership> _promoteMissingPositionStarter(
  List<RosterMembership> roster,
) {
  final missing = missingStartingPosition(roster);
  final candidateIndices =
      [
        for (var i = 4; i < roster.length; i++)
          if (roster[i].player.primaryPosition == missing) i,
      ]..sort(
        (a, b) => roster[b].player.ratings.overall.compareTo(
          roster[a].player.ratings.overall,
        ),
      );
  final promoteIndex = candidateIndices.first;
  if (promoteIndex == 4) return roster;

  final updated = List<RosterMembership>.of(roster);
  final promoted = updated.removeAt(promoteIndex);
  updated.insert(4, promoted);
  return updated;
}

enum _RatingField {
  speed,
  agility,
  strength,
  stamina,
  ballControl,
  passing,
  interiorOffense,
  perimeterOffense,
  perimeterDefense,
  interiorDefense,
  disruption,
  blocking,
}

/// Tops [player]'s overall back up to [_veteranQualityCenter] whenever it
/// landed below that -- `player_generator.dart`'s per-position rating-bias
/// table hands out deltas as large as +/-12, and [kMaxRating] (99)
/// asymmetrically clamps the upside on a strongly-positive-biased stat
/// (a Center's `strength +12`/`interiorDefense +10`/`blocking +10`, a
/// Point Guard's `ballControl +12`/`passing +12`) far more than the
/// negative-biased stats on the same position ever get clamped at the
/// floor, since 95 minus even the largest negative delta stays nowhere
/// near [kMinRating]. Left alone, that asymmetry regularly landed the
/// star veteran's real overall in the low 90s regardless of
/// [_veteranQualityCenter] itself (2026-08-22, a direct GM report: "so
/// how do I keep getting a 91/92?", confirmed by hand-working a Center
/// roll: 95 + bias clamped per stat averages to 92.17, four different
/// stats losing 2-8 points each to the ceiling with no matching floor
/// relief on the negative side).
///
/// Distributes the shortfall one point at a time onto a random
/// still-under-[kMaxRating] stat -- same mechanic
/// `coach_generator.dart`'s `_distributeStats` already uses for a
/// conceptually identical problem (hit an exact total without any one
/// stat exceeding its own ceiling) -- rather than forcing an exact
/// value on every single roll: a position/archetype combo with a much
/// smaller bias spread (Small Forward's biases are all +/-2) can still
/// clear [_veteranQualityCenter] on its own natural roll and keeps that
/// real number untouched, so she reads at *or above* 95 most of the
/// time rather than *exactly* 95 every time -- "I want to see her at 95
/// most of the time," not a second "no wiggle room" rule layered on top
/// of the one [PlayerRatings.potential] already has just below this.
Player _boostVeteranOverall(Random random, Player player) {
  final ratings = player.ratings;
  if (ratings.overall >= _veteranQualityCenter) return player;

  final values = {
    _RatingField.speed: ratings.speed,
    _RatingField.agility: ratings.agility,
    _RatingField.strength: ratings.strength,
    _RatingField.stamina: ratings.stamina,
    _RatingField.ballControl: ratings.ballControl,
    _RatingField.passing: ratings.passing,
    _RatingField.interiorOffense: ratings.interiorOffense,
    _RatingField.perimeterOffense: ratings.perimeterOffense,
    _RatingField.perimeterDefense: ratings.perimeterDefense,
    _RatingField.interiorDefense: ratings.interiorDefense,
    _RatingField.disruption: ratings.disruption,
    _RatingField.blocking: ratings.blocking,
  };
  final targetSum = _veteranQualityCenter * 12;
  var currentSum = ratings.skillPoints;
  while (currentSum < targetSum) {
    final eligible = [
      for (final field in _RatingField.values)
        if (values[field]! < kMaxRating) field,
    ];
    // Every stat maxed at 99 (skillPoints up to 1188) comfortably above
    // any real targetSum (95 * 12 = 1140) -- never expected to actually
    // run out, but bailing out is still correct over an infinite loop
    // if it somehow ever did.
    if (eligible.isEmpty) break;
    final chosen = eligible[random.nextInt(eligible.length)];
    values[chosen] = values[chosen]! + 1;
    currentSum++;
  }

  return player.copyWithRatings(
    ratings.copyWith(
      speed: values[_RatingField.speed],
      agility: values[_RatingField.agility],
      strength: values[_RatingField.strength],
      stamina: values[_RatingField.stamina],
      ballControl: values[_RatingField.ballControl],
      passing: values[_RatingField.passing],
      interiorOffense: values[_RatingField.interiorOffense],
      perimeterOffense: values[_RatingField.perimeterOffense],
      perimeterDefense: values[_RatingField.perimeterDefense],
      interiorDefense: values[_RatingField.interiorDefense],
      disruption: values[_RatingField.disruption],
      blocking: values[_RatingField.blocking],
    ),
  );
}

/// Generates a new expansion franchise's starting active roster.
/// Deterministic: the same [seed] always produces the same 11 players in
/// the same order (positions are shuffled from the seeded stream, so which
/// position gets which narrative slot varies by franchise too, not just
/// the ratings). [portraitWeights] is optional and threads straight
/// through to `generatePlayer` -- see its doc comment.
///
/// The returned list's first 5 entries -- "the starting five" everywhere
/// else in the game reads bench order (`Franchise`'s own doc comment,
/// `DepthChartScreen`) -- are always one player at each of the 5 standard
/// positions: indices 0-3 are the narrative slots (4 distinct positions,
/// see [_narrativeAndGenericPositions]) and index 4 is
/// [_promoteMissingPositionStarter]'s doing, not chance. A real starting
/// five out of the box, before the GM ever touches Bench Order.
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
    // No potentialOverride here -- her potential is pinned to exactly her
    // own rolled overall right after the roster is built, below.
    build(
      0,
      qualityCenter: _veteranQualityCenter,
      qualitySpread: _veteranQualitySpread,
      minAge: _veteranMinAge,
      maxAge: _veteranMaxAge,
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
        potentialOverride: _genericPotentialCap,
        potentialOverrideSpread: _genericPotentialCapSpread,
      ),
  ];

  // Boosted back up to _veteranQualityCenter first (see
  // _boostVeteranOverall's own doc comment for why her raw roll
  // regularly landed a few points under it), *then* potential is pinned
  // to exactly her own -- now corrected -- overall. `generatePlayer` has
  // no "potential == overall exactly" mode (its own `potentialOverride`
  // always jitters toward a separate target), so the pin is done
  // directly, once, right here rather than by fighting that mechanism
  // into producing a zero gap.
  final vet = _boostVeteranOverall(random, roster[0].player);
  roster[0] = RosterMembership(
    player: vet.copyWithRatings(
      vet.ratings.copyWith(potential: vet.ratings.overall),
    ),
    status: RosterStatus.active,
  );

  final orderedRoster = _promoteMissingPositionStarter(roster);
  return assignJerseyNumbers(random, distributeTraits(random, orderedRoster));
}
