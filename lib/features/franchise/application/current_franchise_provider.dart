import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../player/domain/player.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/starting_lineup.dart';
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
/// read; [createFranchise] and [updateLineup] both persist and update this
/// state, so nothing else needs to remember to save.
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

  /// Replaces the starting lineup on the current franchise and persists
  /// it. Does nothing if there's no current franchise -- the lineup editor
  /// shouldn't be reachable in that state anyway.
  ///
  /// Awaits [future] rather than reading [state] directly: [state] can
  /// still be `AsyncLoading` (value `null`) if [build] hasn't resolved yet,
  /// which would make this silently no-op even though a franchise really
  /// is on its way. Awaiting guarantees the load has actually finished.
  Future<void> updateLineup(StartingLineup newLineup) async {
    final franchise = await future;
    if (franchise == null) return;
    await _persist(franchise.copyWithLineup(newLineup));
  }

  /// Replaces the coach's portrait appearance and persists it. Same
  /// no-op-if-no-franchise and await-future rationale as [updateLineup].
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
  /// [updateLineup].
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
