import '../../league/domain/team_identity.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player.dart';

/// Target minutes by rank on a 12-player active roster, summing to a full
/// 200 player-minutes across a 40-minute game (5 on court at a time) --
/// `0B_Planned.md`'s reference table. Index 0 is rank 1 (the best player).
const _targetMinutesByRank = <int>[30, 30, 30, 26, 26, 14, 14, 8, 8, 6, 4, 4];

/// The full-roster total [_targetMinutesByRank] sums to -- every
/// [targetMinutesForOrderedRoster] call redistributes to hit exactly this,
/// whether the roster is a full 12 or short a player or two to injury.
const kTotalTargetMinutes = 200;

/// Ranks [roster] by [PlayerRatings.overall] (best first), then tries to
/// steer the top 5 toward [teamAbbreviation]'s own `TeamIdentity.preferredShape`
/// before assigning target minutes off `_targetMinutesByRank`. There's no
/// GM-set target-minutes ranking to defer to yet (`0B_Planned.md`'s
/// automatic-substitutions item is still UI-less), so this is the default
/// the engine falls back to -- "best players play the most, steered
/// toward this team's own shape" -- for every AI team.
///
/// [teamAbbreviation] is optional -- omitted (or a shape that can't be
/// forced), the top 5 just stays the plain overall-sorted list, duplicate
/// positions and all. [OffenseShape.motion] is never explicitly forced
/// either, by design: it's the "nothing special happened" shape
/// ([OffenseShape.detectOffenseShape]'s own doc comment), so a team whose
/// identity targets it simply gets the unforced top 5 -- same shape this
/// whole mechanism used to default to for every team before
/// [TeamIdentity.preferredShape] existed (2026-08-15, a direct GM call:
/// "I don't want them *all* to field standard lineups... that's why I
/// said 50%, not 100%" -- still true today, just driven by a real,
/// per-team identity now instead of an anonymous coin flip, per a direct
/// GM follow-up 2026-08-21: "I still think 50% of teams should be a
/// classic shape... 50% would try for the standard shape, and 50% other
/// stuff").
Map<Player, int> targetMinutesFor(
  List<Player> roster, {
  String? teamAbbreviation,
}) {
  assert(
    roster.length >= 5,
    'expects at least 5 active players to field a game',
  );
  final sorted = [...roster]
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  final preferredShape = teamAbbreviation == null
      ? null
      : identityFor(teamAbbreviation).preferredShape;
  final topFive = switch (preferredShape) {
    OffenseShape.traditional => _withBalancedTopFive(sorted),
    OffenseShape.postUp => _withPostUpTopFive(sorted),
    OffenseShape.paceAndSpace => _withPaceAndSpaceTopFive(sorted),
    OffenseShape.motion || null => sorted,
  };
  return targetMinutesForOrderedRoster(topFive);
}

bool _isBig(Player player) =>
    player.primaryPosition == Position.powerForward ||
    player.primaryPosition == Position.center;

/// Swaps [promoteIndex] and [displaceIndex] in [roster], then re-sorts
/// each half (top 5 / bench) by overall independently, so a forced swap
/// never otherwise disturbs "best players play the most" within either
/// group. Shared by every `_with*TopFive` builder below.
List<Player> _swapAndResort(
  List<Player> roster,
  int promoteIndex,
  int displaceIndex,
) {
  final updated = List<Player>.of(roster);
  final promoted = updated[promoteIndex];
  final displaced = updated[displaceIndex];
  updated[displaceIndex] = promoted;
  updated[promoteIndex] = displaced;
  final newTopFive = updated.sublist(0, 5)
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  final newBench = updated.sublist(5)
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  return [...newTopFive, ...newBench];
}

