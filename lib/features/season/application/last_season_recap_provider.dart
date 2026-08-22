import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../franchise/application/save_slots.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/persistence/franchise_json.dart';

/// A completed season's franchise, frozen exactly as it stood right
/// before the transition into the season now underway -- reachable from
/// the Dashboard's own recap card, a direct GM ask (2026-08-22): "I need
/// a way to re-open that report once season 2 has started ... skimmed
/// the end season report a little too fast."
///
/// [SeasonRecapScreen] itself reads several season-scoped
/// [Franchise] fields ([Franchise.leagueRetirements],
/// [Franchise.trainingReports], [Franchise.seasonEndAgingResults], the
/// just-finished season's own [Franchise.seasonProgress]) that
/// [Franchise.copyWithNewSeason] wipes the instant the next season
/// begins -- there's no way to recompute this recap from the live
/// franchise once that's happened. Rather than adding a new persisted
/// field to [Franchise] itself (every field there costs a matching edit
/// across ~23 hand-written `copyWith*` methods), this snapshot is
/// stored as a standalone save entry, sibling to the slot's own real
/// save rather than inside it -- [beginNextSeasonAndPersist] writes it
/// immediately before persisting the transitioned franchise, using the
/// exact same [franchiseToJson]/[SaveEnvelope] machinery a real save
/// already uses. Overwritten on every later transition, so this always
/// holds the *most recently completed* season only, never a growing
/// history.
String lastSeasonRecapSaveId(String slotId) => '${slotId}_last_recap';

Future<void> saveLastSeasonRecap(
  SaveRepository repository,
  String slotId,
  Franchise franchise,
) async {
  final envelope = SaveEnvelope(
    schemaVersion: 1,
    payload: franchiseToJson(franchise),
  );
  await repository.writeSave(lastSeasonRecapSaveId(slotId), envelope.toJson());
}

/// The active slot's [saveLastSeasonRecap] snapshot, or `null` if no
/// season has ever transitioned in this slot yet. Re-reads whenever
/// [activeSaveSlotProvider] changes, same "follow the active slot"
/// posture [currentFranchiseProvider] itself has.
final lastSeasonRecapProvider = FutureProvider<Franchise?>((ref) async {
  final repository = ref.watch(saveRepositoryProvider);
  final slotId = await ref.watch(activeSaveSlotProvider.future);
  final raw = await repository.readSave(lastSeasonRecapSaveId(slotId));
  if (raw == null) return null;
  return franchiseFromJson(SaveEnvelope.fromJson(raw).payload);
});
