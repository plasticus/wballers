import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../player/generation/trait_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../season/domain/standings_entry.dart';
import '../domain/draft_pick.dart';
import '../domain/draft_prospect.dart';

/// Real WNBA draft length: every team picks once per round.
const kDraftRounds = 3;

/// How many teams make the postseason (and so skip the lottery, drafting
/// in reverse standings order instead) -- matches
/// `postseason_generator.dart`'s `kPostseasonTeamCount`, duplicated here
/// rather than imported to keep this module's only real dependency on the
/// season-simulation layer being [StandingsEntry] itself.
const _playoffTeamCount = 8;

const _minProspectAge = 20;
const _maxProspectAge = 23;

/// Draft-class talent shape (2026-08-12, a direct GM redesign): potential
/// is now drawn *directly* per tier, not derived from a generated overall
/// via [_generatePotentialOffset] the way every other generated player
/// still is -- the old "quality center + a wide offset, clamped to 99"
/// approach meant a genuinely elite prospect's potential clamped to
/// exactly 99 something like 60% of the time (confirmed against real
/// generated data), which read as too lumpy, not like a real spread of
/// outcomes. Two tiers only:
///
///  - **Elite** ([_minEliteCount]-[_maxEliteCount] prospects, potential
///    uniform across [_eliteMinPotential]-[_eliteMaxPotential]) -- a true
///    star-caliber prospect, no clamping-driven pileup at the ceiling.
///  - **Everyone else** -- a single smooth taper from [_taperMinPotential]
///    up to [_taperMaxPotential], leaning [_taperWeightRatio] times more
///    common at the bottom than the top. Nobody generates below
///    [_taperMinPotential] at all -- a direct GM call: "those players are
///    going off to their non-BBall careers," i.e. they're simply not part
///    of the draft-eligible pool, not a separate deep-fringe tier.
///
/// [_potentialToOverallRatioMin]/[_potentialToOverallRatioMax] then derive
/// each prospect's actual draft-day overall from her potential (not the
/// other way around), so a higher-potential prospect also reads as
/// meaningfully better *right now*, not just a random roll with a big
/// ceiling attached -- a real gap in the old system, caught by
/// hand-simulating a sample class before this landed.
const _minEliteCount = 5;
const _maxEliteCount = 7;
const _eliteMinPotential = 90;
const _eliteMaxPotential = 99;
const _taperMinPotential = 70;
const _taperMaxPotential = 89;
// A gentle lean, not a steep one -- an earlier version weighted the taper
// all the way down to 0 at the top (~20x more common at 70 than 89) and
// left the 85-89 band with essentially 1 prospect a class in a hand-run
// sample, which read as too sparse. 2x keeps every band genuinely
// present while still favoring the low end, matching real draft-class
// scarcity.
const _taperWeightRatio = 2.0;
const _potentialToOverallRatioMin = 0.72;
const _potentialToOverallRatioMax = 0.88;
const _prospectQualitySpread = 8; // per-field jitter width once the
// target overall (potential x ratio) is picked -- tier no longer implies
// a different spread, now that tier only sets potential.

/// Default draft class size -- comfortably more than the 60 picks a
/// 20-team, 3-round draft needs (see [kDraftRounds]), so not every
/// prospect gets drafted, same as real life.
const kDefaultDraftClassSize = 80;

/// Seed offset for a re-derived, not-yet-real "what pick would I have"
/// projection off a completed season's final standings
/// (`SeasonRecapScreen`, 2026-08-10, TODO.md item 13) -- same
/// re-derive-fresh-every-render posture
/// `player_market_preview_generator.dart`'s Draft tab preview already
/// established for the prospect *class*, just applied to the pick
/// *order* instead. Nothing wired to a real draft-day flow yet either
/// way -- there is no Season 2 to actually pick in.
const kDraftOrderSeedOffset = 13;

/// Seed offset for [generateDraftClass]'s *real, persisted* class
/// (`0D_Season_2_Roadmap.md`'s Player pool refresh stage, 2026-08-11,
/// `season_transition_advancer.dart`'s `beginNextSeason`) -- a separate
/// stream from [kDraftOrderSeedOffset]'s own preview-only re-derivation,
/// so a save's real class can never shift because of what some other
/// screen's throwaway preview happened to roll. Next free number after
/// `retirement_advancer.dart`'s `kAiTeamRetirementSeedOffset` (18).
const kDraftClassSeedOffset = 19;

/// Seed offset for the *real* draft order -- `0D_Season_2_Roadmap.md`'s
/// "The draft, for real" stage (2026-08-11), `season_transition_advancer.dart`'s
/// `beginNextSeason`. Deliberately a separate stream from
/// [kDraftOrderSeedOffset]'s preview-only re-derivation (`SeasonRecapScreen`)
/// -- a save's real draft order must never shift because some other
/// screen's throwaway "what pick would I have" preview happened to roll
/// its `Random` differently. Next free number after [kDraftClassSeedOffset]
/// (19).
const kRealDraftOrderSeedOffset = 20;

