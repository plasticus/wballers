import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../domain/franchise.dart';
import '../persistence/franchise_json.dart';
import 'current_franchise_provider.dart';

/// The 3 fixed save-slot ids a GM can have a separate franchise going in
/// at once (2026-08-07, a direct GM ask: "I want to generate a few new
/// leagues/rosters to see how it goes"). Slot 1 is
/// [kCurrentFranchiseSaveId] itself, not a new id -- every pre-existing
/// save on a real device, and every test's `_seededRepository` helper
/// across the whole suite, already writes there assuming it's the one
/// [CurrentFranchiseNotifier] reads; keeping it as slot 1 means none of
/// that needed to change. Slots 2 and 3 are the new capacity.
const kSaveSlotIds = [
  kCurrentFranchiseSaveId,
  'franchise-slot-2',
  'franchise-slot-3',
];

/// Where [activeSaveSlotProvider] persists which slot is currently
/// active -- a bare slot id string, not a JSON envelope (there's nothing
/// else to version here).
const kActiveSaveSlotMetaId = 'active-save-slot';

/// Which of [kSaveSlotIds] [CurrentFranchiseNotifier] currently reads
/// from and writes to. Defaults to the first slot if nothing's been
/// chosen yet (a fresh install, or any save predating multi-slot support)
/// -- the same slot every pre-existing test and save already assumes,
/// so this is a silent, backward-compatible default rather than a
/// behavior change for anyone who never opens the Main Menu.
class ActiveSaveSlotNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final repository = ref.watch(saveRepositoryProvider);
    final raw = await repository.readSave(kActiveSaveSlotMetaId);
    if (raw != null && kSaveSlotIds.contains(raw)) return raw;
    return kSaveSlotIds.first;
  }

  /// Switches the active slot and persists the choice -- the Main Menu's
  /// "Play" action on a slot. [CurrentFranchiseNotifier] watches this
  /// provider's future, so it picks up [slotId]'s franchise (or `null`,
  /// if that slot is empty) automatically once this resolves.
  Future<void> setActiveSlot(String slotId) async {
    assert(kSaveSlotIds.contains(slotId), 'not a real save slot: $slotId');
    final repository = ref.read(saveRepositoryProvider);
    await repository.writeSave(kActiveSaveSlotMetaId, slotId);
    state = AsyncData(slotId);
  }
}

final activeSaveSlotProvider =
    AsyncNotifierProvider<ActiveSaveSlotNotifier, String>(
      ActiveSaveSlotNotifier.new,
    );

/// Reads [slotId]'s franchise directly, independent of whichever slot is
/// currently active -- what the Main Menu's slot picker needs to show a
/// summary for a slot the GM isn't necessarily playing right now.
/// `null` means that slot has no save yet.
final saveSlotFranchiseProvider = FutureProvider.family<Franchise?, String>((
  ref,
  slotId,
) async {
  final repository = ref.watch(saveRepositoryProvider);
  final raw = await repository.readSave(slotId);
  if (raw == null) return null;
  return franchiseFromJson(SaveEnvelope.fromJson(raw).payload);
});

/// Deletes [slotId]'s save and refreshes both [saveSlotFranchiseProvider]
/// (so the Main Menu's card for it goes back to "Empty") and
/// [currentFranchiseProvider] (in case [slotId] happened to be the active
/// slot -- deleting it out from under an open franchise shouldn't leave
/// stale data on screen).
Future<void> deleteSaveSlot(WidgetRef ref, String slotId) async {
  final repository = ref.read(saveRepositoryProvider);
  await repository.deleteSave(slotId);
  ref.invalidate(saveSlotFranchiseProvider(slotId));
  ref.invalidate(currentFranchiseProvider);
}