/// Rearranges [sortedByOverall] (already ranked best-to-worst by
/// [PlayerRatings.overall]) so its own top 5 -- ranks 0-4, the two
/// highest target-minutes tiers -- cover one of each standard position,
/// promoting the best available player at any position missing from the
/// top 5 up from the bench in place of the weakest starter whose
/// position duplicates another starter's. Every generated roster carries
/// at least 2 of each position (`roster/generation/roster_position_plan.dart`'s
/// `kTwelvePlayerPositionPlan`), so this always succeeds for a full
/// 12-player roster, converging in at most `Position.values.length`
/// swaps since each swap strictly grows the number of distinct positions
/// covered by the top 5. Lands exactly on [OffenseShape.traditional]'s own
/// definition -- one of each position means 2 guards, 1 wing, 2 bigs.
///
/// This is the same fix already applied to the GM's own Day-0 roster
/// (`roster/generation/starting_roster_generator.dart`'s
/// `_promoteMissingPositionStarter`), ported here because AI teams have
/// no GM-ordered bench to inherit that fix from -- their actual on-court
/// five comes from this overall sort, not roster-generation order (a
/// direct GM report, 2026-08-15: "zero other teams have a standard
/// starting 5"). Only called for whichever AI teams
/// `TeamIdentity.preferredShape` targets [OffenseShape.traditional] -- see
/// [targetMinutesFor]'s own doc comment.
List<Player> _withBalancedTopFive(List<Player> sortedByOverall) {
  var roster = List<Player>.of(sortedByOverall);
  for (var attempt = 0; attempt < Position.values.length; attempt++) {
    final counts = <Position, int>{
      for (final position in Position.values) position: 0,
    };
    for (final player in roster.take(5)) {
      counts[player.primaryPosition] = counts[player.primaryPosition]! + 1;
    }
    final missingPositions = Position.values.where(
      (position) => counts[position] == 0,
    );
    if (missingPositions.isEmpty) break;
    final missingPosition = missingPositions.first;

    final benchCandidateIndices = [
      for (var i = 5; i < roster.length; i++)
        if (roster[i].primaryPosition == missingPosition) i,
    ];
    final duplicateStarterIndices = [
      for (var i = 0; i < 5; i++)
        if (counts[roster[i].primaryPosition]! > 1) i,
    ];
    if (benchCandidateIndices.isEmpty || duplicateStarterIndices.isEmpty) {
      // Shouldn't happen given the position-plan guarantee, but don't
      // crash a match over it -- just leave this position unbalanced.
      break;
    }
    final promoteIndex = benchCandidateIndices.reduce(
      (a, b) => roster[a].ratings.overall >= roster[b].ratings.overall ? a : b,
    );
    final displaceIndex = duplicateStarterIndices.reduce(
      (a, b) => roster[a].ratings.overall <= roster[b].ratings.overall ? a : b,
    );
    roster = _swapAndResort(roster, promoteIndex, displaceIndex);
  }
  return roster;
}

/// Steers [sortedByOverall]'s top 5 toward [OffenseShape.postUp]'s own
/// definition -- 3+ bigs on the floor -- by promoting the best available
/// bench PF/C in place of the weakest non-big starter, repeated until
/// either 3 bigs land in the top 5 or there's genuinely nothing left to
/// promote. The position plan guarantees at least 2 PF + 2 C per roster
/// (4 bigs total), always enough to reach 3. Bounded the same generous
/// way [_withBalancedTopFive] is -- convergence only ever needs at most 3
/// swaps (0 to 3 bigs), [Position.values.length] is comfortably more.
List<Player> _withPostUpTopFive(List<Player> sortedByOverall) {
  var roster = List<Player>.of(sortedByOverall);
  for (var attempt = 0; attempt < Position.values.length; attempt++) {
    if (roster.take(5).where(_isBig).length >= 3) break;
    final benchBigIndices = [
      for (var i = 5; i < roster.length; i++)
        if (_isBig(roster[i])) i,
    ];
    final nonBigStarterIndices = [
      for (var i = 0; i < 5; i++)
        if (!_isBig(roster[i])) i,
    ];
    if (benchBigIndices.isEmpty || nonBigStarterIndices.isEmpty) break;
    final promoteIndex = benchBigIndices.reduce(
      (a, b) => roster[a].ratings.overall >= roster[b].ratings.overall ? a : b,
    );
    final displaceIndex = nonBigStarterIndices.reduce(
      (a, b) => roster[a].ratings.overall <= roster[b].ratings.overall ? a : b,
    );
    roster = _swapAndResort(roster, promoteIndex, displaceIndex);
  }
  return roster;
}

