import '../../league/domain/team.dart';
import '../domain/game_day.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/season_schedule.dart';
import '../domain/standings_entry.dart';
import 'season_schedule_generator.dart';

/// The 3-day rotation a postseason game day cycles through --
/// `0B_Planned.md`'s tentative postseason-only Tuesday addition, for a
/// 3-games/week pace. [_nextPostseasonSlot] uses this to pick each new
/// game day's real (week, day) slot, rolling into the following week once
/// a week's 3 slots are used -- unlike the fixed-rotation-by-game-index
/// scheme this replaced, every slot is now a genuinely unique schedule
/// entry, same as any other [ScheduledGame].
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
/// to clinch never get consulted, since [growPostseasonSchedule] stops
/// scheduling a series the moment it has a winner.
List<bool> _homeAwayPattern(int winsNeeded) {
  return switch (winsNeeded) {
    2 => const [true, true, false],
    3 => const [true, true, false, false, true],
    4 => const [true, true, false, false, true, false, true],
    _ => throw ArgumentError('unsupported winsNeeded: $winsNeeded'),
  };
}

/// Whichever of [a]/[b] has the better (lower-numbered) seed in [seeds].
String _betterSeed(String a, String b, List<String> seeds) =>
    seeds.indexOf(a) < seeds.indexOf(b) ? a : b;

String _worseSeed(String a, String b, List<String> seeds) =>
    seeds.indexOf(a) < seeds.indexOf(b) ? b : a;

/// The [ScheduledGame]s [growPostseasonSchedule] should append to the
/// schedule right now, or an empty list if there's nothing new to add yet
/// (`0B_Planned.md`'s postseason design finally gets the same day-by-day
/// treatment the Continental Cup already has -- 2026-08-20, a direct GM
/// report: "I'd be so upset if I was in the postseason, and it just...
/// simmed all my games... it needs to play all the games through the
/// normal system"). Deliberately *not* a full round at a time the way the
/// old bulk `simulatePostseason` generated one -- a series' length isn't
/// known ahead of time, so this only ever schedules the *next* real game
/// day's slate: one more game for every series still alive, or (once a
/// whole round clinches) the next round's Game 1s.
///
/// Pure and deterministic -- no [Random] needed. Seeding/pairing has
/// always been a deterministic function of final standings; only game
/// *outcomes* need randomness, and those are rolled the normal way by
/// whichever caller feeds the returned games through `simulateMatch`
/// (`season_advancer.dart`'s `_simulateOneGame`), same as every other
/// game type.
///
/// Called from `season_advancer.dart`'s `advanceToNextGameDay` right
/// after a game day's results are folded into [progress] -- so
/// [progress] here must already reflect *today's* results (both
/// [SeasonProgress.playedGames] and [SeasonProgress.nextGameDayIndex]),
/// not the state from before today's games. Returns an empty list once
/// the Finals are decided -- nothing left to ever schedule.
List<ScheduledGame> growPostseasonSchedule(
  SeasonProgress progress, {
  required List<Team> leagueTeams,
}) {
  final hasPostseasonGame = progress.schedule.games.any(
    (g) => g.type == GameType.postseason,
  );

  if (!hasPostseasonGame) {
    // Only kick the postseason off once there's genuinely nothing else
    // left on the calendar to advance to -- the regular season, every
    // Continental Cup round, and the All-Star break are all done.
    if (progress.nextGameDayIndex < gameDaysInOrder(progress.schedule).length) {
      return const [];
    }
    final standings = currentStandings(progress, leagueTeams);
    if (standings.length < kPostseasonTeamCount) return const [];
    final seeds = postseasonSeeds(standings);
    final matchups = [
      (seeds[0], seeds[7]),
      (seeds[1], seeds[6]),
      (seeds[2], seeds[5]),
      (seeds[3], seeds[4]),
    ];
    return [
      for (final (higher, lower) in matchups)
        ScheduledGame(
          week: kPostseasonFirstRoundWeek,
          day: GameDay.sunday,
          homeTeamAbbreviation: higher,
          awayTeamAbbreviation: lower,
          type: GameType.postseason,
          postseasonRound: 1,
        ),
    ];
  }

  final bracket = reconstructPostseasonBracket(
    progress,
    leagueTeams: leagueTeams,
  )!;

  for (final (seriesList, winsNeeded, round) in [
    (bracket[0], _firstRoundWinsNeeded, 1),
    (bracket[1], _semifinalsWinsNeeded, 2),
    (bracket[2], _finalsWinsNeeded, 3),
  ]) {
    final alive = [
      for (final series in seriesList)
        if (series.winnerAbbreviation == null) series,
    ];
    // Empty means either "this round isn't reachable yet" (an earlier
    // round is still alive -- an earlier iteration of this loop already
    // returned) or "every series in this round is already decided" --
    // either way, nothing to schedule here, move on to the next round.
    if (alive.isEmpty) continue;

    final pattern = _homeAwayPattern(winsNeeded);
    final slot = _nextPostseasonSlot(progress.schedule);
    return [
      for (final series in alive)
        ScheduledGame(
          week: slot.$1,
          day: slot.$2,
          homeTeamAbbreviation: pattern[series.games.length]
              ? series.higherSeedAbbreviation
              : series.lowerSeedAbbreviation,
          awayTeamAbbreviation: pattern[series.games.length]
              ? series.lowerSeedAbbreviation
              : series.higherSeedAbbreviation,
          type: GameType.postseason,
          postseasonRound: round,
        ),
    ];
  }

  // Every round's every series is decided -- the Finals are over.
  return const [];
}

