import 'dart:math';

import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../player/generation/trait_generator.dart';
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
List<DraftProspect> generateDraftClass(
  Random random, {
  int count = kDefaultDraftClassSize,
}) {
  final collegePool = weightedColleges();
  return [
    for (var i = 0; i < count; i++)
      _generateProspect(random, i, count, collegePool),
  ];
}

DraftProspect _generateProspect(
  Random random,
  int index,
  int classSize,
  List<College> collegePool,
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
      available.sort((a, b) => _draftValue(b).compareTo(_draftValue(a)));
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

int _draftValue(DraftProspect prospect) =>
    prospect.player.ratings.overall + prospect.player.ratings.potential ~/ 2;