/// Steers [sortedByOverall]'s top 5 toward [OffenseShape.paceAndSpace]'s
/// own definition -- 1 or 0 bigs on the floor -- by demoting the weakest
/// big starter in place of the best available non-big bench player,
/// repeated until either 1 big or fewer remains in the top 5 or there's
/// genuinely nothing left to demote. The position plan guarantees at
/// least 6 non-big players per roster (2 each of PG/SG/SF), always enough
/// to backfill. Bounded the same generous way [_withBalancedTopFive] is.
List<Player> _withPaceAndSpaceTopFive(List<Player> sortedByOverall) {
  var roster = List<Player>.of(sortedByOverall);
  for (var attempt = 0; attempt < Position.values.length; attempt++) {
    if (roster.take(5).where(_isBig).length <= 1) break;
    final bigStarterIndices = [
      for (var i = 0; i < 5; i++)
        if (_isBig(roster[i])) i,
    ];
    final benchNonBigIndices = [
      for (var i = 5; i < roster.length; i++)
        if (!_isBig(roster[i])) i,
    ];
    if (bigStarterIndices.isEmpty || benchNonBigIndices.isEmpty) break;
    final displaceIndex = bigStarterIndices.reduce(
      (a, b) => roster[a].ratings.overall <= roster[b].ratings.overall ? a : b,
    );
    final promoteIndex = benchNonBigIndices.reduce(
      (a, b) => roster[a].ratings.overall >= roster[b].ratings.overall ? a : b,
    );
    roster = _swapAndResort(roster, promoteIndex, displaceIndex);
  }
  return roster;
}

/// Assigns target minutes off `_targetMinutesByRank` in [orderedRoster]'s
/// own list order -- no resorting. This is the GM's own bench order made
/// mechanical: `DepthChartScreen` already frames list position as "the
/// rank" and shows each row its `targetMinutesForRank`, but until now
/// nothing in the match engine actually read that order back -- dragging
/// a player up or down had zero effect on an actual game, only
/// [targetMinutesFor]'s own overall-based resort ever ran. A direct GM
/// report ("I don't see the point of setting bench order") traced back to
/// this gap. AI teams have no GM to set an order for, so they keep using
/// [targetMinutesFor]'s automatic overall-based ranking -- this variant is
/// for whichever roster a caller already knows is in a real, meaningful
/// order.
Map<Player, int> targetMinutesForOrderedRoster(List<Player> orderedRoster) {
  assert(
    orderedRoster.length >= 5,
    'expects at least 5 active players to field a game',
  );
  final n = orderedRoster.length;
  if (n > 12) {
    // An illegal, over-cap active roster -- `roster_legality.dart`'s own
    // gate blocks advancing *past* preseason while this is true, but
    // preseason itself is deliberately still playable (2026-08-23, a
    // direct GM design call: "you can roll an illegal roster through
    // preseason, then... if your roster is illegal before game 1, it
    // won't let you play the game"). Only the top 12 in [orderedRoster]'s
    // own order actually dress -- everyone past that gets 0 target
    // minutes, same as a real team inactive-listing the overflow for
    // this one game, rather than crashing (`_targetMinutesByRank` only
    // has 12 entries; a naive `sublist` past that throws a RangeError --
    // this was the exact silent "Play Game just spins" crash mechanism
    // the auto-waive this replaces was originally built to avoid).
    return {
      for (var i = 0; i < 12; i++) orderedRoster[i]: _targetMinutesByRank[i],
      for (var i = 12; i < n; i++) orderedRoster[i]: 0,
    };
  }
  if (n == 12) {
    return {
      for (var i = 0; i < n; i++) orderedRoster[i]: _targetMinutesByRank[i],
    };
  }

  // Fewer than a full 12 -- an injury (or two) has parked someone in
  // Reserve/Inactive (2026-08-20, following a direct GM question: "do we
  // need to plan minutes differently?"). Ranks 1-N simply slide up the
  // same table [orderedRoster] is already in -- that alone gives an
  // injured starter's replacement starter-level minutes for free, no
  // special-casing needed. What's left over is the minutes the *omitted*
  // bottom ranks would have played; the GM's own suggestion was to spread
  // that across "the remaining non-starters" rather than touch the
  // starters' minutes, so it's split evenly across ranks 6+ (falling back
  // to splitting across everyone in the vanishingly rare case fewer than
  // 6 players remain at all -- shouldn't happen given the 2-slot
  // Reserve/Inactive cap, but this keeps the totals exact either way).
  final assigned = _targetMinutesByRank.sublist(0, n);
  final shortfall = kTotalTargetMinutes - assigned.reduce((a, b) => a + b);
  const starterCount = 5;
  final benchStart = n > starterCount ? starterCount : 0;
  final benchCount = n - benchStart;
  final share = shortfall ~/ benchCount;
  final remainder = shortfall - (share * benchCount);
  final minutes = List<int>.of(assigned);
  for (var i = benchStart; i < n; i++) {
    // Any leftover single minutes (integer division can't split evenly)
    // go to the higher-ranked bench players first.
    minutes[i] += share + (i - benchStart < remainder ? 1 : 0);
  }

  return {for (var i = 0; i < n; i++) orderedRoster[i]: minutes[i]};
}

