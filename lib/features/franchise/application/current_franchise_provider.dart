import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../player/domain/player.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/generation/jersey_number_assignment.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/game_result.dart';
import '../../season/generation/postseason_advancer.dart';
import '../../season/generation/season_advancer.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';
import '../../training/generation/training_advancer.dart';
import '../domain/franchise.dart';
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
  /// The [Random] stream is reseeded from [Franchise.simulationSeed] plus
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
        franchise.simulationSeed +
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
  /// for why) -- gated behind the exact same `advance.gamesPlayed.isEmpty`
  /// idempotency check as everything else in this method, so the lump
  /// can never apply twice to one season.
  Future<List<GameResult>?> simulatePostseasonAndPersist() async {
    final franchise = await future;
    if (franchise == null || !franchise.seasonProgress.isComplete) {
      return null;
    }

    final advance = simulatePostseason(
      Random(franchise.simulationSeed + kPostseasonAdvanceSeedOffset),
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
      Random(withTraining.simulationSeed + kSeasonEndAgingSeedOffset),
      withTraining,
    );
    await _persist(agingAdvance.franchise);
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
  /// The [Random] stream is reseeded from [Franchise.simulationSeed] plus
  /// [Franchise.nextTrainingWeek], not carried forward across calls --
  /// see [kTrainingAdvanceSeedOffset]'s doc comment for why that's what
  /// makes a given week's training result reproducible across a
  /// save/reload.
  Future<TrainingReport?> runTrainingAndPersist() async {
    final franchise = await future;
    if (franchise == null) return null;

    final advance = runTraining(
      Random(
        franchise.simulationSeed +
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
          current.simulationSeed +
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
