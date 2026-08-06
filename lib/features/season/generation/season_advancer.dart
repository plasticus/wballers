import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';

/// Seed offset for game-day advancement -- keeps this random stream from
/// correlating with the coach (0), starting roster (1), league draw (2),
/// league AI rosters (3), or season schedule (4) streams, same pattern as
/// those. Callers should combine this with [SeasonProgress.nextGameDayIndex]
/// (e.g. `Random(simulationSeed + kSeasonAdvanceSeedOffset + nextGameDayIndex)`)
/// rather than reusing one long-lived [Random] across app sessions --
/// there's no way to persist a [Random]'s internal state between saves, so
/// keying off the already-persisted game-day index is what makes each
/// game day's result reproducible across a save/reload without a
/// dedicated stream to carry forward.
const kSeasonAdvanceSeedOffset = 5;

/// What advancing one game day produced: the updated [SeasonProgress]
/// (what actually gets persisted -- lean [PlayedGame]s only) and the full
/// [GameResult]s for that game day's games, box score and all. The lean
/// persistence decision (`played_game.dart`) means a full [GameResult]
/// only exists transiently, right when it's simulated -- this is that
/// window, for whoever calls [advanceToNextGameDay] to do something with
/// before it's gone (e.g. show the GM's own game's box score instead of
/// just letting it disappear into the standings like every other team's).
class GameDayAdvance {
  const GameDayAdvance({required this.progress, required this.gamesPlayed});

  final SeasonProgress progress;
  final List<GameResult> gamesPlayed;
}

/// Simulates every game scheduled for [SeasonProgress.nextGameDayIndex]
/// (via `simulateMatch`, one continuing [random] stream) and returns the
/// updated progress (with those games appended, as lean [PlayedGame]s,
/// and the pointer moved to the following game day) alongside the full
/// [GameResult]s for the game day just played.
///
/// Advances by game day, not by week: `0B_Planned.md`'s declared game
/// days (Sunday and Thursday in the regular season/Continental Cup,
/// +Tuesday in the postseason) mean a single week can hold 2-3 separate
/// game days, each with its own slate. A week-at-a-time "Advance Week"
/// action would blow right past individual game days the GM might want
/// to play through one at a time -- this is the finer-grained building
/// block that supports that instead. Because [SeasonProgress.nextGameDayIndex]
/// indexes `gameDaysInOrder`, which only lists (week, day) combinations
/// that actually have a game, there's no such thing as an "empty"
/// advance -- every call plays at least one game, until the season is
/// done (see [SeasonProgress.isComplete]).
///
/// Team-agnostic: every team's game is simulated the same way here --
/// this is the "background-sim everyone" building block `0B_Planned.md`'s
/// Option B calls for. Giving the GM's own game special treatment (a real
/// play-through rather than an instantly-resolved sim) is a caller
/// concern -- see [GameDayAdvance.gamesPlayed] -- not something this
/// function itself does differently.
///
/// [rostersByAbbreviation] must have a full 12-player roster for every
/// team referenced by a game on the advancing game day.
///
/// Only covers whatever's already in [SeasonProgress.schedule] (preseason,
/// regular season, Continental Cup Round 1) -- Continental Cup Rounds 2-5
/// and the postseason bracket depend on results this function produces,
/// but aren't generated or folded back into the schedule by this function
/// yet. That's real follow-up work, not done here.
GameDayAdvance advanceToNextGameDay(
  Random random,
  SeasonProgress progress, {
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  final gameDays = gameDaysInOrder(progress.schedule);
  assert(
    progress.nextGameDayIndex < gameDays.length,
    'the season is already complete -- nothing left to advance to',
  );
  final (week, day) = gameDays[progress.nextGameDayIndex];
  final todaysGames = progress.schedule.games
      .where((game) => game.week == week && game.day == day)
      .toList();

  final results = [
    for (final game in todaysGames)
      _simulateOneGame(random, game, rostersByAbbreviation),
  ];

  final newlyPlayed = [
    for (final result in results)
      PlayedGame(
        game: result.game,
        homeScore: result.match.homeScore,
        awayScore: result.match.awayScore,
      ),
  ];

  return GameDayAdvance(
    progress: progress.copyWithGameDayPlayed(newlyPlayed),
    gamesPlayed: results,
  );
}

GameResult _simulateOneGame(
  Random random,
  ScheduledGame game,
  Map<String, List<Player>> rostersByAbbreviation,
) {
  final match = simulateMatch(
    random,
    homeRoster: rostersByAbbreviation[game.homeTeamAbbreviation]!,
    awayRoster: rostersByAbbreviation[game.awayTeamAbbreviation]!,
  );
  return GameResult(game: game, match: match);
}
