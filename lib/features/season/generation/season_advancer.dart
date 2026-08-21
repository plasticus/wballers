import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../league/domain/team.dart';
import '../../match/domain/match_result.dart';
import '../../match/engine/match_engine.dart';
import '../../match/engine/substitution_policy.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/season_schedule.dart';
import 'continental_cup_generator.dart';
import 'postseason_generator.dart' show growPostseasonSchedule;

/// Seed offset for game-day advancement -- keeps this random stream from
/// correlating with the coach (0), starting roster (1), league draw (2),
/// league AI rosters (3), or season schedule (4) streams, same pattern as
/// those. Callers should combine this with [SeasonProgress.nextGameDayIndex]
/// (e.g. `Random(franchise.seasonSeed + kSeasonAdvanceSeedOffset + nextGameDayIndex)`
/// -- [Franchise.seasonSeed], not [Franchise.simulationSeed] directly, so a
/// second season's game day 0 doesn't reseed identically to the first's)
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
/// team referenced by a game on the advancing game day -- with one
/// exception: the All-Star week's 2 placeholder game days
/// (`all_star_generator.dart`) are silently skipped rather than crashing
/// if their synthetic rosters aren't present, so this still works for any
/// caller that doesn't know about the All-Star break at all. See
/// [_simulatable]'s own doc comment.
///
/// [ownTeamAbbreviation], when given, marks whose roster order is a real,
/// GM-set bench order rather than arbitrary generation order -- that
/// team's target minutes come from [targetMinutesForOrderedRoster] (rank =
/// list position) instead of [simulateMatch]'s automatic overall-based
/// fallback every other team still uses. `null` (the default) leaves every
/// team on the automatic ranking, which is what every AI-only diagnostic
/// and most tests want.
///
/// [coachesByAbbreviation], when given, feeds [simulateMatch]'s
/// `homeCoach`/`awayCoach` (the coach Offense-vs-Defense matchup,
/// TODO.md's coach-stats item) for every game this call simulates --
/// `null` (the default) leaves every game's coach bonus at 0, same
/// backward-compatible opt-in every other addition to this call chain
/// gets.
///
/// [ownDefenseTactic] (2026-08-14, a direct GM ask), when given, is the
/// GM's own picked [DefensiveTactic] for today -- applied only to
/// whichever side matches [ownTeamAbbreviation] in each of today's games;
/// every other side (every AI opponent, always) gets the literal
/// [DefensiveTactic.balanced], regardless of what's passed here. `null`
/// (the default) also resolves to Balanced for the GM's own side -- same
/// "AI always Balanced, no exception" behavior applies to a franchise
/// with no real pick made yet.
///
/// [ownGameAlreadyPlayed] (2026-08-18, `TODO.md` item 8's live-game
/// architecture stage 5 -- Watch Live), when given, is the GM's own
/// scheduled game's real, already-computed [MatchResult] -- watched live
/// beat by beat via `simulateMatchLive` on its own screen, rather than
/// bulk-simulated here. Whichever of today's games has [ownTeamAbbreviation]
/// on either side is resolved straight from this result instead of a fresh
/// `_simulateOneGame` call -- it doesn't consume from [random] at all, so
/// every other game this call still simulates draws from a different
/// position in the stream than an ordinary instant-sim advance would have
/// left them at. That's an accepted, one-time side effect of choosing
/// Watch Live for a given day, not a determinism bug: nothing about this
/// call's own reproducibility guarantee (a given day's `random` seed always
/// produces the same result for *that* call) changes -- see
/// `advanceGameDayWithOwnResult`'s own doc comment for why no save-schema
/// state needs to track which path a day took. `null` (the default, every
/// existing caller) leaves this function's behavior completely unchanged.
///
/// Continental Cup Rounds 2-5 aren't part of the schedule at franchise
/// creation (each depends on the previous round's actual results), so
/// this function grows [SeasonProgress.schedule] itself the moment a
/// round finishes: every one of a Cup round's games is scheduled on the
/// same single game day (`season_schedule_generator.dart`), so finishing
/// that day always means the whole round just finished, and the next
/// round can be generated immediately -- see [_growContinentalCup].
///
/// The postseason bracket (2026-08-20, a direct GM report: "it needs to
/// play all the games through the normal system") grows the exact same
/// way, just at finer grain -- a series plays 2-7 games depending on
/// results, so there's nothing to pre-schedule a whole round at a time
/// the way a single-elimination Cup round can. Instead, every call here
/// schedules at most one more real game day's worth of postseason games:
/// the next game for every series still alive, or (once a whole round
/// clinches) the next round's Game 1s -- see [growPostseasonSchedule].
/// [leagueTeams] is what that needs to compute standings/seeding; nothing
/// else in this function reads it.
GameDayAdvance advanceToNextGameDay(
  Random random,
  SeasonProgress progress, {
  required Map<String, List<Player>> rostersByAbbreviation,
  required List<Team> leagueTeams,
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
  DefensiveTactic? ownDefenseTactic,
  MatchResult? ownGameAlreadyPlayed,
  Map<String, Map<Player, double>>? injuryPenaltyByAbbreviation,
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
      if (ownGameAlreadyPlayed != null &&
          (game.homeTeamAbbreviation == ownTeamAbbreviation ||
              game.awayTeamAbbreviation == ownTeamAbbreviation))
        GameResult(game: game, match: ownGameAlreadyPlayed)
      else if (_simulatable(game, rostersByAbbreviation))
        _simulateOneGame(
          random,
          game,
          rostersByAbbreviation,
          ownTeamAbbreviation,
          coachesByAbbreviation,
          ownDefenseTactic,
          injuryPenaltyByAbbreviation,
        ),
  ];

  final newlyPlayed = [
    for (final result in results)
      PlayedGame.fromResult(
        result,
        rostersByAbbreviation: rostersByAbbreviation,
      ),
  ];

  final cupGrownSchedule = _growContinentalCup(
    random,
    progress.schedule,
    results,
  );
  // Postseason growth needs to see *today's* results already folded in --
  // both the played-game history (for bracket reconstruction) and the
  // advanced index (to know whether the regular season just genuinely
  // ran out of scheduled days) -- so this is built against a progress
  // snapshot that already reflects today, not the one this call started
  // with.
  final progressAfterToday = SeasonProgress(
    schedule: cupGrownSchedule,
    playedGames: [...progress.playedGames, ...newlyPlayed],
    nextGameDayIndex: progress.nextGameDayIndex + 1,
  );
  final postseasonAdditions = growPostseasonSchedule(
    progressAfterToday,
    leagueTeams: leagueTeams,
  );
  final grownSchedule = postseasonAdditions.isEmpty
      ? cupGrownSchedule
      : cupGrownSchedule.copyWithAppendedGames(postseasonAdditions);

  return GameDayAdvance(
    progress: progress.copyWithGameDayPlayed(
      newlyPlayed,
      updatedSchedule: grownSchedule,
    ),
    gamesPlayed: results,
  );
}

