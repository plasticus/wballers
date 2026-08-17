import 'dart:math';

import '../../player/domain/player.dart';

/// Target minutes by rank on a 12-player active roster, summing to a full
/// 200 player-minutes across a 40-minute game (5 on court at a time) --
/// `0B_Planned.md`'s reference table. Index 0 is rank 1 (the best player).
const _targetMinutesByRank = <int>[30, 30, 30, 26, 26, 14, 14, 8, 8, 6, 4, 4];

/// Ranks [roster] by [PlayerRatings.overall] (best first), then --
/// roughly half the time, decided once per team by [_shouldBalanceTopFive]
/// -- rebalances the top 5 to cover one of each standard position
/// ([_withBalancedTopFive]) before assigning target minutes off
/// `_targetMinutesByRank`. There's no GM-set target-minutes ranking to
/// defer to yet (`0B_Planned.md`'s automatic-substitutions item is still
/// UI-less), so this is the default the engine falls back to -- "best
/// players play the most" -- for every AI team, same
/// random-default-but-overridable shape used elsewhere (team colors, the
/// team-to-replace picker) once a real ranking exists to plug in here.
///
/// Only *some* teams get balanced, deliberately: an initial version
/// balanced every AI team, but a direct GM follow-up (2026-08-15) walked
/// that back -- "I don't want them *all* to field standard lineups...
/// having some non-standard ones is really cool! Like a team that deploys
/// 2 PFs instead of a Center... that's why I said 50%, not 100%." A team
/// that skips balancing just keeps its plain overall-sorted top 5,
/// duplicate positions and all -- that's the "interesting" variety being
/// preserved, not a residual bug.
Map<Player, int> targetMinutesFor(List<Player> roster) {
  assert(roster.length == 12, 'expects a full 12-player active roster');
  final sorted = [...roster]
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  final topFive = _shouldBalanceTopFive(roster)
      ? _withBalancedTopFive(sorted)
      : sorted;
  return targetMinutesForOrderedRoster(topFive);
}

/// A stable, cross-run-deterministic hash of a player id string -- same
/// algorithm as `training/generation/training_advancer.dart`'s own
/// private `_stableStringHash` (kept separate since Dart privacy is
/// per-file), used instead of `String.hashCode` because that's not a
/// documented-stable algorithm across Dart/Flutter versions, and this
/// codebase's deterministic-simulation invariants all lean on exact
/// reproducibility for a given save.
int _stableStringHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = (31 * hash + codeUnit) & 0x7fffffff;
  }
  return hash;
}

/// Whether [roster] -- a specific team's specific 12 players -- gets
/// [_withBalancedTopFive]'s standard-lineup treatment: a deterministic
/// ~50/50 split, stable for as long as this exact set of players stays
/// together (no trades exist yet, so that's the whole season). Derived
/// from the roster's own player ids (sorted, so list order doesn't
/// matter) rather than a plain team-index coin flip, so it's still stable
/// if a caller's team ordering ever changes without needing a real seed
/// threaded all the way through here.
///
/// Seeds a real [Random] with the hash rather than reading a bit off it
/// directly (e.g. `.isEven`) -- every id here shares the same fixed-size
/// roster (12 players), so a naive checksum-style hash's low bit ends up
/// *constant* across every roster (each id contributes its own prefix's
/// parity an even number of times, which always cancels out), not the
/// ~50/50 split it looks like at a glance. `Random`'s own bit-mixing
/// avoids that trap -- same reason `_isBreakoutSeason`
/// (`training/generation/training_advancer.dart`) seeds a `Random` from
/// a stable hash instead of trusting the hash's own bits directly.
bool _shouldBalanceTopFive(List<Player> roster) {
  final ids = [for (final player in roster) player.id]..sort();
  return Random(_stableStringHash(ids.join(','))).nextBool();
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
/// covered by the top 5.
///
/// This is the same fix already applied to the GM's own Day-0 roster
/// (`roster/generation/starting_roster_generator.dart`'s
/// `_promoteMissingPositionStarter`), ported here because AI teams have
/// no GM-ordered bench to inherit that fix from -- their actual on-court
/// five comes from this overall sort, not roster-generation order (a
/// direct GM report, 2026-08-15: "zero other teams have a standard
/// starting 5"). Only called for the roughly-half of AI teams
/// [_shouldBalanceTopFive] selects -- see [targetMinutesFor]'s own doc
/// comment for why the other half deliberately skip this.
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

    // Swap the two players' list positions directly, then re-sort each
    // half by overall so the promotion/demotion doesn't otherwise disturb
    // "best players play the most" within the top 5 and within the bench.
    final updated = List<Player>.of(roster);
    final promoted = updated[promoteIndex];
    final displaced = updated[displaceIndex];
    updated[displaceIndex] = promoted;
    updated[promoteIndex] = displaced;
    final newTopFive = updated.sublist(0, 5)
      ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
    final newBench = updated.sublist(5)
      ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
    roster = [...newTopFive, ...newBench];
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
  assert(orderedRoster.length == 12, 'expects a full 12-player active roster');
  return {
    for (var i = 0; i < orderedRoster.length; i++)
      orderedRoster[i]: _targetMinutesByRank[i],
  };
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
