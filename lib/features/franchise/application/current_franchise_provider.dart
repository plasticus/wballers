import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/save_envelope.dart';
import '../../../core/persistence/save_repository_provider.dart';
import '../domain/franchise.dart';
import '../persistence/franchise_json.dart';

/// Phase 1 supports exactly one franchise save at a time -- there's no
/// save-slot picker UI yet, so every read/write goes through this one
/// fixed slot rather than [Franchise.id]. Multi-save-slot support is
/// future work once that UI exists.
const kCurrentFranchiseSaveId = 'current-franchise';

const _franchiseSchemaVersion = 1;

/// The coach's current franchise, if one has been created yet. `null`
/// means no franchise exists (onboarding hasn't run). Loads from disk on
/// first read; [createFranchise] both persists and updates this state, so
/// nothing else needs to remember to save.
class CurrentFranchiseNotifier extends AsyncNotifier<Franchise?> {
  @override
  Future<Franchise?> build() async {
    final repository = ref.watch(saveRepositoryProvider);
    final raw = await repository.readSave(kCurrentFranchiseSaveId);
    if (raw == null) return null;

    final envelope = SaveEnvelope.fromJson(raw);
    return franchiseFromJson(envelope.payload);
  }

  Future<void> createFranchise(Franchise franchise) async {
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
