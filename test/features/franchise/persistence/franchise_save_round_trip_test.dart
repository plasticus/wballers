import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/file_save_repository.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

import '../../roster/domain/roster_test_helpers.dart';

/// Proves the Phase 0 persistence layer (`SaveEnvelope`/`SaveRepository`)
/// actually works end-to-end with real game data, not just test strings.
void main() {
  late Directory tempDir;
  late FileSaveRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'wballers_franchise_save_test_',
    );
    repository = FileSaveRepository(resolveBaseDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a franchise survives being wrapped in a SaveEnvelope, written, and '
      're-read as a brand new repository instance', () async {
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kInitialLeagueTeams.first,
      coach: const Coach(name: 'Jordan Ellis', stats: CoachStats.neutral),
      roster: [
        for (var i = 0; i < 12; i++)
          RosterMembership(
            player: playerWithOverall(50 + i, name: 'Player $i'),
            status: RosterStatus.active,
          ),
        RosterMembership(
          player: playerWithOverall(45, name: 'Prospect', yearsOfService: 0),
          status: RosterStatus.developmental,
        ),
      ],
      simulationSeed: 12345,
    );

    final envelope = SaveEnvelope(
      schemaVersion: 1,
      payload: franchiseToJson(franchise),
    );
    await repository.writeSave(franchise.id, envelope.toJson());

    // A fresh repository instance against the same directory, simulating
    // a full app restart rather than just re-reading in-memory state.
    final reopened = FileSaveRepository(
      resolveBaseDirectory: () async => tempDir,
    );
    final raw = await reopened.readSave(franchise.id);
    final restoredEnvelope = SaveEnvelope.fromJson(raw!);
    final restored = franchiseFromJson(restoredEnvelope.payload);

    expect(restoredEnvelope.schemaVersion, 1);
    expect(restored.id, franchise.id);
    expect(restored.gmName, franchise.gmName);
    expect(restored.simulationSeed, franchise.simulationSeed);
    expect(restored.team.abbreviation, franchise.team.abbreviation);
    expect(restored.coach.name, franchise.coach.name);
    expect(restored.roster, hasLength(13));
    expect(
      restored.roster.where((m) => m.status == RosterStatus.active),
      hasLength(12),
    );
    expect(
      restored.roster
          .where((m) => m.status == RosterStatus.developmental)
          .single
          .player
          .name,
      'Prospect',
    );
  });
}
