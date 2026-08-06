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
import 'package:womensbballmgr/features/franchise/presentation/team_roster_screen.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

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
    startingLineup: StartingLineup.bestAvailable(roster),
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
  testWidgets('with no franchise, prompts to create one', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Create an expansion franchise to see your roster.'),
      findsOneWidget,
    );
    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });

  testWidgets('with a franchise, shows the team and the active roster', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    expect(find.text(franchise.team.name), findsOneWidget);
    expect(find.text('Active Roster (12)'), findsOneWidget);
    expect(
      find.textContaining(franchise.roster.first.player.name),
      findsOneWidget,
    );
  });

  testWidgets('a developmental player gets its own section', (tester) async {
    final developmentalPlayer = generateStartingRoster(99).first.player;
    final franchise = _franchiseWith(
      extraMembers: [
        RosterMembership(
          player: developmentalPlayer,
          status: RosterStatus.developmental,
        ),
      ],
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    // The Developmental section is below the fold behind 12 active-roster
    // rows; the ListView only builds slivers near the viewport.
    await tester.scrollUntilVisible(
      find.text('Developmental (1)'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Developmental (1)'), findsOneWidget);
  });

  testWidgets(
    'shows a player\'s height and offense/defense/physical overalls',
    (tester) async {
      final player = playerWithOverall(70, heightInches: 74);
      final franchise = _franchiseWith(
        extraMembers: [
          RosterMembership(player: player, status: RosterStatus.developmental),
        ],
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: TeamRosterScreen()),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Developmental (1)'),
        300,
        scrollable: find.byType(Scrollable),
      );

      expect(find.textContaining('6\'2"'), findsWidgets);
      expect(find.text('OFF 70 · DEF 70 · PHY 70'), findsOneWidget);
    },
  );

  testWidgets('a player\'s traits show as chips naming each one', (
    tester,
  ) async {
    final traitedPlayer = playerWithOverall(
      70,
      traits: {Trait.leader, Trait.sharpshooter},
    );
    final franchise = _franchiseWith(
      extraMembers: [
        RosterMembership(
          player: traitedPlayer,
          status: RosterStatus.developmental,
        ),
      ],
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Developmental (1)'),
      300,
      scrollable: find.byType(Scrollable),
    );

    // findsWidgets, not findsOneWidget: the randomly generated active
    // roster could coincidentally include another player with the same
    // trait -- this test only cares that the deliberately-traited player's
    // chips render, not roster-wide uniqueness.
    expect(find.text('Leader'), findsWidgets);
    expect(find.text('Sharpshooter'), findsWidgets);
  });

  testWidgets('with no developmental or reserve players, those sections '
      'are hidden', (tester) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Developmental'), findsNothing);
    expect(find.textContaining('Reserve'), findsNothing);
  });

  testWidgets('tapping a player row opens their Player Detail screen', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);
    final targetPlayer = franchise.roster.first.player;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TeamRosterScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.textContaining(targetPlayer.name).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, targetPlayer.name), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
  });
}
