import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/season_schedule.dart';

/// Simulates every game in [schedule], in week order, against one
/// continuing [random] stream -- deterministic for a given seed, same
/// pattern as the rest of generation. [rostersByAbbreviation] must have an
/// entry (a full 12-player active roster) for every team referenced by the
/// schedule.
///
/// This is deliberately just "run `simulateMatch` for each game" -- the
/// heavy lifting already lives in the match engine (`0A_Completed.md`).
/// Standings are a separate derivation (`computeStandings`) over the
/// returned list, not computed here, so a caller who only wants a handful
/// of results doesn't pay for a table they didn't ask for.
List<GameResult> simulateSeason(
  Random random, {
  required SeasonSchedule schedule,
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  final games = [...schedule.games]..sort((a, b) {
    final byWeek = a.week.compareTo(b.week);
    if (byWeek != 0) return byWeek;
    return a.day.index.compareTo(b.day.index);
  });
  return [
    for (final game in games)
      GameResult(
        game: game,
        match: simulateMatch(
          random,
          homeRoster: rostersByAbbreviation[game.homeTeamAbbreviation]!,
          awayRoster: rostersByAbbreviation[game.awayTeamAbbreviation]!,
        ),
      ),
  ];
}
