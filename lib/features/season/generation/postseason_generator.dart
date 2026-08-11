import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../league/domain/team.dart';
import '../../match/engine/match_engine.dart';
import '../../match/engine/substitution_policy.dart';
import '../../player/domain/player.dart';
import '../domain/game_day.dart';
import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
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
const _seriesGameDayRotation = [
  GameDay.sunday,
  GameDay.tuesday,
  GameDay.thursday,
];

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
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
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
    final homeRoster = rostersByAbbreviation[homeAbbreviation]!;
    final awayRoster = rostersByAbbreviation[awayAbbreviation]!;

    final match = simulateMatch(
      random,
      homeRoster: homeRoster,
      awayRoster: awayRoster,
      // Same GM-bench-order-vs-automatic-ranking split as the regular
      // season (`season_advancer.dart`'s `_simulateOneGame`).
      homeTargetMinutes: homeAbbreviation == ownTeamAbbreviation
          ? targetMinutesForOrderedRoster(homeRoster)
          : null,
      awayTargetMinutes: awayAbbreviation == ownTeamAbbreviation
          ? targetMinutesForOrderedRoster(awayRoster)
          : null,
      homeCoach: coachesByAbbreviation?[homeAbbreviation],
      awayCoach: coachesByAbbreviation?[awayAbbreviation],
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
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
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
        ownTeamAbbreviation: ownTeamAbbreviation,
        coachesByAbbreviation: coachesByAbbreviation,
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
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
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
        ownTeamAbbreviation: ownTeamAbbreviation,
        coachesByAbbreviation: coachesByAbbreviation,
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
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
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
    ownTeamAbbreviation: ownTeamAbbreviation,
    coachesByAbbreviation: coachesByAbbreviation,
  );
}

/// The season's champion, derived from Finals (`postseasonRound` 3)
/// results in [playedGames] -- whichever team won more of those games.
/// `null` until the Finals have actually been played
/// (`simulatePostseason` always plays a series to its clinching game in
/// one shot, so there's no meaningful "partial" Finals state to worry
/// about here -- either it's unplayed, or it's decided).
String? seasonChampion(List<PlayedGame> playedGames) {
  final winsByTeam = <String, int>{};
  for (final game in playedGames) {
    if (game.game.postseasonRound != 3) continue;
    final winner = game.winningTeamAbbreviation;
    winsByTeam[winner] = (winsByTeam[winner] ?? 0) + 1;
  }
  if (winsByTeam.isEmpty) return null;
  return winsByTeam.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// One reconstructed postseason series -- who played, what actually
/// happened, and who won -- rebuilt from a season's persisted
/// [PlayedGame] history rather than carried forward from [SeriesResult]
/// (which is transient, gone the moment [simulatePostseason] returns).
/// [games] is empty for a series that hasn't been played yet -- a
/// projected matchup, not a gap.
class PostseasonSeriesView {
  const PostseasonSeriesView({
    required this.round,
    required this.higherSeedAbbreviation,
    required this.lowerSeedAbbreviation,
    required this.games,
  });

  final int round;
  final String higherSeedAbbreviation;
  final String lowerSeedAbbreviation;
  final List<PlayedGame> games;

  int get higherSeedWins => games
      .where((g) => g.winningTeamAbbreviation == higherSeedAbbreviation)
      .length;

  int get lowerSeedWins => games.length - higherSeedWins;

  /// `null` until the series actually has a winner -- games.isEmpty (not
  /// yet played) is the common case, but this also protects against ever
  /// reading a tied win count as a false winner.
  String? get winnerAbbreviation {
    if (games.isEmpty) return null;
    if (higherSeedWins == lowerSeedWins) return null;
    return higherSeedWins > lowerSeedWins
        ? higherSeedAbbreviation
        : lowerSeedAbbreviation;
  }
}

/// Rebuilds the full 3-round postseason bracket (First Round -> Semifinals
/// -> Finals) from [progress]'s persisted history, using the exact same
/// seeding/pairing rules [simulatePostseason] used to generate it in the
/// first place ([postseasonSeeds], then the fixed 1v8/2v7/3v6/4v5 ->
/// winners-cross bracket shape) -- so a series that hasn't been played yet
/// still shows up as a projected matchup, not a gap in the list. A later
/// round's list is empty until every series feeding into it has a winner
/// (mirrors [PostseasonSeriesView.games] being empty for an unplayed
/// series) -- `simulatePostseason` resolves the whole bracket in one
/// shot, so in practice this is either "nothing played yet" (every round
/// empty but the first) or "fully decided" (every round populated), not
/// something that lingers half-done.
///
/// `null` if the regular season hasn't produced a full 8-team seed field
/// yet ([postseasonSeeds]' own precondition) -- callers should gate this
/// on [SeasonProgress.isComplete] the same way the Dashboard's own
/// "Simulate Postseason" button does, rather than showing a seed
/// projection built on a still-developing standings table.
List<List<PostseasonSeriesView>>? reconstructPostseasonBracket(
  SeasonProgress progress, {
  required List<Team> leagueTeams,
}) {
  final standings = currentStandings(progress, leagueTeams);
  if (standings.length < kPostseasonTeamCount) return null;
  final seeds = postseasonSeeds(standings);

  List<PlayedGame> gamesFor(int round, String a, String b) {
    return [
      for (final played in progress.playedGames)
        if (played.game.type == GameType.postseason &&
            played.game.postseasonRound == round &&
            {
              played.game.homeTeamAbbreviation,
              played.game.awayTeamAbbreviation,
            }.containsAll({a, b}))
          played,
    ];
  }

  final round1Pairs = [
    (seeds[0], seeds[7]),
    (seeds[1], seeds[6]),
    (seeds[2], seeds[5]),
    (seeds[3], seeds[4]),
  ];
  final round1 = [
    for (final (higher, lower) in round1Pairs)
      PostseasonSeriesView(
        round: 1,
        higherSeedAbbreviation: higher,
        lowerSeedAbbreviation: lower,
        games: gamesFor(1, higher, lower),
      ),
  ];

  final round1Winners = [for (final s in round1) s.winnerAbbreviation];
  var round2 = <PostseasonSeriesView>[];
  if (round1Winners.every((w) => w != null)) {
    final round2Pairs = [
      (round1Winners[0]!, round1Winners[3]!),
      (round1Winners[1]!, round1Winners[2]!),
    ];
    round2 = [
      for (final (a, b) in round2Pairs)
        PostseasonSeriesView(
          round: 2,
          higherSeedAbbreviation: _betterSeed(a, b, seeds),
          lowerSeedAbbreviation: _worseSeed(a, b, seeds),
          games: gamesFor(2, a, b),
        ),
    ];
  }

  var round3 = <PostseasonSeriesView>[];
  final round2Winners = [for (final s in round2) s.winnerAbbreviation];
  if (round2.length == 2 && round2Winners.every((w) => w != null)) {
    final a = round2Winners[0]!;
    final b = round2Winners[1]!;
    round3 = [
      PostseasonSeriesView(
        round: 3,
        higherSeedAbbreviation: _betterSeed(a, b, seeds),
        lowerSeedAbbreviation: _worseSeed(a, b, seeds),
        games: gamesFor(3, a, b),
      ),
    ];
  }

  return [round1, round2, round3];
}