/// [GameType.skillsCompetition] never goes through the match engine at
/// all (it isn't a team-vs-team game -- `all_star_generator.dart`'s own
/// doc comment on why it still gets a placeholder [ScheduledGame]) --
/// always skipped here, resolved separately by
/// `all_star_advancer.dart`'s `resolveSkillsCompetitionDay`, called
/// alongside this function rather than from inside it (that function
/// needs conference/position data this one was never given).
///
/// [GameType.allStarGame] *can* go through the match engine -- two real
/// rosters, same as any other game -- but only once a caller has actually
/// built and injected the 2 synthetic conference squads into
/// [rostersByAbbreviation] (`resolveAllStarGame`'s job, not this
/// function's). Skipped gracefully rather than crashing on a missing-key
/// lookup when they haven't been -- every existing "play out a whole
/// season" test helper predates the All-Star break and has no reason to
/// know about it; this keeps the schedule's one new week from being a
/// breaking change for any of them, at the cost of a caller that *wants*
/// a real All-Star Game needing to inject those rosters itself.
bool _simulatable(
  ScheduledGame game,
  Map<String, List<Player>> rostersByAbbreviation,
) {
  if (game.type == GameType.skillsCompetition) return false;
  return rostersByAbbreviation.containsKey(game.homeTeamAbbreviation) &&
      rostersByAbbreviation.containsKey(game.awayTeamAbbreviation);
}

GameResult _simulateOneGame(
  Random random,
  ScheduledGame game,
  Map<String, List<Player>> rostersByAbbreviation,
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
  DefensiveTactic? ownDefenseTactic,
  Map<String, Map<Player, double>>? injuryPenaltyByAbbreviation,
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
        : targetMinutesFor(
            homeRoster,
            teamAbbreviation: game.homeTeamAbbreviation,
          ),
    homeCoach: coachesByAbbreviation?[game.homeTeamAbbreviation],
    awayCoach: coachesByAbbreviation?[game.awayTeamAbbreviation],
    awayTargetMinutes: game.awayTeamAbbreviation == ownTeamAbbreviation
        ? targetMinutesForOrderedRoster(awayRoster)
        : targetMinutesFor(
            awayRoster,
            teamAbbreviation: game.awayTeamAbbreviation,
          ),
    // Only the GM's own team ever plays anything but Balanced -- every AI
    // opponent gets the literal default, always, "AI always plays
    // Balanced" with no separate decision logic anywhere.
    homeDefenseTactic: game.homeTeamAbbreviation == ownTeamAbbreviation
        ? (ownDefenseTactic ?? DefensiveTactic.balanced)
        : DefensiveTactic.balanced,
    awayDefenseTactic: game.awayTeamAbbreviation == ownTeamAbbreviation
        ? (ownDefenseTactic ?? DefensiveTactic.balanced)
        : DefensiveTactic.balanced,
    // Both sides' current injury penalties, merged into the one combined
    // map `simulateMatch` expects (2026-08-20, `injury_advancer.dart`) --
    // `null` (every existing caller, and any team with nobody hurt) reads
    // as "nobody injured," same opt-in-only posture as every other bonus
    // here.
    injuryPenalty: {
      ...?injuryPenaltyByAbbreviation?[game.homeTeamAbbreviation],
      ...?injuryPenaltyByAbbreviation?[game.awayTeamAbbreviation],
    },
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
