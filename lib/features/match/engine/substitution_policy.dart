import '../../player/domain/player.dart';

/// Target minutes by rank on a 12-player active roster, summing to a full
/// 200 player-minutes across a 40-minute game (5 on court at a time) --
/// `0B_Planned.md`'s reference table. Index 0 is rank 1 (the best player).
const _targetMinutesByRank = <int>[30, 30, 30, 26, 26, 14, 14, 8, 8, 6, 4, 4];

/// Ranks [roster] by [PlayerRatings.overall] (best first) and assigns each
/// player their target minutes off `_targetMinutesByRank`. There's no
/// GM-set target-minutes ranking to defer to yet (`0B_Planned.md`'s
/// automatic-substitutions item is still UI-less), so this is the default
/// the engine falls back to -- "best players play the most," same
/// random-default-but-overridable shape used elsewhere (team colors, the
/// team-to-replace picker) once a real ranking exists to plug in here.
Map<Player, int> targetMinutesFor(List<Player> roster) {
  assert(roster.length == 12, 'expects a full 12-player active roster');
  final sorted = [...roster]
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  return targetMinutesForOrderedRoster(sorted);
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
/// played so far, excluding anyone in [fouledOut]. Locks in per quarter
/// rather than modeling live in-quarter checks -- a simpler approximation
/// of real substitution patterns (which cluster at dead-ball stoppages
/// anyway) than tracking exact in/out timing.
List<Player> pickOnCourt({
  required List<Player> roster,
  required Map<Player, int> targetMinutes,
  required Map<Player, double> minutesPlayed,
  required Set<Player> fouledOut,
}) {
  final available = roster.where((p) => !fouledOut.contains(p)).toList()
    ..sort(_byMostBehindSchedule(targetMinutes, minutesPlayed));
  assert(
    available.length >= 5,
    'fewer than 5 available (non-fouled-out) players remain on the roster',
  );
  return available.take(5).toList();
}

/// Replaces [foulingPlayer] in [onCourt] with the best available bench
/// player (same "furthest behind schedule" rule as [pickOnCourt]), for a
/// player who just fouled out mid-quarter.
List<Player> substituteForFoulOut({
  required Player foulingPlayer,
  required List<Player> onCourt,
  required List<Player> roster,
  required Map<Player, int> targetMinutes,
  required Map<Player, double> minutesPlayed,
  required Set<Player> fouledOut,
}) {
  final bench =
      roster
          .where((p) => !onCourt.contains(p) && !fouledOut.contains(p))
          .toList()
        ..sort(_byMostBehindSchedule(targetMinutes, minutesPlayed));
  assert(bench.isNotEmpty, 'no bench player available to replace a foul-out');
  final replacement = bench.first;
  return [
    for (final p in onCourt)
      if (p == foulingPlayer) replacement else p,
  ];
}
