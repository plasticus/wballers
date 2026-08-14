import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/franchise/presentation/depth_chart_screen.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

Franchise _franchiseWith({List<RosterMembership>? extraMembers}) {
  final roster = [...generateStartingRoster(1), ...?extraMembers];
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: roster,
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress: testSeasonProgress(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool.first,
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

RosterMembership _developmentalMember(String id) {
  return RosterMembership(
    player: Player(
      id: id,
      name: 'Rookie $id',
      age: 20,
      yearsOfService: 0,
      hometown: 'Anywhere, USA',
      primaryPosition: Position.pointGuard,
      secondaryPositions: const {},
      handedness: Handedness.right,
      biography: '',
      ratings: const PlayerRatings(
        speed: 50,
        agility: 50,
        strength: 50,
        stamina: 50,
        ballControl: 50,
        passing: 50,
        interiorOffense: 50,
        perimeterOffense: 50,
        perimeterDefense: 50,
        interiorDefense: 50,
        disruption: 50,
        blocking: 50,
        potential: 60,
      ),
      heightInches: 70,
      archetype: Archetype.floorGeneral,
      traits: const {},
    ),
    status: RosterStatus.developmental,
  );
}

/// A 12th active player -- `generateStartingRoster` deliberately produces
/// only 11 now (see its own doc comment), one short of a full roster; the
/// gap is meant to be filled by signing a free agent, not something this
/// bench-order-focused test file cares about. Tests here that need a full
/// 12-player active roster to exercise the ranking table add this one
/// directly instead.
RosterMembership _activeMember(String id) {
  return RosterMembership(
    player: Player(
      id: id,
      name: 'Signed $id',
      age: 24,
      yearsOfService: 2,
      hometown: 'Anywhere, USA',
      primaryPosition: Position.center,
      secondaryPositions: const {},
      handedness: Handedness.right,
      biography: '',
      ratings: const PlayerRatings(
        speed: 55,
        agility: 55,
        strength: 55,
        stamina: 55,
        ballControl: 55,
        passing: 55,
        interiorOffense: 55,
        perimeterOffense: 55,
        perimeterDefense: 55,
        interiorDefense: 55,
        disruption: 55,
        blocking: 55,
        potential: 60,
      ),
      heightInches: 76,
      archetype: Archetype.shotBlocker,
      traits: const {},
    ),
    status: RosterStatus.active,
  );
}

/// A deliberately maxed-out player -- 99 (the scale's actual ceiling,
/// `kMaxRating`) across the board -- so an OVR sort has an unambiguous,
/// seed-independent winner regardless of what `generateStartingRoster`
/// happened to roll for everyone else. Was 95 flat until
/// `starting_roster_generator.dart`'s 2026-08-14 revision raised the
/// hand-placed franchise vet's own quality center to 95 -- close enough
/// (with her own spread and a favorable position bias) to occasionally
/// tie or edge out a flat-95 fixture, which this test can't tolerate.
RosterMembership _highOverallMember(String id) {
  return RosterMembership(
    player: Player(
      id: id,
      name: 'Star $id',
      age: 26,
      yearsOfService: 4,
      hometown: 'Anywhere, USA',
      primaryPosition: Position.center,
      secondaryPositions: const {},
      handedness: Handedness.right,
      biography: '',
      ratings: const PlayerRatings(
        speed: 99,
        agility: 99,
        strength: 99,
        stamina: 99,
        ballControl: 99,
        passing: 99,
        interiorOffense: 99,
        perimeterOffense: 99,
        perimeterDefense: 99,
        interiorDefense: 99,
        disruption: 99,
        blocking: 99,
        potential: 99,
      ),
      heightInches: 76,
      archetype: Archetype.shotBlocker,
      traits: const {},
    ),
    status: RosterStatus.active,
  );
}

Future<InMemorySaveRepository> _seededRepository(Franchise franchise) async {
  final repository = InMemorySaveRepository();
  final envelope = SaveEnvelope(
    schemaVersion: 1,
    payload: franchiseToJson(franchise),
  );
  await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());
  return repository;
}

void main() {
  testWidgets('lists the active roster ranked 1-12 with target minutes', (
    tester,
  ) async {
    // All 12 active rows need to be on-screen at once -- the default test
    // surface is too short to lay out a 12-row ReorderableListView, which
    // (like a regular ListView) only builds items near the viewport.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWith(extraMembers: [_activeMember('extra-1')]);
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: DepthChartScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    final active = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .toList();
    expect(active.length, 12);

    for (final membership in active) {
      expect(find.text(_rowLabel(membership.player)), findsOneWidget);
    }
    expect(find.text('30 min'), findsNWidgets(3));
    expect(find.text('4 min'), findsNWidgets(2));
  });

  testWidgets('shows developmental players separately at 0 minutes', (
    tester,
  ) async {
    final franchise = _franchiseWith(
      extraMembers: [_developmentalMember('dev-1')],
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: DepthChartScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    expect(find.text('Developmental (0 min)'), findsOneWidget);
    expect(
      find.text(_rowLabel(_developmentalMember('dev-1').player)),
      findsOneWidget,
    );
  });

  testWidgets(
    '"Let the Coach Set the Order" ranks by OVR and notes developmental '
    'minutes are still the GM\'s call',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final star = _highOverallMember('star-1');
      final franchise = _franchiseWith(extraMembers: [star]);
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: DepthChartScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Let the Coach Set the Order'));
      await tester.pump();

      expect(
        find.textContaining('developmental minutes are still your call'),
        findsOneWidget,
      );

      final active = franchise.roster
          .where((m) => m.status == RosterStatus.active)
          .toList();
      final starY = tester.getTopLeft(find.text(_rowLabel(star.player))).dy;
      for (final membership in active) {
        if (membership.player.id == star.player.id) continue;
        final y = tester.getTopLeft(find.text(_rowLabel(membership.player))).dy;
        expect(
          starY,
          lessThan(y),
          reason: 'the 99-OVR star should rank above ${membership.player.name}',
        );
      }
    },
  );

  testWidgets('Save Bench Order persists the roster and returns', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DepthChartScreen(franchise: franchise),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Order'), findsWidgets);

    await tester.tap(find.text('Save Bench Order'));
    await tester.pumpAndSettle();

    // Back on the launcher screen.
    expect(find.text('Open'), findsOneWidget);

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final envelope = SaveEnvelope.fromJson(saved!);
    final savedFranchise = franchiseFromJson(envelope.payload);
    final savedActiveIds = savedFranchise.roster
        .where((m) => m.status == RosterStatus.active)
        .map((m) => m.player.id)
        .toList();
    final originalActiveIds = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .map((m) => m.player.id)
        .toList();
    expect(savedActiveIds, originalActiveIds);
  });
}

/// Mirrors `depth_chart_screen.dart`'s private `_rowLabel` -- can't import
/// a private function, so this is kept in sync by hand.
String _rowLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  return '${player.primaryPosition.abbreviation} $jersey${player.lastName} '
      '(${player.archetype.label}, ${player.ratings.overall} OVR)';
}
