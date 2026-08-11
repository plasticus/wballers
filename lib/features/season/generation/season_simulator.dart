import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/season_schedule.dart';

/// Simulates every game in [schedule], in week order, against one
/// continuing [random] stream -- deterministic for a given seed, same
/// pattern as the rest of generation. [rostersByAbbreviation] must have an
/// entry (a full 12-player active roster) for every team referenced by the
/// schedule. [coachesByAbbreviation] is optional (`null` skips the coach
/// Offense-vs-Defense bonus entirely, same as every other real caller in
/// this call chain) -- this function is an admin/diagnostic tool, not part
/// of the live game loop, so most callers won't have real coach data handy.
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
  Map<String, Coach>? coachesByAbbreviation,
}) {
  final games = [...schedule.games]
    ..sort((a, b) {
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
          homeCoach: coachesByAbbreviation?[game.homeTeamAbbreviation],
          awayCoach: coachesByAbbreviation?[game.awayTeamAbbreviation],
        ),
      ),
  ];
}
