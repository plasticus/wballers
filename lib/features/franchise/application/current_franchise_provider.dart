import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../coach/domain/coach.dart';
import '../../coach/generation/coach_aging_advancer.dart';
import '../../coach/generation/coach_free_agency_advancer.dart';
import '../../draft/generation/draft_advancer.dart';
import '../../league/domain/league.dart';
import '../../match/domain/match_result.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../player/domain/player.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../portrait/persistence/portrait_catalog_loader.dart';
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
import '../../season/generation/injury_advancer.dart';
import '../../season/generation/postseason_generator.dart' show seasonChampion;
import '../../season/generation/retirement_advancer.dart';
import '../../season/generation/season_advancer.dart';
import '../../season/generation/season_awards_advancer.dart';
import '../../season/generation/season_tenure_advancer.dart';
import '../../season/generation/season_transition_advancer.dart';
import '../../trade/domain/pick_ownership.dart';
import '../../trade/domain/trade_asset.dart';
import '../../trade/domain/trade_offer.dart';
import '../../trade/generation/ai_offseason_trade_advancer.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';
import '../../training/generation/training_advancer.dart';
import '../domain/former_player_record.dart';
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
    // `copyWith`, not a fresh `RosterMembership(...)` -- preserves
    // [RosterMembership.injury] across the move (an injured player moved
    // between slots is still injured; this isn't a recovery mechanism).
    // [RosterMembership.recoveredWhileReserved] does get cleared here,
    // deliberately -- any real move the GM makes off this player counts as
    // having seen/acted on the reminder, not just a move specifically back
    // to active.
    newRoster[index] = membership.copyWith(
      status: newStatus,
      recoveredWhileReserved: false,
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

  /// Replaces the GM's own head coach with [newCoach] -- "the GM can
  /// hire a new head coach every off-season, if they want," a direct GM
  /// call (2026-08-19, `coach-lifecycle-notes.md`). Entirely voluntary
  /// (no forced turnover the way a poor-record AI team gets fired) and
  /// unconditional here -- `AvailableHeadCoachesScreen` is the only
  /// caller, and only ever shows itself during the off-season window
  /// (`isTradeWindowOpen`'s own "gate in the UI, not the provider" shape
  /// applies here too), so nothing else needs to re-check that. The old
  /// coach is discarded outright, same as a fired/retired AI coach --
  /// no persisted "former coaches" list exists for anything to read.
  Future<void> hireHeadCoach(Coach newCoach) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(franchise.copyWithCoach(newCoach));
  }

  /// Sets (or, given `null`, clears) [Franchise.tradeBlockPlayerId] --
  /// exactly one at a time, per `trading-and-hidden-gems-notes.md`. A
  /// no-op if [playerId] isn't actually one of the GM's own *active*
  /// roster players (developmental/reserve players, or a stale id,
  /// silently don't set anything, rather than the Trade Board later
  /// having to cope with a block player who was never really tradeable).
  Future<void> setTradeBlockPlayer(String? playerId) async {
    final franchise = await future;
    if (franchise == null) return;
    if (playerId != null &&
        !franchise.roster.any(
          (m) => m.player.id == playerId && m.status == RosterStatus.active,
        )) {
      return;
    }
    await _persist(franchise.copyWithTradeBlockPlayerId(playerId));
  }

  /// Records [offerId] as resolved this turn
  /// ([Franchise.resolvedTradeOfferIds]) without touching either roster
  /// -- what the Trade Board's "Decline" button calls.
  Future<void> declineTradeOffer(String offerId) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(
      franchise.copyWithResolvedTradeOfferIds({
        ...franchise.resolvedTradeOfferIds,
        offerId,
      }),
    );
  }

  /// Executes [offer] for real: every [PlayerTradeAsset] on each side
  /// actually changes rosters (the GM's own and [offer]'s
  /// [TradeOffer.offeringTeamAbbreviation]'s), landing [RosterStatus.active]
  /// on their new team same as a free-agent signing or a draft pick
  /// does. Every [PickTradeAsset] on each side genuinely changes
  /// ownership too (2026-08-19, real draft-pick ownership --
  /// [Franchise.pickOwnershipOverrides], `pick_ownership.dart`'s
  /// `transferFuturePickOwnership`), for whichever of the
  /// `tradeableDraftSeasons` horizon [PickTradeAsset.draftSeason] names --
  /// the acquiring side is really who's on the clock for it once that
  /// draft actually arrives (`DraftInProgress.onTheClock`), not just
  /// credited for it in this one offer's value math.
  ///
  /// A no-op (but still marks [offer] resolved, so a stale offer card
  /// doesn't linger) if either side no longer actually has everything
  /// [offer] named -- a player could have retired, been traded away by
  /// an earlier accepted offer this same turn, or moved off the active
  /// roster; a pick could have already been traded away the same way --
  /// all between when the board was generated and now. If the GM's own
  /// [Franchise.tradeBlockPlayerId] was part of [offer], it's cleared --
  /// she's not on this roster to keep advertising anymore.
  Future<void> acceptTradeOffer(TradeOffer offer) async {
    final franchise = await future;
    if (franchise == null) return;
    if (franchise.resolvedTradeOfferIds.contains(offer.id)) return;

    Future<void> markResolved() => _persist(
      franchise.copyWithResolvedTradeOfferIds({
        ...franchise.resolvedTradeOfferIds,
        offer.id,
      }),
    );

    final aiTeamIndex = franchise.league.aiTeams.indexWhere(
      (t) => t.team.abbreviation == offer.offeringTeamAbbreviation,
    );
    if (aiTeamIndex == -1) {
      await markResolved();
      return;
    }
    final aiTeam = franchise.league.aiTeams[aiTeamIndex];

    final askedPlayerIds = {
      for (final asset in offer.askedFromYou)
        if (asset case PlayerTradeAsset(:final player)) player.id,
    };
    final offeredPlayerIds = {
      for (final asset in offer.offeredToYou)
        if (asset case PlayerTradeAsset(:final player)) player.id,
    };
    final askedPicks = [
      for (final asset in offer.askedFromYou)
        if (asset case PickTradeAsset()) asset,
    ];
    final offeredPicks = [
      for (final asset in offer.offeredToYou)
        if (asset case PickTradeAsset()) asset,
    ];
    final ownHasEverything = askedPlayerIds.every(
      (id) => franchise.roster.any((m) => m.player.id == id),
    );
    final aiHasEverything = offeredPlayerIds.every(
      (id) => aiTeam.roster.any((m) => m.player.id == id),
    );
    final ownOwnsEveryAskedPick = askedPicks.every(
      (pick) =>
          currentFuturePickOwner(
            franchise.pickOwnershipOverrides,
            draftSeason: pick.draftSeason,
            round: pick.round,
            originalTeamAbbreviation: pick.originalTeamAbbreviation,
          ) ==
          franchise.team.abbreviation,
    );
    final aiOwnsEveryOfferedPick = offeredPicks.every(
      (pick) =>
          currentFuturePickOwner(
            franchise.pickOwnershipOverrides,
            draftSeason: pick.draftSeason,
            round: pick.round,
            originalTeamAbbreviation: pick.originalTeamAbbreviation,
          ) ==
          aiTeam.team.abbreviation,
    );
    if (!ownHasEverything ||
        !aiHasEverything ||
        !ownOwnsEveryAskedPick ||
        !aiOwnsEveryOfferedPick) {
      await markResolved();
      return;
    }

    final incomingPlayers = [
      for (final asset in offer.offeredToYou)
        if (asset case PlayerTradeAsset(:final player)) player,
    ];
    final outgoingPlayers = [
      for (final asset in offer.askedFromYou)
        if (asset case PlayerTradeAsset(:final player)) player,
    ];

    final newOwnRoster = [
      for (final m in franchise.roster)
        if (!askedPlayerIds.contains(m.player.id)) m,
      for (final p in incomingPlayers)
        RosterMembership(player: p, status: RosterStatus.active),
    ];
    var newAiRoster = [
      for (final m in aiTeam.roster)
        if (!offeredPlayerIds.contains(m.player.id)) m,
      for (final p in outgoingPlayers)
        RosterMembership(player: p, status: RosterStatus.active),
    ];
    // Every other offer shape keeps headcount equal on both sides, so
    // this never fires in practice -- but the one 2-for-1 consolidation
    // slot (`trade_offer_generator.dart`'s `kConsolidationOfferSlotIndex`)
    // genuinely can leave the AI side with more active players than it
    // started with. `targetMinutesForOrderedRoster`'s own hard assert
    // caps active rosters at `kActiveRosterSize`, so going over there
    // isn't a "self-inflicted disadvantage" the way the GM's own roster
    // dropping under it is (`dropPlayer`'s own doc comment) -- it's a
    // real crash risk the next time this AI team plays. Make room the
    // same way a real front office would: waive the team's own weakest
    // *pre-existing* active player (never one of [outgoingPlayers] --
    // they just arrived, cutting them the same trade that brought them
    // in would be a strange thing for the AI to do) back to
    // [Franchise.freeAgents], same "released, not vanished" landing spot
    // [dropPlayer] already uses.
    final waivedToFreeAgency = <Player>[];
    while (newAiRoster.where((m) => m.status == RosterStatus.active).length >
        kActiveRosterSize) {
      final preExistingActive = [
        for (final m in newAiRoster)
          if (m.status == RosterStatus.active &&
              !outgoingPlayers.any((p) => p.id == m.player.id))
            m.player,
      ];
      if (preExistingActive.isEmpty) break; // Shouldn't happen; safety net.
      final weakest = preExistingActive.reduce(
        (a, b) => a.ratings.skillPoints <= b.ratings.skillPoints ? a : b,
      );
      newAiRoster = [
        for (final m in newAiRoster)
          if (m.player.id != weakest.id) m,
      ];
      waivedToFreeAgency.add(weakest.copyWithJerseyNumber(null));
    }
    final newAiTeams = [...franchise.league.aiTeams];
    newAiTeams[aiTeamIndex] = aiTeam.copyWithRoster(newAiRoster);

    var newPickOwnershipOverrides = franchise.pickOwnershipOverrides;
    for (final pick in askedPicks) {
      newPickOwnershipOverrides = transferFuturePickOwnership(
        newPickOwnershipOverrides,
        draftSeason: pick.draftSeason,
        round: pick.round,
        originalTeamAbbreviation: pick.originalTeamAbbreviation,
        newOwnerAbbreviation: aiTeam.team.abbreviation,
      );
    }
    for (final pick in offeredPicks) {
      newPickOwnershipOverrides = transferFuturePickOwnership(
        newPickOwnershipOverrides,
        draftSeason: pick.draftSeason,
        round: pick.round,
        originalTeamAbbreviation: pick.originalTeamAbbreviation,
        newOwnerAbbreviation: franchise.team.abbreviation,
      );
    }

    final blockPlayerTraded =
        franchise.tradeBlockPlayerId != null &&
        askedPlayerIds.contains(franchise.tradeBlockPlayerId);

    var updated = franchise
        .copyWithRoster(newOwnRoster)
        .copyWithLeague(League(aiTeams: newAiTeams))
        .copyWithPickOwnershipOverrides(newPickOwnershipOverrides)
        .copyWithResolvedTradeOfferIds({
          ...franchise.resolvedTradeOfferIds,
          offer.id,
        });
    if (blockPlayerTraded) {
      updated = updated.copyWithTradeBlockPlayerId(null);
    }
    if (waivedToFreeAgency.isNotEmpty) {
      updated = updated.copyWithFreeAgents([
        ...updated.freeAgents,
        ...waivedToFreeAgency,
      ]);
    }
    await _persist(updated);
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
  /// means retired, not signable. Also snapshots her name/position/jersey
  /// into [Franchise.formerPlayers] (`copyWithRetiredPlayer`) so this
  /// season's own training reports can still show a real name for her
  /// afterward instead of the generic "Former Player" fallback -- a
  /// direct GM report (2026-08-19), see [FormerPlayerRecord]'s own doc
  /// comment. A no-op beyond the removal itself if [playerId] somehow
  /// isn't actually on [franchise]'s roster (never expected in practice
  /// -- every caller resolves this against a real [PendingRetirement]).
  Franchise _retirePlayer(Franchise franchise, String playerId) {
    final membership = franchise.roster.where((m) => m.player.id == playerId);
    if (membership.isEmpty) return franchise;
    final player = membership.first.player;
    return franchise.copyWithRetiredPlayer(
      FormerPlayerRecord(
        playerId: player.id,
        name: player.name,
        primaryPosition: player.primaryPosition,
        jerseyNumber: player.jerseyNumber,
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

  /// Whether [advanceGameDay]/[advanceGameDayWithOwnResult] should refuse
  /// to run. Originally a flat `activeCount < kActiveRosterSize` check, but
  /// that ended up stricter than the game's own roster-legality rules ever
  /// were: `roster_legality.dart`'s own doc comment is explicit that
  /// there's "no enforced minimum" on active roster size -- running short
  /// is meant to be a self-inflicted disadvantage, not something the game
  /// blocks. The flat check only existed for one real scenario: a fresh
  /// expansion roster starts one player short on purpose
  /// (`generateStartingRoster`'s doc comment), and the season shouldn't be
  /// advanceable until the GM fills that Day-0 gap with a free agent.
  ///
  /// Narrowed (2026-08-20, following the injuries design pass) to exactly
  /// that Day-0 case -- `franchise.season == 0` and still short a player --
  /// so that parking a player or two in Reserve/Inactive for an injury,
  /// later in a season, no longer blocks play the same way. The Dashboard's
  /// own button already hides itself in the Day-0 situation
  /// (`dashboard_screen.dart`'s `_SeasonAdvanceCard`), so a real GM should
  /// never hit this guard -- it's here so nothing else that might call
  /// [advanceGameDay] directly could accidentally bypass the gate.
  bool _blockedByRosterGap(Franchise franchise) {
    if (franchise.season != 0) return false;
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;
    return activeCount < kActiveRosterSize;
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
  /// [_blockedByRosterGap] -- see that method's doc comment for exactly
  /// which roster gaps block advancing and which don't.
  ///
  /// The [Random] stream is reseeded from [Franchise.seasonSeed] plus
  /// the game day index being advanced, not carried forward across calls
  /// -- see [kSeasonAdvanceSeedOffset]'s doc comment for why that's what
  /// makes a given game day's result reproducible across a save/reload.
  ///
  /// [ownDefenseTactic] (2026-08-14, a direct GM ask, following the
  /// "Coach's Board" design artifact) is the GM's pre-game pick from the
  /// Matchup Analysis screen -- `null` (the default, e.g. every other
  /// caller: the Dashboard's own "Advance to Next Game Day" button) falls
  /// back to [DefensiveTactic.balanced], same as omitting it entirely.
  /// Only ever applied to the GM's own team's side of their own game --
  /// see [advanceToNextGameDay]'s own doc comment.
  Future<List<GameResult>?> advanceGameDay({
    DefensiveTactic? ownDefenseTactic,
  }) async {
    final franchise = await future;
    if (franchise == null || franchise.seasonProgress.isComplete) {
      return null;
    }
    if (_blockedByRosterGap(franchise)) return null;

    final advance = advanceToNextGameDay(
      Random(
        franchise.seasonSeed +
            kSeasonAdvanceSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      franchise.seasonProgress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
      leagueTeams: allLeagueTeams(franchise),
      ownTeamAbbreviation: franchise.team.abbreviation,
      coachesByAbbreviation: coachesByAbbreviation(franchise),
      ownDefenseTactic: ownDefenseTactic,
      injuryPenaltyByAbbreviation: _injuryPenaltyByAbbreviation(franchise),
    );

    final withTraining = _catchUpTraining(
      franchise.copyWithSeasonProgress(advance.progress),
    );
    final withInjuries = _withInjuriesResolved(
      Random(
        franchise.seasonSeed +
            kInjuryResolutionSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      withTraining,
      gamesPlayed: advance.gamesPlayed,
      // This game day might be a postseason one -- `advance.gamesPlayed`
      // being postseason games is exactly what makes this true, no
      // separate flag needed.
      isPostseason: advance.gamesPlayed.any(
        (result) => result.game.type == GameType.postseason,
      ),
    );
    // The Finals just got decided (or the postseason was somehow skipped
    // entirely, e.g. a hand-built test franchise) -- run the full
    // off-season pipeline right here, the same real, unambiguous signal
    // [_resolveOffSeason]'s own doc comment describes.
    final withOffSeason = withInjuries.seasonProgress.isComplete
        ? _resolveOffSeason(withInjuries)
        : withInjuries;
    // A new game day means a new Trade Board turn -- whatever the GM
    // accepted/declined on the day that just ended shouldn't keep
    // suppressing a freshly (re)generated offer that happens to land on
    // the same deterministic id again (`Franchise.resolvedTradeOfferIds`'s
    // own doc comment).
    await _persist(withOffSeason.copyWithResolvedTradeOfferIds(const {}));
    return advance.gamesPlayed;
  }

  /// Same as [advanceGameDay], except the GM's own scheduled game for today
  /// has *already* been played -- [ownMatch] is that real, already-computed
  /// [MatchResult] (2026-08-18, `TODO.md` item 8's live-game architecture
  /// stage 5, "Watch Live"): the GM watched it live, beat by beat, via
  /// `simulateMatchLive` on its own screen (`LiveGameLabScreen`), rather
  /// than having it bulk-simulated the instant way. Every other of today's
  /// games still gets bulk-simulated here exactly as [advanceGameDay]
  /// always does -- only the GM's own game is pulled from [ownMatch]
  /// instead of a fresh `simulateMatch` call (`advanceToNextGameDay`'s own
  /// `ownGameAlreadyPlayed` param, added for this).
  ///
  /// No new save-schema state exists for "a live game is in progress" --
  /// a direct, locked design call (`TODO.md` item 8's "Interruption"
  /// bullet, following the standing pre-release call to avoid save-schema
  /// churn). Nothing from the live game
  /// gets persisted until this call runs to completion with a real
  /// [ownMatch] in hand -- if the app is backgrounded or closed mid-live-
  /// game instead, [SeasonProgress.nextGameDayIndex] simply never moves,
  /// and the GM re-lands on the same day's Matchup Preview next launch, as
  /// if nothing had happened. That's deliberate, not a gap: it means this
  /// method's caller only ever calls it with a real, fully-finished result.
  Future<List<GameResult>?> advanceGameDayWithOwnResult(
    MatchResult ownMatch, {
    DefensiveTactic? ownDefenseTactic,
  }) async {
    final franchise = await future;
    if (franchise == null || franchise.seasonProgress.isComplete) {
      return null;
    }
    if (_blockedByRosterGap(franchise)) return null;

    final advance = advanceToNextGameDay(
      Random(
        franchise.seasonSeed +
            kSeasonAdvanceSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      franchise.seasonProgress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
      leagueTeams: allLeagueTeams(franchise),
      ownTeamAbbreviation: franchise.team.abbreviation,
      coachesByAbbreviation: coachesByAbbreviation(franchise),
      ownDefenseTactic: ownDefenseTactic,
      ownGameAlreadyPlayed: ownMatch,
      injuryPenaltyByAbbreviation: _injuryPenaltyByAbbreviation(franchise),
    );

    final withTraining = _catchUpTraining(
      franchise.copyWithSeasonProgress(advance.progress),
    );
    final withInjuries = _withInjuriesResolved(
      Random(
        franchise.seasonSeed +
            kInjuryResolutionSeedOffset +
            franchise.seasonProgress.nextGameDayIndex,
      ),
      withTraining,
      gamesPlayed: advance.gamesPlayed,
      isPostseason: advance.gamesPlayed.any(
        (result) => result.game.type == GameType.postseason,
      ),
    );
    final withOffSeason = withInjuries.seasonProgress.isComplete
        ? _resolveOffSeason(withInjuries)
        : withInjuries;
    // A new game day means a new Trade Board turn -- whatever the GM
    // accepted/declined on the day that just ended shouldn't keep
    // suppressing a freshly (re)generated offer that happens to land on
    // the same deterministic id again (`Franchise.resolvedTradeOfferIds`'s
    // own doc comment).
    await _persist(withOffSeason.copyWithResolvedTradeOfferIds(const {}));
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

  /// Runs the full off-season pipeline -- everything that needs to happen
  /// the moment a season is unambiguously, completely over (the Finals
  /// decided, nothing left on the calendar). Called from wherever an
  /// advance just made [SeasonProgress.isComplete] newly true
  /// ([advanceGameDay], [advanceGameDayWithOwnResult]) -- now that the
  /// postseason plays out one real game day at a time just like everything
  /// else (2026-08-20, a direct GM report: "it needs to play all the games
  /// through the normal system"), there's no longer one single dedicated
  /// "simulate the postseason" call site to hang this off of; `isComplete`
  /// flipping true is the real, unambiguous signal instead. Safe to call
  /// unconditionally once that's confirmed -- `advanceGameDay`'s own early
  /// return already prevents a second call from ever reaching here once
  /// the season's actually done, so this never double-applies.
  ///
  /// This is the single call site for [resolveSeasonEndAging] (TODO.md
  /// item 1's other half, see that function's own doc comment for why),
  /// [resolveAiTeamSeasonTraining] (TODO.md item 8 -- every AI roster's
  /// whole season of training resolves right here too, in one lump, per
  /// the GM's own design call), and [resolveSeasonAwards]
  /// (`0D_Season_2_Roadmap.md`'s Presentation stage -- League MVP, Scoring
  /// Leader, Defensive MVP, Sixth Man, Most Improved Player, and Rookie of
  /// the Year all resolve here too).
  Franchise _resolveOffSeason(Franchise franchise) {
    final agingAdvance = resolveSeasonEndAging(
      Random(franchise.seasonSeed + kSeasonEndAgingSeedOffset),
      franchise,
    );
    final aiTrainingAdvance = resolveAiTeamSeasonTraining(
      Random(agingAdvance.franchise.seasonSeed + kAiTeamTrainingSeedOffset),
      agingAdvance.franchise,
    );
    final withAiTraining = agingAdvance.franchise.copyWithLeague(
      aiTrainingAdvance.league,
    );
    // Every coach (GM's own + all 19 AI) ages a year and grows -- runs
    // before the performance-based firing check below, so a same-turn
    // mandatory-retirement replacement can't also get performance-fired
    // this same off-season (its coachHiredSeason already resets here).
    final coachAgingAdvance = resolveCoachAging(
      Random(withAiTraining.seasonSeed + kCoachAgingSeedOffset),
      withAiTraining,
    );
    final withCoachAging = coachAgingAdvance.franchise;
    final coachFreeAgencyAdvance = resolveCoachFreeAgency(
      Random(withCoachAging.seasonSeed + kCoachFreeAgencySeedOffset),
      withCoachAging,
    );
    final withCoachFreeAgency = withCoachAging.copyWithLeague(
      coachFreeAgencyAdvance.league,
    );
    final aiAgingAdvance = resolveAiTeamSeasonEndAging(
      Random(withCoachFreeAgency.seasonSeed + kAiTeamSeasonEndAgingSeedOffset),
      withCoachFreeAgency,
    );
    final withAiAging = withCoachFreeAgency.copyWithLeague(
      aiAgingAdvance.league,
    );
    // Awards read this season's *final* stats (every training/aging pass
    // above has already run) but must resolve before anyone's removed
    // from a roster or has yearsOfService/age incremented -- Rookie of
    // the Year needs yearsOfService as it stood *during* the season just
    // played, and a retiring veteran should still be able to win an
    // award for the season they actually played.
    final awardsAdvance = resolveSeasonAwards(
      Random(withAiAging.seasonSeed + kSeasonAwardsSeedOffset),
      withAiAging,
    );
    final withAwards = awardsAdvance.franchise;
    final aiRetirementAdvance = resolveAiTeamRetirements(
      Random(withAwards.seasonSeed + kAiTeamRetirementSeedOffset),
      withAwards,
    );
    final withAiRetirement = withAiAging
        .copyWithLeague(aiRetirementAdvance.league)
        .copyWithLeagueRetirements(aiRetirementAdvance.retirements);
    // Forces the narrative veteran into retirement at the end of the
    // franchise's very first season, wherever she is by then -- see
    // `resolveNarrativeVeteranRetirement`'s own doc comment. Runs before
    // the GM's own pending-retirement eligibility check below, so if
    // she's still on the GM's own roster at this point, she's removed
    // outright rather than also being evaluated for a persuasion decision
    // she was never meant to get.
    final withVeteranRetirement = resolveNarrativeVeteranRetirement(
      withAiRetirement,
    );
    // The GM's own roster is never auto-retired -- each newly-eligible
    // player becomes a pending decision instead (a real Mail item lets
    // the GM let them retire or have the coach attempt to convince them
    // to stay). Appended, not replaced: an earlier season's still-
    // unresolved decision (the GM never opened that mail) shouldn't get
    // silently dropped just because another season's evaluation ran.
    final championAbbreviation = seasonChampion(
      withVeteranRetirement.seasonProgress.playedGames,
    );
    final wonChampionship =
        championAbbreviation == withVeteranRetirement.team.abbreviation;
    final alreadyPending = {
      for (final pending in withVeteranRetirement.pendingRetirements)
        pending.playerId,
    };
    final newlyEligible = [
      for (final membership in withVeteranRetirement.roster)
        if (!alreadyPending.contains(membership.player.id))
          if (evaluateRetirementEligibility(
                membership.player,
                wonChampionship: wonChampionship,
              )
              case final reason?)
            PendingRetirement(playerId: membership.player.id, reason: reason),
    ];
    final withPendingRetirements = newlyEligible.isEmpty
        ? withVeteranRetirement
        : withVeteranRetirement.copyWithPendingRetirements([
            ...withVeteranRetirement.pendingRetirements,
            ...newlyEligible,
          ]);
    // Legality enforcement runs after retirement, so it sees who's
    // actually still on the roster -- and reads *this* season's final
    // star tiers, so it has to run after training/aging too.
    final withLegality = enforceAiRosterLegality(
      withPendingRetirements,
    ).franchise;
    // A light off-season pass of AI-to-AI 1:1 trades, entirely separate
    // from the GM-facing Trade Board -- runs after legality enforcement,
    // so it's trading with each team's real final roster shape, not one
    // about to get waived down anyway.
    final aiOffseasonTradeAdvance = resolveAiOffseasonTrades(
      Random(withLegality.seasonSeed + kAiOffseasonTradeSeedOffset),
      withLegality,
    );
    final withAiOffseasonTrades = withLegality.copyWithLeague(
      aiOffseasonTradeAdvance.league,
    );
    // Tenure (age/yearsOfService) increments last, deliberately -- every
    // pass above computes its result against the age a player played this
    // season *at* (`advancePlayerTenure`'s own doc comment).
    return advancePlayerTenure(withAiOffseasonTrades);
  }

  /// Transitions [franchise] into its next season ([beginNextSeason]) and
  /// persists the result -- the not-yet-built "Begin Season 2" button's
  /// eventual write path (`0D_Season_2_Roadmap.md`'s Presentation stage),
  /// exposed early here so `draft_advancer.dart`'s pick-resolution methods
  /// below have something real to operate on. Reads the bundled portrait
  /// catalog ([portraitWeightsProvider]) so the fresh free agents and
  /// draft class this produces get real faces, same as every other
  /// generator that accepts [PortraitWeights].
  ///
  /// Immediately resolves AI picks up to the GM's own first turn
  /// ([resolveAiPicksUntilOwnTurn]) -- [DraftInProgress.order] rarely (if
  /// ever) starts with the GM's own team, and nobody needs to watch
  /// picks nobody's making a choice on before their first real one.
  /// Does nothing if there's no current franchise or [seasonIsOver] isn't
  /// true yet -- same guard [beginNextSeason] itself asserts.
  Future<void> beginNextSeasonAndPersist() async {
    final franchise = await future;
    if (franchise == null || !seasonIsOver(franchise)) return;

    final portraitWeights = await ref.read(portraitWeightsProvider.future);
    final next = beginNextSeason(franchise, portraitWeights: portraitWeights);
    final draft = next.draftInProgress;
    if (draft == null) {
      await _persist(next);
      return;
    }

    final resolved = resolveAiPicksUntilOwnTurn(
      draft: draft,
      draftClass: next.draftClass,
      ownTeamAbbreviation: next.team.abbreviation,
      managementByAbbreviation: {
        for (final entry in coachesByAbbreviation(next).entries)
          entry.key: entry.value.stats.management,
      },
    );
    await _persist(next.copyWithDraftInProgress(resolved));
  }

  /// Records the GM's own pick ([makeOwnPick]) for the prospect with
  /// [prospectPlayerId], then immediately resolves every AI pick up to
  /// the GM's *next* turn ([resolveAiPicksUntilOwnTurn]) -- same "AI
  /// picks between GM turns resolve instantly" posture
  /// [beginNextSeasonAndPersist] already established for the draft's
  /// very first picks. If that leaves the draft [DraftInProgress.isComplete],
  /// immediately [finalizeDraft]s it too, landing every pick (the GM's own
  /// and all 19 AI teams') onto its real roster in the same call -- there's
  /// no separate "confirm the draft" step for the GM to remember.
  ///
  /// Does nothing if there's no current franchise, no draft in progress,
  /// it isn't actually the GM's turn, or [prospectPlayerId] isn't a real
  /// available prospect -- the Draft Day screen is expected to only ever
  /// offer a pick when all of those already hold, same
  /// only-call-when-valid contract every other write method here has.
  Future<void> makeDraftPick(String prospectPlayerId) async {
    final franchise = await future;
    if (franchise == null) return;
    final draft = franchise.draftInProgress;
    if (draft == null || draft.isComplete) return;
    if (draft.onTheClock != franchise.team.abbreviation) return;

    final prospectIndex = franchise.draftClass.indexWhere(
      (prospect) => prospect.player.id == prospectPlayerId,
    );
    if (prospectIndex == -1) return;
    final selected = franchise.draftClass[prospectIndex];

    final afterOwnPick = makeOwnPick(
      draft: draft,
      draftClass: franchise.draftClass,
      ownTeamAbbreviation: franchise.team.abbreviation,
      selected: selected,
      ownCoachManagement: franchise.coach.stats.management,
    );
    final afterAiPicks = resolveAiPicksUntilOwnTurn(
      draft: afterOwnPick,
      draftClass: franchise.draftClass,
      ownTeamAbbreviation: franchise.team.abbreviation,
      managementByAbbreviation: {
        for (final entry in coachesByAbbreviation(franchise).entries)
          entry.key: entry.value.stats.management,
      },
    );

    final withDraft = franchise.copyWithDraftInProgress(afterAiPicks);
    if (!afterAiPicks.isComplete) {
      await _persist(withDraft);
      return;
    }
    await _persist(
      finalizeDraft(
        Random(franchise.seasonSeed + kDraftFinalizeSeedOffset),
        withDraft,
      ),
    );
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
  /// [advanceGameDay] and [advanceGameDayWithOwnResult] both already call
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
  /// [advanceGameDay] and [advanceGameDayWithOwnResult] -- every path
  /// that can complete a week, postseason weeks included now that those
  /// play out the same day-by-day way -- means a week's report exists the
  /// instant that week finishes, full stop, with no dependence on the
  /// GM's UI timing at all.
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

  /// Every team's current active-roster injury penalty, keyed by
  /// abbreviation (2026-08-20, `injury_advancer.dart`) -- what
  /// [advanceToNextGameDay]'s `injuryPenaltyByAbbreviation` param needs so
  /// an already-hobbled player actually plays worse in their next game.
  Map<String, Map<Player, double>> _injuryPenaltyByAbbreviation(
    Franchise franchise,
  ) {
    return {
      for (final entry in rosterMembershipsByAbbreviation(franchise).entries)
        entry.key: injuryPenaltyFor(entry.value),
    };
  }

  /// Runs [resolveInjuries] against [franchise] for [gamesPlayed] --
  /// shared by every caller that just advanced through real games
  /// ([advanceGameDay], [advanceGameDayWithOwnResult]), same "one shared
  /// helper, several callers" shape [_catchUpTraining] already
  /// established.
  Franchise _withInjuriesResolved(
    Random random,
    Franchise franchise, {
    required List<GameResult> gamesPlayed,
    required bool isPostseason,
  }) {
    return resolveInjuries(
      random,
      franchise,
      gamesPlayed: gamesPlayed,
      isPostseason: isPostseason,
    );
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
