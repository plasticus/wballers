import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../player/domain/player.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../roster/domain/roster_membership.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/game_result.dart';
import '../../season/generation/postseason_advancer.dart';
import '../../season/generation/season_advancer.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';
import '../../training/generation/training_advancer.dart';
import '../domain/franchise.dart';
import '../persistence/franchise_json.dart';

/// Phase 1 supports exactly one franchise save at a time -- there's no
/// save-slot picker UI yet, so every read/write goes through this one
/// fixed slot rather than [Franchise.id]. Multi-save-slot support is
/// future work once that UI exists.
const kCurrentFranchiseSaveId = 'current-franchise';

const _franchiseSchemaVersion = 1;

/// The GM's current franchise, if one has been created yet. `null` means
/// no franchise exists (onboarding hasn't run). Loads from disk on first
/// read; [createFranchise] and every other write method here persist and
/// update this state, so nothing else needs to remember to save.
class CurrentFranchiseNotifier extends AsyncNotifier<Franchise?> {
  @override
  Future<Franchise?> build() async {
    final repository = ref.watch(saveRepositoryProvider);
    final raw = await repository.readSave(kCurrentFranchiseSaveId);
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
  /// Returns `null` if there's no current franchise, or if the season has
  /// no game days left to advance to ([SeasonProgress.isComplete]).
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

    await _persist(franchise.copyWithSeasonProgress(advance.progress));
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

    await _persist(franchise.copyWithSeasonProgress(advance.progress));
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
  /// show it once (the Dashboard's "Training Report Ready" affordance),
  /// same "here's your transient window" deal as [advanceGameDay].
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

  Future<void> _persist(Franchise franchise) async {
    final repository = ref.read(saveRepositoryProvider);
    final envelope = SaveEnvelope(
      schemaVersion: _franchiseSchemaVersion,
      payload: franchiseToJson(franchise),
    );
    await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());
    state = AsyncData(franchise);
  }
}

final currentFranchiseProvider =
    AsyncNotifierProvider<CurrentFranchiseNotifier, Franchise?>(
      CurrentFranchiseNotifier.new,
    );