/// A weighted-random potential somewhere in [_taperMinPotential]-
/// [_taperMaxPotential] -- linearly [_taperWeightRatio] times more common
/// at the bottom than the top (see that constant's own doc comment).
int _weightedTaperPotential(Random random) {
  final span = _taperMaxPotential - _taperMinPotential;
  final weights = [
    for (var p = _taperMinPotential; p <= _taperMaxPotential; p++)
      1 + (_taperWeightRatio - 1) * (_taperMaxPotential - p) / span,
  ];
  final totalWeight = weights.reduce((a, b) => a + b);
  var roll = random.nextDouble() * totalWeight;
  for (var i = 0; i < weights.length; i++) {
    if (roll < weights[i]) return _taperMinPotential + i;
    roll -= weights[i];
  }
  return _taperMaxPotential; // floating-point edge case fallback.
}

/// Generates [count] draft-eligible prospects: young (20-23), no
/// professional experience yet ([Player.yearsOfService] pinned to 0
/// regardless of the normal debut-age roll), each with a shot at 0-2
/// traits via [generateTraits] -- per the trait-redesign design intent,
/// this is the primary way traits enter the league, not team-wide roster
/// generation (`distributeTraits`). Deterministic for a given [random]
/// stream.
///
/// The elite-tier headcount ([_minEliteCount]-[_maxEliteCount]) is rolled
/// once per class and scaled down proportionally for a smaller-than-real
/// [count] -- without that scaling, a small preview (the Draft tab's
/// [kPlayerMarketPreviewCount]-sized one, `player_market_preview_generator.dart`)
/// could end up mostly elite prospects instead of reading like a
/// realistic slice of a real class.
///
/// [portraitWeights] is optional and threads straight through to
/// [generatePlayer] -- omitted, every prospect's [Player.appearance] stays
/// `null`, same fallback [generatePlayer] itself documents. Wasn't even a
/// parameter here until `0D_Season_2_Roadmap.md`'s Player pool refresh
/// stage (2026-08-11) started actually persisting a real class -- the
/// same gap `generateFreeAgentPool` once had before a GM playtest bug
/// report ("free agents should have a face," `Aug9bugs.md` #2) fixed it
/// there; every draft prospect shown anywhere before this was a preview
/// only, so a missing face never surfaced as a real bug.
List<DraftProspect> generateDraftClass(
  Random random, {
  int count = kDefaultDraftClassSize,
  PortraitWeights? portraitWeights,
}) {
  final collegePool = weightedColleges();
  final fullEliteCount =
      _minEliteCount + random.nextInt(_maxEliteCount - _minEliteCount + 1);
  final eliteCount = min(
    count,
    (fullEliteCount * count / kDefaultDraftClassSize).round(),
  );
  return [
    for (var i = 0; i < count; i++)
      _generateProspect(random, i, eliteCount, collegePool, portraitWeights),
  ];
}

DraftProspect _generateProspect(
  Random random,
  int index,
  int eliteCount,
  List<College> collegePool,
  PortraitWeights? portraitWeights,
) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final potential = index < eliteCount
      ? _eliteMinPotential +
            random.nextInt(_eliteMaxPotential - _eliteMinPotential + 1)
      : _weightedTaperPotential(random);
  final ratio =
      _potentialToOverallRatioMin +
      random.nextDouble() *
          (_potentialToOverallRatioMax - _potentialToOverallRatioMin);
  final targetOverall = (potential * ratio).round().clamp(
    kMinRating,
    potential,
  );

  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: targetOverall,
    qualitySpread: _prospectQualitySpread,
    minAge: _minProspectAge,
    maxAge: _maxProspectAge,
    yearsOfService: 0,
    potentialOverride: potential,
    potentialOverrideSpread: 0,
    portraitWeights: portraitWeights,
  );
  final traits = generateTraits(random, position: position);
  final withTraits = traits.isEmpty ? player : player.copyWithTraits(traits);
  final college = collegePool[random.nextInt(collegePool.length)];
  return DraftProspect(player: withTraits, college: college);
}

/// Determines the full draft order from a final regular-season
/// [standings] table: the bottom [_playoffTeamCount]-and-below teams (the
/// non-playoff field) go through a weighted lottery -- worse record means
/// more lottery weight, but nothing is guaranteed -- and the playoff
/// teams follow in reverse standings order (worst playoff seed picks
/// first among them), same as real WNBA. The same order applies to every
/// round of [kDraftRounds] -- there's no re-lottery between rounds.
///
/// The exact lottery-weighting formula (linear by reverse rank, not a
/// fixed odds table) is this project's own decision, not a literal replica
/// of the real WNBA's administrative ping-pong-ball process --
/// `0B_Planned.md`'s Draft item flagged the specifics as still open before
/// this.
List<String> generateDraftOrder(Random random, List<StandingsEntry> standings) {
  assert(
    standings.length > _playoffTeamCount,
    'need more teams than make the playoffs to have a lottery field at all',
  );

  final playoffTeams = standings.take(_playoffTeamCount).toList();
  final nonPlayoffTeams = standings.skip(_playoffTeamCount).toList();

  return [
    ..._weightedLotteryOrder(random, nonPlayoffTeams),
    for (final team in playoffTeams.reversed) team.teamAbbreviation,
  ];
}

