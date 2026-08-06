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
import 'package:womensbballmgr/features/franchise/presentation/lineup_editor_screen.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWithTwoPointGuards() {
  final roster = [
    RosterMembership(
      player: playerWithOverall(
        60,
        id: 'pg-starter',
        name: 'Starting PG',
        primaryPosition: Position.pointGuard,
      ),
      status: RosterStatus.active,
    ),
    RosterMembership(
      player: playerWithOverall(
        50,
        id: 'pg-bench',
        name: 'Bench PG',
        primaryPosition: Position.pointGuard,
      ),
      status: RosterStatus.active,
    ),
    for (final position in [
      Position.shootingGuard,
      Position.smallForward,
      Position.powerForward,
      Position.center,
    ])
      RosterMembership(
        player: playerWithOverall(
          50,
          id: position.name,
          name: position.name,
          primaryPosition: position,
        ),
        status: RosterStatus.active,
      ),
  ];

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
  );
}

void main() {
  testWidgets('defaults to the best-available starter at each position', (
    tester,
  ) async {
    final franchise = _franchiseWithTwoPointGuards();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: MaterialApp(home: LineupEditorScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    // The higher-overall point guard should be the pre-selected starter.
    expect(find.text('Starting PG (60 OVR)'), findsOneWidget);
  });

  testWidgets('saving persists the new lineup and returns to the caller', (
    tester,
  ) async {
    final franchise = _franchiseWithTwoPointGuards();
    final repository = InMemorySaveRepository();
    final envelope = SaveEnvelope(
      schemaVersion: 1,
      payload: franchiseToJson(franchise),
    );
    await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LineupEditorScreen(franchise: franchise),
                  ),
                ),
                child: const Text('Open lineup editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open lineup editor'));
    await tester.pumpAndSettle();

    // Switch the point guard dropdown to the bench player. Invoking the
    // real onChanged directly rather than simulating the popup-menu tap
    // sequence -- the overlay route's open/close timing proved flaky to
    // drive via taps, but this still exercises the actual production
    // callback, just not the pixel-level menu interaction.
    final pgDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    pgDropdown.onChanged!('pg-bench');
    await tester.pumpAndSettle();

    // Confirms the selection actually took (not just that the callback was
    // called): the field's displayed value should now be the bench player.
    expect(find.text('Bench PG (50 OVR)'), findsOneWidget);
    expect(find.text('Starting PG (60 OVR)'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Lineup'));
    await tester.pumpAndSettle();

    expect(find.text('Open lineup editor'), findsOneWidget);
    expect(find.byType(LineupEditorScreen), findsNothing);

    final context = tester.element(find.text('Open lineup editor'));
    final container = ProviderScope.containerOf(context);
    final saved = container.read(currentFranchiseProvider).value;

    expect(
      saved?.startingLineup.startersByPosition[Position.pointGuard],
      'pg-bench',
    );
  });
}
