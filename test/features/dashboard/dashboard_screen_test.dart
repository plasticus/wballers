import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/dashboard/dashboard_screen.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';

import '../../support/in_memory_save_repository.dart';
import '../../support/league_test_helpers.dart';
import '../../support/season_test_helpers.dart';

Franchise _franchiseWith({SeasonProgress? seasonProgress}) {
  final roster = generateStartingRoster(1);
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
    startingLineup: StartingLineup.bestAvailable(roster),
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress:
        seasonProgress ??
        testSeasonProgress(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
          ownTeam: kLeagueTeamPool.first,
        ),
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
  testWidgets('shows the season record and a next-game-day preview', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Season'), findsOneWidget);
    expect(find.text('0-0'), findsOneWidget);
    expect(find.textContaining('Next:'), findsOneWidget);
    expect(find.text('Advance to Next Game Day'), findsOneWidget);
  });

  testWidgets(
    'tapping Advance to Next Game Day simulates a game day and reacts to it',
    (tester) async {
      // The Season card (and its button) needs to be on-screen for tap() to
      // hit test it -- the default test surface is too short once the hero
      // logo pushes everything else further down.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advance to Next Game Day'));
      await tester.pumpAndSettle();

      // Either the GM's own game was part of that day (Game Result opens)
      // or it wasn't (a snackbar summarizes what else happened across the
      // league) -- which one depends on the generated schedule, not
      // something worth pinning down here. Either way, the season moved.
      final openedGameResult = find.text('Game Result').evaluate().isNotEmpty;
      final showedSnackBar = find
          .textContaining('simulated across the league')
          .evaluate()
          .isNotEmpty;
      expect(openedGameResult || showedSnackBar, isTrue);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.seasonProgress.nextGameDayIndex, 1);
    },
  );

  testWidgets('offers "Simulate Postseason" once there are no game days left', (
    tester,
  ) async {
    final base = _franchiseWith();
    final totalGameDays = gameDaysInOrder(base.seasonProgress.schedule).length;
    final franchise = _franchiseWith(
      seasonProgress: SeasonProgress(
        schedule: base.seasonProgress.schedule,
        playedGames: const [],
        nextGameDayIndex: totalGameDays,
      ),
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regular season complete.'), findsOneWidget);
    expect(find.text('Simulate Postseason'), findsOneWidget);
    expect(find.text('Advance to Next Game Day'), findsNothing);
  });
}