/// The (week, day) [growPostseasonSchedule] should schedule its next
/// slate of games on -- one slot past the latest [GameType.postseason]
/// game already in [schedule], cycling through
/// [_seriesGameDayRotation] and rolling into the following week once a
/// week's 3 slots are used. Multiple series (every series still alive in
/// the current round) share the same slot, same as real playoff
/// basketball often has more than one series playing the same night.
(int, GameDay) _nextPostseasonSlot(SeasonSchedule schedule) {
  final postseasonDays =
      {
        for (final game in schedule.games)
          if (game.type == GameType.postseason) (game.week, game.day),
      }.toList()..sort((a, b) {
        final byWeek = a.$1.compareTo(b.$1);
        if (byWeek != 0) return byWeek;
        return a.$2.index.compareTo(b.$2.index);
      });
  assert(
    postseasonDays.isNotEmpty,
    'only called once the postseason has already started',
  );
  final (lastWeek, lastDay) = postseasonDays.last;
  final rotationIndex = _seriesGameDayRotation.indexOf(lastDay);
  if (rotationIndex < _seriesGameDayRotation.length - 1) {
    return (lastWeek, _seriesGameDayRotation[rotationIndex + 1]);
  }
  return (lastWeek + 1, _seriesGameDayRotation[0]);
}

/// The season's champion, derived from Finals (`postseasonRound` 3)
/// results in [playedGames] -- whichever team has actually reached
/// [_finalsWinsNeeded] wins, `null` otherwise. Checking for the real
/// clinching threshold (not just "leads in win count so far") matters now
/// that a still-alive, partway-through Finals series is a genuinely
/// reachable state (`growPostseasonSchedule` plays it out one real game
/// day at a time) -- a 2-1 series lead used to be impossible to observe
/// here at all, back when the old bulk `simulatePostseason` always
/// resolved the Finals to a clinching game before this was ever called.
String? seasonChampion(List<PlayedGame> playedGames) {
  final winsByTeam = <String, int>{};
  for (final game in playedGames) {
    if (game.game.postseasonRound != 3) continue;
    final winner = game.winningTeamAbbreviation;
    winsByTeam[winner] = (winsByTeam[winner] ?? 0) + 1;
  }
  for (final entry in winsByTeam.entries) {
    if (entry.value >= _finalsWinsNeeded) return entry.key;
  }
  return null;
}

/// One reconstructed postseason series -- who played, what actually
/// happened, and who won -- rebuilt from a season's persisted
/// [PlayedGame] history, the only place this state actually lives (a
/// series plays out across many real `advanceGameDay` calls, so there's
/// no in-memory "series in progress" object to carry forward between
/// them). [games] is empty for a series that hasn't been played yet -- a
/// projected matchup, not a gap -- and can hold anywhere from 0 games up
/// to a full series' worth while play is ongoing.
class PostseasonSeriesView {
  const PostseasonSeriesView({
    required this.round,
    required this.higherSeedAbbreviation,
    required this.lowerSeedAbbreviation,
    required this.games,
    required this.winsNeeded,
  });

  final int round;
  final String higherSeedAbbreviation;
  final String lowerSeedAbbreviation;
  final List<PlayedGame> games;

  /// How many wins actually clinches this series -- 2/3/4 for best-of-3/5/7
  /// (`_firstRoundWinsNeeded`/`_semifinalsWinsNeeded`/`_finalsWinsNeeded`).
  /// [winnerAbbreviation] checks against this real threshold, not just
  /// "leads in win count so far" -- a real bug caught by this file's own
  /// test suite (2026-08-20): a 1-0 series lead used to read as a decided
  /// series outright, which would have made `growPostseasonSchedule` treat
  /// every series as over the moment its first game finished.
  final int winsNeeded;

  int get higherSeedWins => games
      .where((g) => g.winningTeamAbbreviation == higherSeedAbbreviation)
      .length;

  int get lowerSeedWins => games.length - higherSeedWins;

  /// `null` until a side has actually reached [winsNeeded] -- a still-alive
  /// mid-series lead (e.g. 2-1 in a best-of-5) correctly reads as `null`
  /// too, not just an empty [games] list.
  String? get winnerAbbreviation {
    if (higherSeedWins >= winsNeeded) return higherSeedAbbreviation;
    if (lowerSeedWins >= winsNeeded) return lowerSeedAbbreviation;
    return null;
  }
}

/// Rebuilds the full 3-round postseason bracket (First Round -> Semifinals
/// -> Finals) from [progress]'s persisted history, using the exact same
/// seeding/pairing rules [growPostseasonSchedule] used to schedule it in
/// the first place ([postseasonSeeds], then the fixed 1v8/2v7/3v6/4v5 ->
/// winners-cross bracket shape) -- so a series that hasn't been played yet
/// still shows up as a projected matchup, not a gap in the list. A later
/// round's list is empty until every series feeding into it has a winner
/// (mirrors [PostseasonSeriesView.games] being empty for an unplayed
/// series) -- since the postseason now plays out one real game day at a
/// time, this is a genuinely live, evolving picture: a round can linger
/// with some series decided and others still mid-series for as long as
/// that round takes to fully resolve, not just "nothing yet" or "fully
/// decided."
///
/// `null` if the regular season hasn't produced a full 8-team seed field
/// yet ([postseasonSeeds]' own precondition) -- callers should check for
/// this rather than assuming a seed projection built on a still-developing
/// standings table.
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
        winsNeeded: _firstRoundWinsNeeded,
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
          winsNeeded: _semifinalsWinsNeeded,
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
        winsNeeded: _finalsWinsNeeded,
      ),
    ];
  }

  return [round1, round2, round3];
}
