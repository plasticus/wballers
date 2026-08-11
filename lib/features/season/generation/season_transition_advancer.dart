import 'dart:math';

import '../../draft/generation/draft_generator.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../roster/generation/free_agent_pool_generator.dart';
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
/// `0D_Season_2_Roadmap.md`'s Foundation stage), a clean [SeasonProgress]
/// with nothing played yet, a fresh batch of free agents added to
/// whatever's already unsigned in the pool (roster-legality waives from
/// the season that just ended included -- never discarded just because a
/// new season started), and a brand-new, fully-replacing draft class
/// (Player pool refresh stage).
///
/// [Franchise.roster]/[Franchise.league] rosters themselves aren't
/// touched here at all -- aging, decline, retirement, and roster-legality
/// enforcement all already happened earlier, at the *previous* season's
/// own postseason-end hook (`current_franchise_provider.dart`'s
/// `simulatePostseasonAndPersist`, Aging & roster churn stage), not here.
/// This function is specifically the "start of the new season" half, not
/// the "wrap up the old one" half.
///
/// [portraitWeights] is optional and threads straight through to both the
/// free-agent and draft-class generation, same "omit it, every new face
/// stays `null`" fallback every other generator in this codebase already
/// has -- this function has no async caller yet to load a manifest from,
/// so a future one (the "Begin Season 2" button, Presentation stage) is
/// expected to pass its own real weights through once it exists.
///
/// Still not done here, each one a separate, not-yet-built roadmap stage:
/// - No real draft-day flow -- [Franchise.draftClass] is real, persisted
///   prospects now, but nothing lets a GM (or the 19 AI teams) actually
///   spend a pick and land one on a roster yet ("The draft, for real").
/// - No ceremony, no awards granted, no "Begin Season 2" button anywhere
///   in the UI yet -- this function has no caller at all outside its own
///   tests right now ("Presentation"). Wiring a real button before that
///   stage exists would let a GM start a new season with last season's
///   draft class just sitting there, never actually drafted from.
///
/// Asserts [seasonIsOver] -- starting a new season before the old one's
/// postseason has actually resolved would silently discard whatever's
/// left of it.
Franchise beginNextSeason(
  Franchise franchise, {
  PortraitWeights? portraitWeights,
}) {
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
  final freshFreeAgents = generateFreeAgentPool(
    Random(newSeasonSeed + kFreeAgentPoolSeedOffset),
    portraitWeights: portraitWeights,
  );
  final newDraftClass = generateDraftClass(
    Random(newSeasonSeed + kDraftClassSeedOffset),
    portraitWeights: portraitWeights,
  );

  return franchise
      .copyWithNewSeason(
        newSeason: newSeason,
        newSeasonProgress: SeasonProgress(
          schedule: newSchedule,
          playedGames: const [],
          nextGameDayIndex: 0,
        ),
      )
      .copyWithFreeAgents([...franchise.freeAgents, ...freshFreeAgents])
      .copyWithDraftClass(newDraftClass);
}
