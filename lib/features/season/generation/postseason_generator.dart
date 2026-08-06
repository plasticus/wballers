import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/game_day.dart';
import '../domain/game_result.dart';
import '../domain/scheduled_game.dart';
import '../domain/series_result.dart';
import '../domain/standings_entry.dart';
import 'season_schedule_generator.dart';

/// The 3-day rotation a postseason series' games cycle through --
/// `0B_Planned.md`'s tentative postseason-only Tuesday addition, for a
/// 3-games/week pace. Every series game gets tagged with a day from this
/// rotation by game index; the round's own `week` constant (First
/// Round/Semifinals/Finals) already keys it into the season calendar, so
/// the day here is really just "which of the round's games is this," not
/// a real per-team schedule conflict check (unlike the regular season,
/// series games aren't pre-scheduled into [SeasonSchedule] at all -- see
/// [simulateSeries]).
const _seriesGameDayRotation = [GameDay.sunday, GameDay.tuesday, GameDay.thursday];

/// How many teams make the postseason -- real 2022+ WNBA format, no
/// conference restriction on seeding.
const kPostseasonTeamCount = 8;

const _firstRoundWinsNeeded = 2; // best-of-3
const _semifinalsWinsNeeded = 3; // best-of-5
const _finalsWinsNeeded = 4; // best-of-7

/// Takes the top [kPostseasonTeamCount] teams from a final regular-season
/// [standings] table as the postseason field, seed 1 (index 0) first.
List<String> postseasonSeeds(List<StandingsEntry> standings) {
  assert(
    standings.length >= kPostseasonTeamCount,
    'need at least $kPostseasonTeamCount teams to seed a postseason bracket',
  );
  return standings
      .take(kPostseasonTeamCount)
      .map((e) => e.teamAbbreviation)
      .toList();
}

/// Standard best-of-N home/away pattern: the higher seed hosts the extra
/// game(s) (2-1 for best-of-3, 2-2-1 for best-of-5, 2-2-1-1-1 for
/// best-of-7) -- real WNBA/NBA format. Games past however many are needed
/// to clinch never get consulted, since [simulateSeries] stops early.
List<bool> _homeAwayPattern(int winsNeeded) {
  return switch (winsNeeded) {
    2 => const [true, true, false],
    3 => const [true, true, false, false, true],
    4 => const [true, true, false, false, true, false, true],
    _ => throw ArgumentError('unsupported winsNeeded: $winsNeeded'),
  };
}