int Function(Player, Player) _byMostBehindSchedule(
  Map<Player, int> targetMinutes,
  Map<Player, double> minutesPlayed,
) {
  return (a, b) {
    final aBehind = targetMinutes[a]! - (minutesPlayed[a] ?? 0);
    final bBehind = targetMinutes[b]! - (minutesPlayed[b] ?? 0);
    return bBehind.compareTo(aBehind);
  };
}

/// Picks the 5 players who should be on court right now: whoever is
/// furthest behind their target minutes relative to what they've actually
/// played so far, excluding anyone in [fouledOut] or [rested]. Locks in
/// per quarter rather than modeling live in-quarter checks -- a simpler
/// approximation of real substitution patterns (which cluster at
/// dead-ball stoppages anyway) than tracking exact in/out timing.
///
/// [rested] (2026-08-17, the quarter-break coaching-options catalog's
/// "Rest a Player" -- `0B_Planned.md`'s quarter-break bullet) is whoever
/// the coach has explicitly sat for the current stretch, on top of the
/// ordinary target-minutes rotation -- defaults to empty, same opt-in
/// posture as every other bonus in this engine. `match_engine.dart` is
/// responsible for clearing it once that pick's duration (1 quarter, or
/// the final ~2 minutes) is over.
List<Player> pickOnCourt({
  required List<Player> roster,
  required Map<Player, int> targetMinutes,
  required Map<Player, double> minutesPlayed,
  required Set<Player> fouledOut,
  Set<Player> rested = const {},
}) {
  final available =
      roster
          .where((p) => !fouledOut.contains(p) && !rested.contains(p))
          .toList()
        ..sort(_byMostBehindSchedule(targetMinutes, minutesPlayed));
  assert(
    available.length >= 5,
    'fewer than 5 available (non-fouled-out, non-rested) players remain '
    'on the roster',
  );
  return available.take(5).toList();
}

/// Replaces [foulingPlayer] in [onCourt] with the best available bench
/// player (same "furthest behind schedule" rule as [pickOnCourt]), for a
/// player who just fouled out mid-quarter. [rested] (2026-08-17,
/// `CoachingOption.restAPlayer`) is excluded from consideration same as
/// [pickOnCourt] -- a coach's rest call shouldn't get quietly overridden
/// by a teammate's foul trouble.
List<Player> substituteForFoulOut({
  required Player foulingPlayer,
  required List<Player> onCourt,
  required List<Player> roster,
  required Map<Player, int> targetMinutes,
  required Map<Player, double> minutesPlayed,
  required Set<Player> fouledOut,
  Set<Player> rested = const {},
}) {
  final bench =
      roster
          .where(
            (p) =>
                !onCourt.contains(p) &&
                !fouledOut.contains(p) &&
                !rested.contains(p),
          )
          .toList()
        ..sort(_byMostBehindSchedule(targetMinutes, minutesPlayed));
  assert(bench.isNotEmpty, 'no bench player available to replace a foul-out');
  final replacement = bench.first;
  return [
    for (final p in onCourt)
      if (p == foulingPlayer) replacement else p,
  ];
}
