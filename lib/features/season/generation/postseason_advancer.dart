import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import 'postseason_generator.dart';

/// Seed offset for postseason simulation -- keeps this random stream from
/// correlating with any other (coach=0, roster=1, league draw=2, league
/// AI rosters=3, season schedule=4, game-day advancement=5). The
/// postseason runs exactly once per season (guarded by
/// [simulatePostseason]'s idempotency check), so unlike game-day
/// advancement this doesn't need a per-call index folded in too.
const kPostseasonAdvanceSeedOffset = 6;

/// What the postseason produced: the updated [SeasonProgress] (postseason
/// games folded into [SeasonProgress.playedGames]/`schedule`, same lean
/// [PlayedGame] shape as every other game) and the full [GameResult]s for
/// every series game played, box scores included -- same "here's your
/// one transient window before only the lean record survives" deal as
/// `GameDayAdvance.gamesPlayed`.
class PostseasonAdvance {
  const PostseasonAdvance({required this.progress, required this.gamesPlayed});

  final SeasonProgress progress;
  final List<GameResult> gamesPlayed;
}

/// Runs the *entire* postseason bracket in one call: seeds the top 8 from
/// [progress]'s final regular-season standings (`postseasonSeeds`), then
/// simulates the First Round (best-of-3), Semifinals (best-of-5), and
/// Finals (best-of-7) back to back against one continuing [random]
/// stream. Every series game becomes a real [ScheduledGame] (folded into
/// `SeasonProgress.schedule`) and a lean [PlayedGame] (folded into
/// `SeasonProgress.playedGames`) -- same shape as every other game, so
/// `computeStandings`, box scores, etc. all just work on postseason games
/// too, even though [computeStandings] itself only counts regular-season
/// ones.
///
/// Deliberately *not* folded into `advanceToNextGameDay`'s day-by-day
/// model the way Continental Cup rounds are: a series plays 2-7 games
/// depending on results, so there's nothing to pre-schedule one game day
/// at a time the way a single-elimination Cup round can be -- the whole
/// bracket has to resolve in one shot once seeding is possible. Callers
/// should only invoke this once [SeasonProgress.isComplete] is true (i.e.
/// there's no day-by-day advancing left to do), since seeding needs final
/// regular-season standings.
///
/// Idempotent: a no-op (returns [progress] unchanged, [gamesPlayed]
/// empty) if the postseason has already been played -- detected by
/// whether [SeasonProgress.schedule] already has any [GameType.postseason]
/// game, same guard style `_growContinentalCup` uses for Cup rounds.
PostseasonAdvance simulatePostseason(
  Random random,
  SeasonProgress progress, {
  required List<Team> leagueTeams,
  required Map<String, List<Player>> rostersByAbbreviation,
  String? ownTeamAbbreviation,
  Map<String, Coach>? coachesByAbbreviation,
}) {
  if (progress.schedule.games.any((g) => g.type == GameType.postseason)) {
    return PostseasonAdvance(progress: progress, gamesPlayed: const []);
  }

  final standings = currentStandings(progress, leagueTeams);
  final seeds = postseasonSeeds(standings);

  final firstRound = generatePostseasonFirstRound(
    random,
    seeds: seeds,
    rostersByAbbreviation: rostersByAbbreviation,
    ownTeamAbbreviation: ownTeamAbbreviation,
    coachesByAbbreviation: coachesByAbbreviation,
  );
  final semifinals = generatePostseasonSemifinals(
    random,
    firstRoundResults: firstRound,
    seeds: seeds,
    rostersByAbbreviation: rostersByAbbreviation,
    ownTeamAbbreviation: ownTeamAbbreviation,
    coachesByAbbreviation: coachesByAbbreviation,
  );
  final finals = generatePostseasonFinals(
    random,
    semifinalResults: semifinals,
    seeds: seeds,
    rostersByAbbreviation: rostersByAbbreviation,
    ownTeamAbbreviation: ownTeamAbbreviation,
    coachesByAbbreviation: coachesByAbbreviation,
  );

  final results = [
    for (final series in firstRound) ...series.games,
    for (final series in semifinals) ...series.games,
    ...finals.games,
  ];

  final newlyPlayed = [
    for (final result in results)
      PlayedGame.fromResult(
        result,
        rostersByAbbreviation: rostersByAbbreviation,
      ),
  ];

  final grownSchedule = progress.schedule.copyWithAppendedGames([
    for (final result in results) result.game,
  ]);

  return PostseasonAdvance(
    progress: SeasonProgress(
      schedule: grownSchedule,
      playedGames: [...progress.playedGames, ...newlyPlayed],
      // Every newly-appended game's (week, day) is now "played" too --
      // without this, gameDaysInOrder would grow to include the
      // postseason's own weeks and isComplete would flip back to false,
      // inviting a caller to "advance" straight into re-simulating the
      // postseason it just ran.
      nextGameDayIndex: gameDaysInOrder(grownSchedule).length,
    ),
    gamesPlayed: results,
  );
}