List<String> _weightedLotteryOrder(
  Random random,
  List<StandingsEntry> nonPlayoffTeamsBestToWorst,
) {
  // Worst record first, so it can be handed the most lottery weight.
  final worstToBest = nonPlayoffTeamsBestToWorst.reversed.toList();
  final remaining = [
    for (var i = 0; i < worstToBest.length; i++)
      (worstToBest[i].teamAbbreviation, worstToBest.length - i),
  ];

  final order = <String>[];
  while (remaining.isNotEmpty) {
    final totalWeight = remaining.fold<int>(0, (sum, e) => sum + e.$2);
    var roll = random.nextInt(totalWeight);
    var pickedIndex = 0;
    for (var i = 0; i < remaining.length; i++) {
      if (roll < remaining[i].$2) {
        pickedIndex = i;
        break;
      }
      roll -= remaining[i].$2;
    }
    order.add(remaining[pickedIndex].$1);
    remaining.removeAt(pickedIndex);
  }
  return order;
}

/// The observed best-to-worst spread of where [teamAbbreviation] could
/// land, across [trials] independent re-rolls of [generateDraftOrder]
/// against the same [standings] -- a direct GM ask (2026-08-22): "Give a
/// range! Always disappointed when I see #2 estimate, but I pick 10th."
/// A single seeded point-estimate (`SeasonRecapScreen`'s old
/// `draftPosition`) reads as a promise the real, separately-seeded
/// lottery (`kRealDraftOrderSeedOffset`) never made -- [_weightedLotteryOrder]
/// only ever guarantees *more* weight for a worse record, never a floor
/// or a ceiling, so a single roll landing well outside the "expected"
/// pick isn't a bug, just an honest long tail this range surfaces
/// instead of hiding.
///
/// A team that actually made the playoffs has no real lottery
/// randomness at all (the playoff field's order is fixed, reverse
/// final-standings -- [generateDraftOrder]'s own doc comment), so
/// [min] and [max] naturally collapse to the same number for them
/// across every trial -- callers don't need a separate playoff/lottery
/// branch to know which case they're in.
///
/// [random] is consumed across all [trials] as one continuous stream
/// (not a fresh `Random` per trial) -- still fully deterministic for a
/// given starting seed, just like every other multi-draw generator in
/// this codebase, so the same franchise snapshot always reports the
/// same range on every rebuild.
({int min, int max}) projectedDraftPositionRange(
  Random random,
  List<StandingsEntry> standings,
  String teamAbbreviation, {
  int trials = 300,
}) {
  var min = 1 << 30;
  var max = 0;
  for (var i = 0; i < trials; i++) {
    final position =
        generateDraftOrder(random, standings).indexOf(teamAbbreviation) + 1;
    if (position < min) min = position;
    if (position > max) max = position;
  }
  return (min: min, max: max);
}

/// Simulates the draft itself: [draftOrder] repeats for each of [rounds]
/// rounds, and every team takes the best remaining prospect by rating --
/// "best player available," with no team-needs modeling yet (a real GM AI
/// improvement for later, not this pass).
List<DraftPick> simulateDraft(
  Random random, {
  required List<String> draftOrder,
  required List<DraftProspect> draftClass,
  int rounds = kDraftRounds,
}) {
  assert(
    draftClass.length >= draftOrder.length * rounds,
    'not enough prospects for every team to pick in every round',
  );

  final available = [...draftClass];
  final picks = <DraftPick>[];
  var overallPick = 1;
  for (var round = 1; round <= rounds; round++) {
    for (final team in draftOrder) {
      available.sort(
        (a, b) => draftProspectValue(b).compareTo(draftProspectValue(a)),
      );
      final selected = available.removeAt(0);
      picks.add(
        DraftPick(
          round: round,
          pickNumber: overallPick,
          teamAbbreviation: team,
          prospect: selected,
        ),
      );
      overallPick++;
    }
  }
  return picks;
}

/// "Best player available" value for one prospect -- overall plus half of
/// potential, so a lower-rated-but-high-upside prospect can still edge out
/// a higher-rated-but-capped one. Shared by [simulateDraft] (the
/// whole-draft preview) and `draft_advancer.dart`'s real, pick-by-pick AI
/// resolution -- both need the exact same "who's best" ranking, or a real
/// draft-day pick could disagree with what the preview screens showed for
/// the same slot.
int draftProspectValue(DraftProspect prospect) =>
    prospect.player.ratings.overall + prospect.player.ratings.potential ~/ 2;
