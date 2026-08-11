import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../coach/generation/coach_free_agency_advancer.dart';
import '../../player/domain/player.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/generation/jersey_number_assignment.dart';
import '../../roster/generation/roster_legality_advancer.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/game_result.dart';
import '../../season/domain/scheduled_game.dart';
import '../../season/domain/season_progress.dart';
import '../../season/domain/skills_competition.dart';
import '../../season/generation/all_star_advancer.dart';
import '../../season/generation/postseason_advancer.dart';
import '../../season/generation/postseason_generator.dart' show seasonChampion;
import '../../season/generation/retirement_advancer.dart';
import '../../season/generation/season_advancer.dart';
import '../../season/generation/season_tenure_advancer.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';
import '../../training/generation/training_advancer.dart';
import '../domain/franchise.dart';
import '../domain/pending_retirement.dart';
import '../persistence/franchise_json.dart';
import 'save_slots.dart';

/// The original single-save id, kept as-is rather than renamed -- it's
/// now specifically slot 1 of [kSaveSlotIds] (`save_slots.dart`), not a
/// standalone concept anymore, but every pre-existing save on a real
/// device and every test's `_seededRepository` helper already writes
/// here assuming [CurrentFranchiseNotifier] reads it by default, so
/// renaming it would be pure churn for no behavior change.
const kCurrentFranchiseSaveId = 'current-franchise';

const _franchiseSchemaVersion = 1;

/// The GM's current franchise, if one has been created yet, in whichever
/// slot [activeSaveSlotProvider] currently points at. `null` means that
/// slot is empty (either a fresh install, or a slot the GM hasn't
/// started a franchise in yet). Loads from disk on first read;
/// [createFranchise] and every other write method here persist and
/// update this state, so nothing else needs to remember to save.
/// Switching the active slot (`ActiveSaveSlotNotifier.setActiveSlot`)
/// automatically reloads this, since [build] watches it.
class CurrentFranchiseNotifier extends AsyncNotifier<Franchise?> {
  @override
  Future<Franchise?> build() async {
    final repository = ref.watch(saveRepositoryProvider);
    final slotId = await ref.watch(activeSaveSlotProvider.future);
    final raw = await repository.readSave(slotId);
    if (raw == null) return null;

    final envelope = SaveEnvelope.fromJson(raw);
    return franchiseFromJson(envelope.payload);
  }

  Future<void> createFranchise(Franchise franchise) => _persist(franchise);

