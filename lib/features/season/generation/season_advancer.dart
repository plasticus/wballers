import 'dart:math';

import '../../match/engine/match_engine.dart';
import '../../match/engine/substitution_policy.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/season_schedule.dart';
import 'continental_cup_generator.dart';

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
/// [ownTeamAbbreviation], when given, marks whose roster order is a real,
/// GM-set bench order rather than arbitrary generation order -- that
/// team's target minutes come from [targetMinutesForOrderedRoster] (rank =
/// list position) instead of [simulateMatch]'s automatic overall-based
/// fallback every other team still uses. `null` (the default) leaves every
/// team on the automatic ranking, which is what every AI-only diagnostic
/// and most tests want.
///
/// Continental Cup Rounds 2-5 aren't part of the schedule at franchise
/// creation (each depends on the previous round's actual results), so
/// this function grows [SeasonProgress.schedule] itself the moment a
/// round finishes: every one of a Cup round's games is scheduled on the
/// same single game day (`season_schedule_generator.dart`), so finishing
/// that day always means the whole round just finished, and the next
/// round can be generated immediately -- see [_growContinentalCup]. The
/// postseason bracket still isn't folded in -- series play out over
/// several games apiece and a series' length isn't known ahead of time,
/// so it doesn't fit this same "one round, one game day" shape. That's
/// real follow-up work, not done here.
GameDayAdvance advanceToNextGameDay(
  Random random,
  SeasonProgress progress, {
  required Map<String, List<Player>> rostersByAbbreviation,
  String? ownTeamAbbreviation,
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
      _simulateOneGame(
        random,
        game,
        rostersByAbbreviation,
        ownTeamAbbreviation,
      ),
  ];

  final newlyPlayed = [
    for (final result in results)
      PlayedGame.fromResult(
        result,
        rostersByAbbreviation: rostersByAbbreviation,
      ),
  ];

  final grownSchedule = _growContinentalCup(random, progress.schedule, results);

  return GameDayAdvance(
    progress: progress.copyWithGameDayPlayed(
      newlyPlayed,
      updatedSchedule: grownSchedule,
    ),
    gamesPlayed: results,
  );
}

GameResult _simulateOneGame(
  Random random,
  ScheduledGame game,
  Map<String, List<Player>> rostersByAbbreviation,
  String? ownTeamAbbreviation,
) {
  final homeRoster = rostersByAbbreviation[game.homeTeamAbbreviation]!;
  final awayRoster = rostersByAbbreviation[game.awayTeamAbbreviation]!;
  final match = simulateMatch(
    random,
    homeRoster: homeRoster,
    awayRoster: awayRoster,
    // The GM's own roster (when it's playing) arrives here in their real
    // bench order (`rostersByAbbreviation` preserves `Franchise.roster`'s
    // list order) -- use it directly rather than letting `simulateMatch`
    // re-derive an overall-based ranking. AI teams have no GM-set order,
    // so they're left null and fall back to that default.
    homeTargetMinutes: game.homeTeamAbbreviation == ownTeamAbbreviation
        ? targetMinutesForOrderedRoster(homeRoster)
        : null,
    awayTargetMinutes: game.awayTeamAbbreviation == ownTeamAbbreviation
        ? targetMinutesForOrderedRoster(awayRoster)
        : null,
  );
  return GameResult(game: game, match: match);
}

/// If [todaysResults] just finished a Continental Cup round, generates
/// and appends the next one (idempotent: a no-op if that round's already
/// been generated, or if [todaysResults] finished Round 5 -- the
/// championship, nothing follows it). Round 2 needs Round 1's byes again
/// for Round 3, so [SeasonSchedule.continentalCupRound1Byes] gets set the
/// moment Round 2 is generated.
SeasonSchedule _growContinentalCup(
  Random random,
  SeasonSchedule schedule,
  List<GameResult> todaysResults,
) {
  final completedRounds = {
    for (final result in todaysResults)
      if (result.game.type == GameType.continentalCup)
        result.game.continentalCupRound!,
  };

  var updated = schedule;
  for (final round in completedRounds) {
    if (round >= 5) continue; // Round 5 is the championship.
    final alreadyGenerated = updated.games.any(
      (g) => g.continentalCupRound == round + 1,
    );
    if (alreadyGenerated) continue;

    final roundResults = [
      for (final result in todaysResults)
        if (result.game.continentalCupRound == round) result,
    ];

    switch (round) {
      case 1:
        final next = generateContinentalCupRound2(roundResults, random);
        updated = updated.copyWithAppendedGames(
          next.games,
          continentalCupRound1Byes: next.byeTeamAbbreviations,
        );
      case 2:
        final next = generateContinentalCupRound3(
          updated.continentalCupRound1Byes!,
          roundResults,
          random,
        );
        updated = updated.copyWithAppendedGames(next);
      case 3:
        final next = generateContinentalCupRound4(roundResults, random);
        updated = updated.copyWithAppendedGames(next);
      case 4:
        final next = generateContinentalCupRound5(roundResults, random);
        updated = updated.copyWithAppendedGames(next);
    }
  }
  return updated;
}
