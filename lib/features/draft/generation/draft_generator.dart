import 'dart:math';

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

/// Draft-class talent shape: a couple of true lottery-caliber prospects, a
/// solid middle tier, and a long tail of fringe/deep prospects who may not
/// stick on a roster at all -- loosely mirroring a real draft class rather
/// than a flat quality curve, same idea as `ai_roster_generator.dart`'s
/// star/quarter-star/role tiers.
const _eliteCount = 2;
const _eliteQualityCenter = 78;
const _eliteQualitySpread = 6;
const _solidCount = 12;
const _solidQualityCenter = 60;
const _solidQualitySpread = 8;
const _fringeQualityCenter = 42;
const _fringeQualitySpread = 10;

/// Default draft class size -- comfortably more than the 60 picks a
/// 20-team, 3-round draft needs (see [kDraftRounds]), so not every
/// prospect gets drafted, same as real life.
const kDefaultDraftClassSize = 70;

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

(int qualityCenter, int qualitySpread) _qualityTierFor(int index, int total) {
  final eliteCount = min(_eliteCount, total);
  final solidCount = min(_solidCount, total - eliteCount);
  if (index < eliteCount) return (_eliteQualityCenter, _eliteQualitySpread);
  if (index < eliteCount + solidCount) {
    return (_solidQualityCenter, _solidQualitySpread);
  }
  return (_fringeQualityCenter, _fringeQualitySpread);
}

/// Generates [count] draft-eligible prospects: young (20-23), no
/// professional experience yet ([Player.yearsOfService] pinned to 0
/// regardless of the normal debut-age roll), each with a shot at 0-2
/// traits via [generateTraits] -- per the trait-redesign design intent,
/// this is the primary way traits enter the league, not team-wide roster
/// generation (`distributeTraits`). Deterministic for a given [random]
/// stream.
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
  return [
    for (var i = 0; i < count; i++)
      _generateProspect(random, i, count, collegePool, portraitWeights),
  ];
}

DraftProspect _generateProspect(
  Random random,
  int index,
  int classSize,
  List<College> collegePool,
  PortraitWeights? portraitWeights,
) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final (qualityCenter, qualitySpread) = _qualityTierFor(index, classSize);
  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: qualityCenter,
    qualitySpread: qualitySpread,
    minAge: _minProspectAge,
    maxAge: _maxProspectAge,
    yearsOfService: 0,
    portraitWeights: portraitWeights,
  );
  final traits = generateTraits(random);
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