  /// Replaces the roster with [newRoster] -- same players, reordered. Used
  /// by the bench-order (depth chart) screen, where list position is both
  /// the minutes-ranked order (see `target_minutes.dart`) and, for the
  /// top 5, the starting lineup -- there's no separate starting-lineup
  /// concept to keep in sync with this anymore.
  ///
  /// Awaits [future] rather than reading [state] directly: [state] can
  /// still be `AsyncLoading` (value `null`) if [build] hasn't resolved
  /// yet, which would make this silently no-op even though a franchise
  /// really is on its way. Awaiting guarantees the load has actually
  /// finished -- every write method below follows the same pattern.
  Future<void> updateRosterOrder(List<RosterMembership> newRoster) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(franchise.copyWithRoster(newRoster));
  }

  /// Signs the free agent with [playerId] off `Franchise.freeAgents` and
  /// onto the roster at [status] (active by default) -- the only way a
  /// free agent ever becomes a real roster player. Assigns a jersey
  /// number that doesn't collide with anyone already on the roster
  /// (`assignJerseyNumberAvoiding`) without touching any other player's
  /// number.
  ///
  /// A no-op if there's no current franchise, [playerId] isn't actually
  /// in [Franchise.freeAgents], or [status]'s own slot is already full
  /// ([kActiveRosterSize] for active, [kMaxDevelopmentalRosterSpots] for
  /// developmental -- plus [isDevelopmentalEligible], since a free agent
  /// with too many years of service can't go there at all --
  /// [kMaxInactiveRosterSpots] for reserve/inactive) -- defensive guards,
  /// not paths the real UI should ever hit (the Player Market screen's
  /// Free Agents tab and the Team screen's Development/Inactive slot
  /// pickers only ever offer a slot/player combination that's actually
  /// legal).
  Future<void> signFreeAgent(
    String playerId, {
    RosterStatus status = RosterStatus.active,
  }) async {
    final franchise = await future;
    if (franchise == null) return;

    final index = franchise.freeAgents.indexWhere((p) => p.id == playerId);
    if (index == -1) return;
    final candidate = franchise.freeAgents[index];
    if (!_hasOpenSlot(franchise, status, candidate: candidate)) return;

    final signed = assignJerseyNumberAvoiding(
      Random(),
      candidate,
      franchise.roster,
    );
    final newRoster = [
      ...franchise.roster,
      RosterMembership(player: signed, status: status),
    ];
    final newFreeAgents = [...franchise.freeAgents]..removeAt(index);

    await _persist(
      franchise.copyWithRosterAndFreeAgents(
        newRoster: newRoster,
        newFreeAgents: newFreeAgents,
      ),
    );
  }

  /// Moves the roster player with [playerId] to [newStatus] -- the Team
  /// screen's Development/Inactive slot cards' "move in"/"move out"
  /// actions (2026-08-10, a direct GM ask: "I'd need a way to move
  /// players in/out of those slots"). A no-op if there's no current
  /// franchise, [playerId] isn't on [Franchise.roster], or [newStatus]'s
  /// own slot is already full -- see [signFreeAgent]'s doc comment for
  /// the exact caps; same guard, same reasoning, just for a player who's
  /// already on the roster rather than one being signed onto it.
  Future<void> moveRosterStatus(String playerId, RosterStatus newStatus) async {
    final franchise = await future;
    if (franchise == null) return;

    final index = franchise.roster.indexWhere((m) => m.player.id == playerId);
    if (index == -1) return;
    final membership = franchise.roster[index];
    if (membership.status == newStatus) return;
    if (!_hasOpenSlot(
      franchise,
      newStatus,
      candidate: membership.player,
      excludingPlayerId: playerId,
    )) {
      return;
    }

    final newRoster = [...franchise.roster];
    newRoster[index] = RosterMembership(
      player: membership.player,
      status: newStatus,
    );
    await _persist(franchise.copyWithRoster(newRoster));
  }

  /// Whether [franchise] has room for one more player at [status] --
  /// [candidate] matters only for the developmental eligibility check
  /// ([isDevelopmentalEligible]). [excludingPlayerId], when given,
  /// leaves that player out of the current count -- for
  /// [moveRosterStatus] checking a slot the mover might already occupy
  /// under a different status, which should never count against
  /// themselves.
  bool _hasOpenSlot(
    Franchise franchise,
    RosterStatus status, {
    required Player candidate,
    String? excludingPlayerId,
  }) {
    final count = franchise.roster
        .where((m) => m.status == status && m.player.id != excludingPlayerId)
        .length;
    return switch (status) {
      RosterStatus.active => count < kActiveRosterSize,
      RosterStatus.developmental =>
        count < kMaxDevelopmentalRosterSpots &&
            isDevelopmentalEligible(candidate),
      RosterStatus.reserveInactive => count < kMaxInactiveRosterSpots,
    };
  }

  /// Releases the roster player with [playerId] and moves them onto
  /// [Franchise.freeAgents] -- a direct GM ask (2026-08-09): "I need a way
  /// to drop a player, so I can free up a roster spot for a free agent,"
  /// with the explicit follow-up that a dropped player should land back
  /// in free agency, not just vanish. Clears their jersey number
  /// ([Player.copyWithJerseyNumber]) on the way out -- an unrostered
  /// player wearing a number would be the only free agent in the pool
  /// with one, and [signFreeAgent] assigns a fresh one anyway the moment
  /// someone signs them back.
  ///
  /// A no-op if there's no current franchise or [playerId] isn't actually
  /// on [Franchise.roster] -- same defensive-guard posture as
  /// [signFreeAgent]. No minimum-roster-size check: `roster_legality.dart`
  /// deliberately doesn't enforce one (a team can choose to run under
  /// [kActiveRosterSize]), so dropping below it is a real, allowed GM
  /// choice -- it just means [advanceGameDay] won't let the season move
  /// again until a replacement is signed, the same gate a fresh Day-0
  /// roster already hits.
  Future<void> dropPlayer(String playerId) async {
    final franchise = await future;
    if (franchise == null) return;

    final index = franchise.roster.indexWhere((m) => m.player.id == playerId);
    if (index == -1) return;

    final dropped = franchise.roster[index].player.copyWithJerseyNumber(null);
    final newRoster = [...franchise.roster]..removeAt(index);
    final newFreeAgents = [...franchise.freeAgents, dropped];

    await _persist(
      franchise.copyWithRosterAndFreeAgents(
        newRoster: newRoster,
        newFreeAgents: newFreeAgents,
      ),
    );
  }

  /// Resolves one of [Franchise.pendingRetirements] -- either the GM lets
  /// [playerId] retire outright ([attemptPersuasion] `false`), or has the
  /// coach attempt to talk them into playing one more year
  /// ([attemptRetirementPersuasion], a real skill check off
  /// [Franchise.coach]'s Motivation). Either way the pending entry is
  /// cleared; a persuaded player simply stays on the roster untouched, a
  /// retiring one is removed from it entirely -- never routed to
  /// [Franchise.freeAgents], same "retired means retired" rule
  /// `resolveAiTeamRetirements` already established.
  ///
  /// A no-op (returns `null`) if there's no current franchise or
  /// [playerId] isn't actually pending -- the mail item that leads here
  /// only ever exists for a real pending entry, so this is a defensive
  /// guard, not a path the real UI should hit.
  Future<RetirementDecisionOutcome?> resolvePendingRetirement(
    String playerId, {
    required bool attemptPersuasion,
  }) async {
    final franchise = await future;
    if (franchise == null) return null;
    if (!franchise.pendingRetirements.any((p) => p.playerId == playerId)) {
      return null;
    }

    final newPending = [
      for (final pending in franchise.pendingRetirements)
        if (pending.playerId != playerId) pending,
    ];

    if (!attemptPersuasion) {
      await _persist(
        _retirePlayer(
          franchise,
          playerId,
        ).copyWithPendingRetirements(newPending),
      );
      return RetirementDecisionOutcome.letRetire;
    }

    final succeeded = attemptRetirementPersuasion(Random(), franchise.coach);
    final updated = succeeded ? franchise : _retirePlayer(franchise, playerId);
    await _persist(updated.copyWithPendingRetirements(newPending));
    return succeeded
        ? RetirementDecisionOutcome.persuadedToStay
        : RetirementDecisionOutcome.persuasionFailed;
  }

  /// Removes [playerId] from [franchise]'s roster entirely -- unlike
  /// [dropPlayer], never routed to [Franchise.freeAgents]: this is
  /// [resolvePendingRetirement]'s "actually retiring" path, and retired
  /// means retired, not signable.
  Franchise _retirePlayer(Franchise franchise, String playerId) {
    return franchise.copyWithRoster([
      for (final membership in franchise.roster)
        if (membership.player.id != playerId) membership,
    ]);
  }

  /// Replaces the coach's portrait appearance and persists it. Same
  /// no-op-if-no-franchise and await-future rationale as
  /// [updateRosterOrder].
  Future<void> updateCoachAppearance(PortraitAppearance appearance) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(
      franchise.copyWithCoach(franchise.coach.copyWithAppearance(appearance)),
    );
  }

  /// Replaces one roster player's portrait appearance and persists it.
  Future<void> updatePlayerAppearance(
    String playerId,
    PortraitAppearance appearance,
  ) {
    return _updatePlayer(
      playerId,
      (player) => player.copyWithAppearance(appearance),
    );
  }

  /// Replaces one roster player's nickname and persists it. Infrastructure
  /// for Phase 2's season-end ceremony (apply an earned nickname suggestion,
  /// or the GM's override of it) -- no UI calls this yet, since nothing can
  /// earn a [PlayerAchievementRecord] to earn a nickname from until then;
  /// see the note on [Player.nickname].
  Future<void> updatePlayerNickname(String playerId, String? nickname) {
    return _updatePlayer(
      playerId,
      (player) => player.copyWithNickname(nickname),
    );
  }

  /// Applies [transform] to the roster player with id [playerId] and
  /// persists the result. Does nothing if there's no current franchise or
  /// [playerId] isn't on the roster (shouldn't happen from the portrait
  /// editor, which is only reachable for players actually on the roster it
  /// was opened from). Same await-[future]-not-`state.value` rationale as
  /// [updateRosterOrder].
  Future<void> _updatePlayer(
    String playerId,
    Player Function(Player) transform,
  ) async {
    final franchise = await future;
    if (franchise == null) return;

    final newRoster = [
      for (final membership in franchise.roster)
        if (membership.player.id == playerId)
          RosterMembership(
            player: transform(membership.player),
            status: membership.status,
          )
        else
          membership,
    ];
    await _persist(franchise.copyWithRoster(newRoster));
  }

  /// Simulates the next scheduled game day and persists the result.
  /// Returns the full [GameResult]s for that game day -- box scores and
  /// all -- so the caller can do something with them (show the GM's own
  /// game distinctly, say) before they're gone; only the lean
  /// [Franchise.seasonProgress] footprint (`PlayedGame`, not the full
  /// event log) actually gets persisted, same as every other game.
  ///
  /// Returns `null` if there's no current franchise, if the season has no
  /// game days left to advance to ([SeasonProgress.isComplete]), or if
  /// the active roster is under [kActiveRosterSize] -- a direct GM ask
  /// for a real Day-0 hook: a fresh expansion roster starts one player
  /// short on purpose (`generateStartingRoster`'s doc comment), and the
  /// season can't advance until the GM signs a free agent to fill it.
  /// This is the actual enforcement point; the Dashboard's own button
  /// already hides itself in the same situation (`dashboard_screen.dart`'s
  /// `_SeasonAdvanceCard`), so a real GM should never hit this guard --
  /// it's here so nothing else that might call this directly could
  /// accidentally bypass the gate.
  ///
  /// The [Random] stream is reseeded from [Franchise.seasonSeed] plus
  /// the game day index being advanced, not carried forward across calls
  /// -- see [kSeasonAdvanceSeedOffset]'s doc comment for why that's what
  /// makes a given game day's result reproducible across a save/reload.
  Future<List<GameResult>?> advanceGameDay() async {
    final franchise = await future;
    if (franchise == null || franchise.seasonProgress.isComplete) {
      return null;
    }
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;
    if (activeCount < kActiveRosterSize) return null;

    final advance = advanceToNextGameDay(
      Random(
        franchise.seasonSeed +
            kSeasonAdvanceSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      franchise.seasonProgress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
      ownTeamAbbreviation: franchise.team.abbreviation,
    );

    final withTraining = _catchUpTraining(
      franchise.copyWithSeasonProgress(advance.progress),
    );
    await _persist(withTraining);
    return advance.gamesPlayed;
  }

  /// Advances through the All-Star break's Skills Competition day
  /// (2026-08-10, TODO.md item 6) -- the generic [advanceGameDay] can't
  /// resolve this day at all (`season_advancer.dart`'s `_simulatable`
  /// always skips it; there's no real match to simulate), so this is a
  /// dedicated path a caller uses instead, once
  /// `nextGameDayTypes(franchise.seasonProgress)` shows
  /// [GameType.skillsCompetition] is up next. Selects both conferences'
  /// All-Star squads and runs all 3 events in one call
  /// (`resolveSkillsCompetitionDay`), persists the result, and manually
  /// advances [SeasonProgress.nextGameDayIndex] the same way
  /// [SeasonProgress.copyWithGameDayPlayed] always does -- with an empty
  /// [PlayedGame] list, since this day never produces one.
  ///
  /// Returns `null` if there's no current franchise, or if the next game
  /// day isn't actually the Skills Competition -- same "shouldn't happen
  /// from a real GM flow, guards against a caller bypassing the check
  /// anyway" posture [advanceGameDay]'s own active-roster guard has.
  Future<SkillsCompetitionResult?> advanceSkillsCompetitionDay() async {
    final franchise = await future;
    if (franchise == null) return null;
    if (!nextGameDayTypes(
      franchise.seasonProgress,
    ).contains(GameType.skillsCompetition)) {
      return null;
    }

    final result = resolveSkillsCompetitionDay(
      Random(
        franchise.seasonSeed +
            kSeasonAdvanceSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      franchise,
    );

    final advancedProgress = franchise.seasonProgress.copyWithGameDayPlayed(
      const [],
    );
    await _persist(
      franchise
          .copyWithSeasonProgress(advancedProgress)
          .copyWithSkillsCompetitionResult(result),
    );
    return result;
  }

  /// Advances through the All-Star break's Game day (2026-08-10,
  /// TODO.md item 5) -- same "the generic path can't handle this day"
  /// reasoning as [advanceSkillsCompetitionDay], but this one *does*
  /// simulate a real match (`resolveAllStarGame` builds both conference
  /// squads and calls the same match engine every other game uses), so it
  /// goes through [advanceToNextGameDay] after all, just with those 2
  /// synthetic squads injected into its roster map -- [_catchUpTraining]
  /// runs afterward too, same as [advanceGameDay], so the week's training
  /// resolves on schedule regardless of it being an All-Star week.
  ///
  /// Returns `null` under the same conditions
  /// [advanceSkillsCompetitionDay] does, substituting
  /// [GameType.allStarGame] for the type check.
  Future<AllStarGameAdvance?> advanceAllStarGameDay() async {
    final franchise = await future;
    if (franchise == null) return null;
    if (!nextGameDayTypes(
      franchise.seasonProgress,
    ).contains(GameType.allStarGame)) {
      return null;
    }

    final random = Random(
      franchise.seasonSeed +
          kSeasonAdvanceSeedOffset +
          franchise.seasonProgress.nextGameDayIndex,
    );
    final gameAdvance = resolveAllStarGame(random, franchise);

    // resolveAllStarGame already ran the match itself (it needs the 2
    // synthetic squads `advanceToNextGameDay` doesn't know how to build)
    // -- calling it again here would double-simulate. Persisting its
    // already-computed PlayedGame just folds the one game it produced
    // into SeasonProgress the same way every other game day does, so
    // `gameDaysInOrder`/`isComplete` bookkeeping stays correct.
    final advancedProgress = franchise.seasonProgress.copyWithGameDayPlayed([
      gameAdvance.playedGame,
    ]);
    final withTraining = _catchUpTraining(
      gameAdvance.franchise.copyWithSeasonProgress(advancedProgress),
    );
    await _persist(withTraining);
    return gameAdvance;
  }

  /// Runs the entire postseason bracket (First Round -> Semifinals ->
  /// Finals) in one call and persists the result. Returns the full
  /// [GameResult]s for every series game played, same "here's your
  /// transient window" deal as [advanceGameDay].
  ///
  /// Returns `null` if there's no current franchise, or if
  /// [SeasonProgress.isComplete] isn't true yet (there's still day-by-day
  /// advancing to do -- the postseason needs final regular-season
  /// standings to seed). Also returns `null` (a no-op) if the postseason
  /// has already been played this season -- see
  /// [simulatePostseason]'s idempotency note.
  ///
  /// This is also the one moment the whole season is unambiguously over,
  /// which is why it's the single call site for [resolveSeasonEndAging]
  /// (TODO.md item 1's other half, see that function's own doc comment
  /// for why) and [resolveAiTeamSeasonTraining] (TODO.md item 8 -- every
  /// AI roster's whole season of training resolves right here too, in
  /// one lump, per the GM's own design call) -- both gated behind the
  /// exact same `advance.gamesPlayed.isEmpty` idempotency check as
  /// everything else in this method, so neither can ever apply twice to
  /// one season.
  Future<List<GameResult>?> simulatePostseasonAndPersist() async {
    final franchise = await future;
    if (franchise == null || !franchise.seasonProgress.isComplete) {
      return null;
    }

    final advance = simulatePostseason(
      Random(franchise.seasonSeed + kPostseasonAdvanceSeedOffset),
      franchise.seasonProgress,
      leagueTeams: allLeagueTeams(franchise),
      rostersByAbbreviation: rostersByAbbreviation(franchise),
      ownTeamAbbreviation: franchise.team.abbreviation,
    );
    if (advance.gamesPlayed.isEmpty) return null; // already played

    final withTraining = _catchUpTraining(
      franchise.copyWithSeasonProgress(advance.progress),
    );
    final agingAdvance = resolveSeasonEndAging(
      Random(withTraining.seasonSeed + kSeasonEndAgingSeedOffset),
      withTraining,
    );
    final aiTrainingAdvance = resolveAiTeamSeasonTraining(
      Random(agingAdvance.franchise.seasonSeed + kAiTeamTrainingSeedOffset),
      agingAdvance.franchise,
    );
    final withAiTraining = agingAdvance.franchise.copyWithLeague(
      aiTrainingAdvance.league,
    );
    final coachFreeAgencyAdvance = resolveCoachFreeAgency(
      Random(withAiTraining.seasonSeed + kCoachFreeAgencySeedOffset),
      withAiTraining,
    );
    final withCoachFreeAgency = withAiTraining.copyWithLeague(
      coachFreeAgencyAdvance.league,
    );
    final aiAgingAdvance = resolveAiTeamSeasonEndAging(
      Random(withCoachFreeAgency.seasonSeed + kAiTeamSeasonEndAgingSeedOffset),
      withCoachFreeAgency,
    );
    final withAiAging = withCoachFreeAgency.copyWithLeague(
      aiAgingAdvance.league,
    );
    final aiRetirementAdvance = resolveAiTeamRetirements(
      Random(withAiAging.seasonSeed + kAiTeamRetirementSeedOffset),
      withAiAging,
    );
    final withAiRetirement = withAiAging.copyWithLeague(
      aiRetirementAdvance.league,
    );
    // The GM's own roster is never auto-retired -- each newly-eligible
    // player becomes a pending decision instead (a real Mail item lets
    // the GM let them retire or have the coach attempt to convince them
    // to stay). Appended, not replaced: an earlier season's still-
    // unresolved decision (the GM never opened that mail) shouldn't get
    // silently dropped just because another season's evaluation ran.
    final championAbbreviation = seasonChampion(
      withAiRetirement.seasonProgress.playedGames,
    );
    final wonChampionship =
        championAbbreviation == withAiRetirement.team.abbreviation;
    final alreadyPending = {
      for (final pending in withAiRetirement.pendingRetirements)
        pending.playerId,
    };
    final newlyEligible = [
      for (final membership in withAiRetirement.roster)
        if (!alreadyPending.contains(membership.player.id))
          if (evaluateRetirementEligibility(
                membership.player,
                wonChampionship: wonChampionship,
              )
              case final reason?)
            PendingRetirement(playerId: membership.player.id, reason: reason),
    ];
    final withPendingRetirements = newlyEligible.isEmpty
        ? withAiRetirement
        : withAiRetirement.copyWithPendingRetirements([
            ...withAiRetirement.pendingRetirements,
            ...newlyEligible,
          ]);
    // Legality enforcement runs after retirement, so it sees who's
    // actually still on the roster -- and reads *this* season's final
    // star tiers, so it has to run after training/aging too.
    final withLegality = enforceAiRosterLegality(
      withPendingRetirements,
    ).franchise;
    // Tenure (age/yearsOfService) increments last, deliberately -- every
    // pass above computes its result against the age a player played this
    // season *at* (`advancePlayerTenure`'s own doc comment).
    await _persist(advancePlayerTenure(withLegality));
    return advance.gamesPlayed;
  }

  /// Replaces the training plan and persists it -- the Training screen's
  /// only write path. Same no-op-if-no-franchise and await-future
  /// rationale as [updateRosterOrder].
  Future<void> updateTrainingPlan(TrainingPlan newPlan) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(franchise.copyWithTrainingPlan(newPlan));
  }

  /// Resolves training for whatever week just became eligible and
  /// persists the result. Returns the [TrainingReport] so the caller can
  /// show it once, same "here's your transient window" deal as
  /// [advanceGameDay].
  ///
  /// [advanceGameDay] and [simulatePostseasonAndPersist] both already call
  /// [_catchUpTraining] themselves the moment a week completes, so in
  /// normal play there's nothing left pending by the time anything else
  /// would call this -- it exists as a manual fallback (a save from before
  /// that auto-resolve existed, or any other path that moved
  /// [SeasonProgress] without going through those two methods) rather than
  /// the primary way training ever resolves.
  ///
  /// Returns `null` if there's no current franchise, or if no new week is
  /// ready yet ([lastFullyCompletedWeek] hasn't advanced past
  /// [Franchise.nextTrainingWeek]) -- see [runTraining]'s doc comment.
  /// Idempotent per week for the same reason [runTraining] is: calling
  /// again before another week completes just returns `null`.
  ///
  /// The [Random] stream is reseeded from [Franchise.seasonSeed] plus
  /// [Franchise.nextTrainingWeek], not carried forward across calls --
  /// see [kTrainingAdvanceSeedOffset]'s doc comment for why that's what
  /// makes a given week's training result reproducible across a
  /// save/reload.
  Future<TrainingReport?> runTrainingAndPersist() async {
    final franchise = await future;
    if (franchise == null) return null;

    final advance = runTraining(
      Random(
        franchise.seasonSeed +
            kTrainingAdvanceSeedOffset +
            franchise.nextTrainingWeek,
      ),
      franchise,
    );
    if (advance == null) return null;

    await _persist(advance.franchise);
    return advance.report;
  }

  /// Resolves training for *every* week that's fully completed but hasn't
  /// been trained yet on [franchise] -- not just the single most-recent
  /// one -- so a real GM session that advances several game days (or an
  /// entire week) in a row before checking Mail still gets one distinct
  /// [TrainingReport] per week, instead of [runTraining] quietly folding
  /// several weeks' worth of minutes and aging into whichever single call
  /// happens to resolve them.
  ///
  /// This is the fix for a real bug: training used to only ever resolve
  /// when the GM tapped the Dashboard's "Training Report Ready" card while
  /// it happened to be showing, and that card is itself only visible in
  /// the narrow window right after a week completes and before the next
  /// game day pushes into the following week (`lastFullyCompletedWeek`
  /// goes back to returning `null` mid-week). Skip that window -- by
  /// playing on without visiting the Dashboard right then -- and the
  /// skipped week's report never got created at all: the next `runTraining`
  /// call just relabeled the combined gap under the newer week's number.
  /// That's what produced training reports on weeks 2, 6, 8, 9 of a season
  /// instead of every week, and made a report look like it "disappeared"
  /// if it wasn't opened the moment it appeared. Calling this from
  /// [advanceGameDay] and [simulatePostseasonAndPersist] -- every path
  /// that can complete a week -- means a week's report exists the instant
  /// that week finishes, full stop, with no dependence on the GM's UI
  /// timing at all.
  Franchise _catchUpTraining(Franchise franchise) {
    var current = franchise;
    while (true) {
      final advance = runTraining(
        Random(
          current.seasonSeed +
              kTrainingAdvanceSeedOffset +
              current.nextTrainingWeek,
        ),
        current,
      );
      if (advance == null) return current;
      current = advance.franchise;
    }
  }

  /// Marks a Mail inbox item (`mail/domain/mail_item.dart`'s `MailItem.id`)
  /// read and persists it -- opening its detail (an Assistant GM message)
  /// or opening the report it wraps (a training report) are the only
  /// callers. A no-op if it's already read, so callers can call this
  /// unconditionally without checking first.
  Future<void> markMailRead(String mailId) async {
    final franchise = await future;
    if (franchise == null || franchise.readMailIds.contains(mailId)) return;
    await _persist(
      franchise.copyWithReadMailIds({...franchise.readMailIds, mailId}),
    );
  }

  Future<void> _persist(Franchise franchise) async {
    final repository = ref.read(saveRepositoryProvider);
    final slotId = await ref.read(activeSaveSlotProvider.future);
    final envelope = SaveEnvelope(
      schemaVersion: _franchiseSchemaVersion,
      payload: franchiseToJson(franchise),
    );
    await repository.writeSave(slotId, envelope.toJson());
    state = AsyncData(franchise);
  }
}

final currentFranchiseProvider =
    AsyncNotifierProvider<CurrentFranchiseNotifier, Franchise?>(
      CurrentFranchiseNotifier.new,
    );
