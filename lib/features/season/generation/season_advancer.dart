import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';

/// Simulates every game scheduled for [SeasonProgress.nextGameDayIndex]
/// (via `simulateMatch`, one continuing [random] stream) and returns
/// updated progress with those games appended and the pointer moved to
/// the following game day.
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
/// Team-agnostic: the GM's own game gets no special treatment here, same
/// as every other -- this is the "background-sim everyone" building
/// block `0B_Planned.md`'s Option B calls for, not the eventual "GM plays
/// through their own game" flow, which is a distinct, not-yet-built layer
/// on top of this.
///
/// [rostersByAbbreviation] must have a full 12-player roster for every
/// team referenced by a game on the advancing game day.
///
/// Only covers whatever's already in [SeasonProgress.schedule] (preseason,
/// regular season, Continental Cup Round 1) -- Continental Cup Rounds 2-5
/// and the postseason bracket depend on results this function produces,
/// but aren't generated or folded back into the schedule by this function
/// yet. That's real follow-up work, not done here.
SeasonProgress advanceToNextGameDay(
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

  final newlyPlayed = [
    for (final game in todaysGames)
      _simulateOneGame(random, game, rostersByAbbreviation),
  ];

  return progress.copyWithGameDayPlayed(newlyPlayed);
}

PlayedGame _simulateOneGame(
  Random random,
  ScheduledGame game,
  Map<String, List<Player>> rostersByAbbreviation,
) {
  final match = simulateMatch(
    random,
    homeRoster: rostersByAbbreviation[game.homeTeamAbbreviation]!,
    awayRoster: rostersByAbbreviation[game.awayTeamAbbreviation]!,
  );
  return PlayedGame(
    game: game,
    homeScore: match.homeScore,
    awayScore: match.awayScore,
  );
}
