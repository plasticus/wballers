import 'dart:math';

import '../../draft/domain/draft_in_progress.dart';
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
/// A real draft order is computed here too, from the *old* season's final
/// standings ([currentStandings] against [franchise.seasonProgress],
/// before it's replaced below) -- worst-record-first via the lottery,
/// same [generateDraftOrder] the preview screens already used, just
/// seeded off [kRealDraftOrderSeedOffset] instead of the preview-only
/// [kDraftOrderSeedOffset] so a save's real order can never shift because
/// some other screen's throwaway preview happened to roll differently.
/// [Franchise.draftInProgress] is set to a fresh, pick-less
/// [DraftInProgress] built from that order -- `draft_advancer.dart`'s
/// `resolveAiPicksUntilOwnTurn`/`makeOwnPick`/`finalizeDraft` are what
/// actually resolve it from here. Whatever [Franchise.pickOwnershipOverrides]
/// accumulated over the season that just ended (real draft-pick trades,
/// 2026-08-19) gets baked into that fresh [DraftInProgress] as a frozen
/// snapshot, then reset back to empty -- the new trade window starts
/// with nothing traded yet.
///
/// Also snapshots every current player's overall rating into
/// [Franchise.seasonStartOverallByPlayerId] -- taken right here, before
/// this new season's own training/aging ever runs, since that's the only
/// moment "this season's starting point" actually means anything.
/// `season_awards_advancer.dart`'s `resolveSeasonAwards` reads it back at
/// *this* season's own end to compute Most Improved Player. Fully
/// replaces the previous snapshot, same "last season's is stale" posture
/// [draftClass] already has.
///
/// [portraitWeights] is optional and threads straight through to both the
/// free-agent and draft-class generation, same "omit it, every new face
/// stays `null`" fallback every other generator in this codebase already
/// has -- this function has no async caller yet to load a manifest from,
/// so a future one (the "Begin Season 2" button, Presentation stage) is
/// expected to pass its own real weights through once it exists.
///
/// Still not done here, a separate, not-yet-built roadmap stage: no real
/// ceremony screen presents the awards `resolveSeasonAwards` grants --
/// `SeasonRecapScreen`'s "Begin Next Season" button calls straight
/// through to this with no fanfare in between ("Presentation").
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
  final finalStandings = currentStandings(
    franchise.seasonProgress,
    allLeagueTeams(franchise),
  );
  final draftOrder = generateDraftOrder(
    Random(newSeasonSeed + kRealDraftOrderSeedOffset),
    finalStandings,
  );
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
  final seasonStartSnapshot = <String, int>{
    for (final membership in franchise.roster)
      membership.player.id: membership.player.ratings.overall,
    for (final aiTeam in franchise.league.aiTeams)
      for (final membership in aiTeam.roster)
        membership.player.id: membership.player.ratings.overall,
  };

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
      .copyWithDraftClass(newDraftClass)
      .copyWithDraftInProgress(
        DraftInProgress(
          order: draftOrder,
          rounds: kDraftRounds,
          pickOwnershipOverrides: franchise.pickOwnershipOverrides,
        ),
      )
      .copyWithPickOwnershipOverrides(const {})
      .copyWithSeasonStartOverallByPlayerId(seasonStartSnapshot);
}
