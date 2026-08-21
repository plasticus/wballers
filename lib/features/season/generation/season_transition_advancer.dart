import 'dart:math';

import '../../draft/domain/draft_in_progress.dart';
import '../../draft/generation/draft_generator.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../roster/generation/free_agent_pool_generator.dart';
import '../../trade/domain/pick_ownership.dart';
import '../application/franchise_rosters.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../domain/standings_entry.dart';
import 'postseason_generator.dart' show seasonChampion;
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
/// (Player pool refresh stage) -- promoted from whatever
/// [Franchise.upcomingDraftClass] already held (rolled a full season
/// ahead, previewable this whole time), immediately followed by rolling
/// *that* draft's own successor so the season now starting has a real
/// preview from day one too (2026-08-21, a direct GM ask).
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
/// accumulated for *this* draft specifically (real draft-pick trades,
/// 2026-08-19) gets sliced out and baked into that fresh [DraftInProgress]
/// as a frozen snapshot; any other season's entries (further-out future
/// picks, `pick_ownership.dart`'s `tradeableDraftSeasons`) carry forward
/// into the new trade window untouched, rather than resetting.
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

  // The just-finished season's real result, folded into the GM's own
  // head coach's career record -- a direct GM ask (2026-08-19): "Head
  // coach needs a detail screen... career wins/losses, any trophies, how
  // long they've been a head coach." One tick per real season
  // transition, off this season's real final standings/champion, not
  // re-derivable later once [newSchedule] below replaces this season's
  // own (`Coach.seasonsAsHeadCoach`'s own doc comment).
  final ownRecord = recordFor(franchise.team.abbreviation, finalStandings);
  final wonChampionship =
      seasonChampion(franchise.seasonProgress.playedGames) ==
      franchise.team.abbreviation;
  final updatedCoach = franchise.coach.copyWithSeasonRecord(
    wins: ownRecord.wins,
    losses: ownRecord.losses,
    wonChampionship: wonChampionship,
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
  // The real class for the draft happening *right now* was already rolled
  // a full season ago (at the previous transition, or at franchise
  // creation for season 0 -> 1) and has been sitting in
  // [Franchise.upcomingDraftClass] ever since, previewable the whole
  // time -- promote it rather than rolling fresh (2026-08-21, a direct GM
  // ask: "roll it at the start of the season instead of on draft day").
  final newDraftClass = franchise.upcomingDraftClass;
  // ...and immediately roll *that* draft's own successor -- the class for
  // whichever draft comes after [newSeason] -- so the season about to
  // start has a real preview available from its very first day too. Same
  // seed formula [newDraftClass] itself always used
  // (`newSeasonSeed + kDraftClassSeedOffset`), just one season further
  // out (`newSeasonSeed + kSeasonSeedSpan`) -- so whenever this eventually
  // gets promoted in turn, it reproduces exactly what a fresh roll at
  // that later moment would have produced anyway.
  final newUpcomingDraftClass = generateDraftClass(
    Random(newSeasonSeed + kSeasonSeedSpan + kDraftClassSeedOffset),
    portraitWeights: portraitWeights,
  );
  final seasonStartSnapshot = <String, int>{
    for (final membership in franchise.roster)
      membership.player.id: membership.player.ratings.overall,
    for (final aiTeam in franchise.league.aiTeams)
      for (final membership in aiTeam.roster)
        membership.player.id: membership.player.ratings.overall,
  };

  // Only this draft's own slice of the live, multi-season overrides gets
  // baked into its DraftInProgress and removed -- every other season's
  // entries (still further out, `pick_ownership.dart`'s
  // tradeableDraftSeasons) carry forward untouched into the new trade
  // window, rather than resetting.
  final overridesForThisDraft =
      franchise.pickOwnershipOverrides[newSeason] ?? const {};
  final remainingPickOwnershipOverrides = FuturePickOwnershipOverrides.of(
    franchise.pickOwnershipOverrides,
  )..remove(newSeason);

  return franchise
      .copyWithCoach(updatedCoach)
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
      .copyWithUpcomingDraftClass(newUpcomingDraftClass)
      .copyWithDraftInProgress(
        DraftInProgress(
          order: draftOrder,
          rounds: kDraftRounds,
          pickOwnershipOverrides: overridesForThisDraft,
        ),
      )
      .copyWithPickOwnershipOverrides(remainingPickOwnershipOverrides)
      .copyWithSeasonStartOverallByPlayerId(seasonStartSnapshot);
}
