import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../player/domain/player.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';

/// Simulates every game scheduled for [SeasonProgress.nextWeek] (via
/// `simulateMatch`, one continuing [random] stream) and returns updated
/// progress with those games appended and the pointer moved to the
/// following week. A week with nothing scheduled (a bye week, or a week
/// beyond what's been generated yet -- see the note below) just advances
/// the pointer with nothing played.
///
/// Team-agnostic: the GM's own game gets no special treatment here, same
/// as every other -- this is the "background-sim everyone" building
/// block `0B_Planned.md`'s Option B calls for, not the eventual "GM plays
/// through their own game" flow, which is a distinct, not-yet-built layer
/// on top of this.
///
/// [rostersByAbbreviation] must have a full 12-player roster for every
/// team referenced by a game in the advancing week.
///
/// Only covers whatever's already in [SeasonProgress.schedule] (preseason,
/// regular season, Continental Cup Round 1) -- Continental Cup Rounds 2-5
/// and the postseason bracket depend on results this function produces,
/// but aren't generated or folded back into the schedule by this function
/// yet. That's real follow-up work, not done here.
SeasonProgress advanceOneWeek(
  Random random,
  SeasonProgress progress, {
  required Map<String, List<Player>> rostersByAbbreviation,
}) {
  final weekGames = progress.schedule.games
      .where((game) => game.week == progress.nextWeek)
      .toList();

  final newlyPlayed = [
    for (final game in weekGames)
      _simulateOneGame(random, game, rostersByAbbreviation),
  ];

  return progress.copyWithWeekPlayed(newlyPlayed);
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
