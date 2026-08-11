import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../application/franchise_rosters.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import 'season_schedule_generator.dart';

/// Whether [franchise]'s current season is genuinely done -- the regular
/// season's own pre-generated schedule fully played out
/// ([SeasonProgress.isComplete]) *and* the postseason bracket has
/// actually been simulated (`simulatePostseason`'s own idempotency check
/// uses this same "does a postseason game exist yet" test). Both are
/// needed: `isComplete` alone goes true the moment the regular season
/// wraps, well before `simulatePostseasonAndPersist` ever runs.
bool seasonIsOver(Franchise franchise) {
  return franchise.seasonProgress.isComplete &&
      franchise.seasonProgress.schedule.games.any(
        (g) => g.type == GameType.postseason,
      );
}

/// Transitions [franchise] into its next season: a freshly generated
/// schedule (`generateSeasonSchedule`, seeded off the *new* season's own
/// [Franchise.seasonSeed] slice so it doesn't just replay the old one --
/// `0D_Season_2_Roadmap.md`'s Foundation item 2) and a clean
/// [SeasonProgress] with nothing played yet.
///
/// Deliberately the *Foundation*-scoped version of "begin Season 2," not
/// the finished thing -- see `0D_Season_2_Roadmap.md`. Everything below
/// is explicitly **not** done here, each one a separate, not-yet-built
/// roadmap stage:
/// - No aging, no `Player.age`/`yearsOfService` increments, no
///   retirement -- every player carries over exactly as they were
///   ("Aging & churn").
/// - No roster-legality enforcement -- an illegal roster carries over
///   illegal ("Aging & churn").
/// - No free-agent pool refresh, no new draft class ("Player pool
///   refresh").
/// - No real draft -- last season's draft order/prospects (if any were
///   ever persisted) aren't touched, because nothing persists them yet
///   ("The draft, for real").
/// - No ceremony, no awards granted, no "Begin Season 2" button anywhere
///   in the UI yet -- this function has no caller at all outside its own
///   tests right now ("Presentation"). Wiring a real button before the
///   stages above exist would let a GM start a new season with an
///   illegal, unaged, stale-free-agent-pool roster -- actively worse
///   than not offering the button at all.
///
/// Asserts [seasonIsOver] -- starting a new season before the old one's
/// postseason has actually resolved would silently discard whatever's
/// left of it.
Franchise beginNextSeason(Franchise franchise) {
  assert(
    seasonIsOver(franchise),
    'beginNextSeason called before the current season\'s postseason '
    'resolved',
  );

  final newSeason = franchise.season + 1;
  final newSeasonSeed = franchise.simulationSeed + newSeason * kSeasonSeedSpan;
  final newSchedule = generateSeasonSchedule(
    allLeagueTeams(franchise),
    Random(newSeasonSeed + kSeasonScheduleSeedOffset),
  );

  return franchise.copyWithNewSeason(
    newSeason: newSeason,
    newSeasonProgress: SeasonProgress(
      schedule: newSchedule,
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
  );
}