/// Simulates one best-of-N series between [higherSeedAbbreviation] (who
/// gets home-court advantage) and [lowerSeedAbbreviation], stopping as
/// soon as either side reaches [winsNeeded] -- a sweep plays fewer games
/// than a full series, same as real playoff basketball. Every game is
/// tagged [GameType.postseason] at [round]/[week] for box-score and
/// schedule purposes, even though the games aren't run through
/// `simulateSeason` (a series' game count isn't known ahead of time, so
/// there's nothing to pre-schedule).
SeriesResult simulateSeries(
  Random random, {
  required String higherSeedAbbreviation,
  required String lowerSeedAbbreviation,
  required int winsNeeded,
  required int week,
  required int round,
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  final pattern = _homeAwayPattern(winsNeeded);
  final games = <GameResult>[];
  var higherSeedWins = 0;
  var lowerSeedWins = 0;
  var gameIndex = 0;

  while (higherSeedWins < winsNeeded && lowerSeedWins < winsNeeded) {
    final higherSeedIsHome = pattern[gameIndex];
    final homeAbbreviation = higherSeedIsHome
        ? higherSeedAbbreviation
        : lowerSeedAbbreviation;
    final awayAbbreviation = higherSeedIsHome
        ? lowerSeedAbbreviation
        : higherSeedAbbreviation;

    final match = simulateMatch(
      random,
      homeRoster: rostersByAbbreviation[homeAbbreviation]!,
      awayRoster: rostersByAbbreviation[awayAbbreviation]!,
    );
    final result = GameResult(
      game: ScheduledGame(
        week: week,
        day: _seriesGameDayRotation[gameIndex % _seriesGameDayRotation.length],
        homeTeamAbbreviation: homeAbbreviation,
        awayTeamAbbreviation: awayAbbreviation,
        type: GameType.postseason,
        postseasonRound: round,
      ),
      match: match,
    );
    games.add(result);
    if (result.winningTeamAbbreviation == higherSeedAbbreviation) {
      higherSeedWins++;
    } else {
      lowerSeedWins++;
    }
    gameIndex++;
  }

  return SeriesResult(
    higherSeedAbbreviation: higherSeedAbbreviation,
    lowerSeedAbbreviation: lowerSeedAbbreviation,
    winsNeeded: winsNeeded,
    games: games,
  );
}

/// Whichever of [a]/[b] has the better (lower-numbered) seed in [seeds].
String _betterSeed(String a, String b, List<String> seeds) =>
    seeds.indexOf(a) < seeds.indexOf(b) ? a : b;

String _worseSeed(String a, String b, List<String> seeds) =>
    seeds.indexOf(a) < seeds.indexOf(b) ? b : a;

/// Postseason First Round: standard bracket seeding (1v8, 2v7, 3v6, 4v5),
/// each a best-of-3 series. Returns the 4 series in that same bracket
/// order -- [generatePostseasonSemifinals] depends on the order to know
/// which winners face each other next.
List<SeriesResult> generatePostseasonFirstRound(
  Random random, {
  required List<String> seeds,
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  assert(
    seeds.length == kPostseasonTeamCount,
    'expects the $kPostseasonTeamCount seeds postseasonSeeds produces',
  );

  final matchups = [
    (seeds[0], seeds[7]),
    (seeds[1], seeds[6]),
    (seeds[2], seeds[5]),
    (seeds[3], seeds[4]),
  ];
  return [
    for (final (higher, lower) in matchups)
      simulateSeries(
        random,
        higherSeedAbbreviation: higher,
        lowerSeedAbbreviation: lower,
        winsNeeded: _firstRoundWinsNeeded,
        week: kPostseasonFirstRoundWeek,
        round: 1,
        rostersByAbbreviation: rostersByAbbreviation,
      ),
  ];
}

/// Postseason Semifinals: a fixed (not reseeded) bracket -- the First
/// Round's game-0 winner plays its game-3 winner, and game-1's winner
/// plays game-2's winner (1v8/4v5 winners meet, 2v7/3v6 winners meet).
/// Each a best-of-5 series.
List<SeriesResult> generatePostseasonSemifinals(
  Random random, {
  required List<SeriesResult> firstRoundResults,
  required List<String> seeds,
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  assert(
    firstRoundResults.length == 4,
    'Postseason First Round is always 4 series',
  );

  final winners = firstRoundResults
      .map((r) => r.winningTeamAbbreviation)
      .toList();
  final pairings = [(winners[0], winners[3]), (winners[1], winners[2])];
  return [
    for (final (a, b) in pairings)
      simulateSeries(
        random,
        higherSeedAbbreviation: _betterSeed(a, b, seeds),
        lowerSeedAbbreviation: _worseSeed(a, b, seeds),
        winsNeeded: _semifinalsWinsNeeded,
        week: kPostseasonSemifinalsWeek,
        round: 2,
        rostersByAbbreviation: rostersByAbbreviation,
      ),
  ];
}

/// Postseason Finals: the 2 Semifinal winners play a single best-of-7
/// series for the championship.
SeriesResult generatePostseasonFinals(
  Random random, {
  required List<SeriesResult> semifinalResults,
  required List<String> seeds,
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  assert(
    semifinalResults.length == 2,
    'Postseason Semifinals is always 2 series',
  );

  final finalists = semifinalResults
      .map((r) => r.winningTeamAbbreviation)
      .toList();
  return simulateSeries(
    random,
    higherSeedAbbreviation: _betterSeed(finalists[0], finalists[1], seeds),
    lowerSeedAbbreviation: _worseSeed(finalists[0], finalists[1], seeds),
    winsNeeded: _finalsWinsNeeded,
    week: kPostseasonFinalsWeek,
    round: 3,
    rostersByAbbreviation: rostersByAbbreviation,
  );
}
