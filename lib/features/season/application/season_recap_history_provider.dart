import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../../franchise/application/save_slots.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/persistence/franchise_json.dart';

/// Every completed season's franchise, frozen exactly as it stood right
/// before the transition into the season that followed it -- kept for
/// the life of the save, one entry per season, not just the most recent
/// (2026-08-22, a direct GM ask: "I want to keep post season reports
/// forever (well, for the life of the save). They all need to live
/// somewhere.").
///
/// [SeasonRecapScreen] itself reads several season-scoped [Franchise]
/// fields ([Franchise.leagueRetirements], [Franchise.trainingReports],
/// [Franchise.seasonEndAgingResults], the just-finished season's own
/// [Franchise.seasonProgress]) that [Franchise.copyWithNewSeason] wipes
/// the instant the next season begins -- there's no way to recompute a
/// completed season's recap from the live franchise afterward. Rather
/// than adding a new persisted field to [Franchise] itself (every field
/// there costs a matching edit across ~23 hand-written `copyWith*`
/// methods), each season's snapshot is stored as its own standalone
/// save entry, sibling to the slot's own real save rather than inside
/// it -- [beginNextSeasonAndPersist] writes it immediately before
/// persisting the transitioned franchise, using the exact same
/// [franchiseToJson]/[SaveEnvelope] machinery a real save already uses.
///
/// A first pass (2026-08-22, earlier the same day) kept only the single
/// most recently completed season, overwriting it on every later
/// transition -- the direct follow-up GM report above caught that this
/// didn't actually satisfy "re-open that report", since anything before
/// the latest season was gone for good. [seasonRecapSeasonsProvider]'s
/// own index (a bare JSON list of season numbers, not wrapped in a
/// [SaveEnvelope] -- same "nothing else to version here" reasoning
/// `save_slots.dart`'s own `kActiveSaveSlotMetaId` uses) is what makes
/// every past season's recap independently reachable rather than just
/// the newest.
String seasonRecapSaveId(String slotId, int season) =>
    '${slotId}_recap_season_$season';

/// Where the active slot's list of "which seasons have a saved recap"
/// lives -- read by [seasonRecapSeasonsProvider], kept in sync by every
/// [saveSeasonRecap] call.
String seasonRecapIndexSaveId(String slotId) => '${slotId}_recap_index';

Future<void> saveSeasonRecap(
  SaveRepository repository,
  String slotId,
  Franchise franchise,
) async {
  final envelope = SaveEnvelope(
    schemaVersion: 1,
    payload: franchiseToJson(franchise),
  );
  await repository.writeSave(
    seasonRecapSaveId(slotId, franchise.season),
    envelope.toJson(),
  );

  final indexId = seasonRecapIndexSaveId(slotId);
  final existingRaw = await repository.readSave(indexId);
  final seasons = <int>{
    if (existingRaw != null) ...(jsonDecode(existingRaw) as List).cast<int>(),
    franchise.season,
  };
  final sorted = seasons.toList()..sort();
  await repository.writeSave(indexId, jsonEncode(sorted));
}

/// Every season the active slot has a saved recap for, most recently
/// completed first -- empty before any season has ever transitioned.
final seasonRecapSeasonsProvider = FutureProvider<List<int>>((ref) async {
  final repository = ref.watch(saveRepositoryProvider);
  final slotId = await ref.watch(activeSaveSlotProvider.future);
  final raw = await repository.readSave(seasonRecapIndexSaveId(slotId));
  if (raw == null) return const [];
  final seasons = (jsonDecode(raw) as List).cast<int>();
  return seasons.reversed.toList();
});

/// [season]'s frozen recap franchise for the active slot, or `null` if
/// nothing was ever saved for it (an in-progress season, or a season
/// number that never actually existed in this save).
final seasonRecapProvider = FutureProvider.family<Franchise?, int>((
  ref,
  season,
) async {
  final repository = ref.watch(saveRepositoryProvider);
  final slotId = await ref.watch(activeSaveSlotProvider.future);
  final raw = await repository.readSave(seasonRecapSaveId(slotId, season));
  if (raw == null) return null;
  return franchiseFromJson(SaveEnvelope.fromJson(raw).payload);
});
