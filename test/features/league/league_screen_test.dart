import 'dart:math';

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
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league_draw.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/league_screen.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import '../../support/in_memory_save_repository.dart';
import '../../support/league_test_helpers.dart';
import '../../support/season_test_helpers.dart';
import '../../support/training_test_helpers.dart';

Future<void> _pumpWithRepository(
  WidgetTester tester,
  InMemorySaveRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: LeagueScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('with no franchise, prompts to create one', (tester) async {
    await _pumpWithRepository(tester, InMemorySaveRepository());

    expect(
      find.text('Create an expansion franchise to see your league.'),
      findsOneWidget,
    );
    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });

  testWidgets(
    'with a franchise, lists this playthrough\'s drawn 20-team league, '
    'with the replaced team swapped for the GM club',
    (tester) async {
      const simulationSeed = 1;
      final drawnTeams = drawLeagueTeams(
        Random(simulationSeed + kLeagueDrawSeedOffset),
      );
      final replaced = drawnTeams.firstWhere(
        (team) => team.conference == Conference.atlantic,
      );
      const clubTeam = Team(
        abbreviation: 'BRS',
        location: 'New Orleans, LA',
        name: 'New Orleans Brass',
        conference: Conference.atlantic,
        colors: TeamColors(
          primaryHex: '#14213D',
          secondaryHex: '#FCA311',
          accentHex: '#E5E5E5',
        ),
        identityNote: 'A new franchise chasing its first banner.',
        emoji: '🏀',
      );
      final roster = generateStartingRoster(1);
      final franchise = Franchise(
        id: 'franchise-1',
        gmName: 'Taylor Reed',
        team: clubTeam,
        coach: const Coach(
          name: 'Jordan Ellis',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: roster,
        simulationSeed: simulationSeed,
        replacedTeamAbbreviation: replaced.abbreviation,
        league: testLeague(
          simulationSeed: simulationSeed,
          replacedTeamAbbreviation: replaced.abbreviation,
        ),
        seasonProgress: testSeasonProgress(
          simulationSeed: simulationSeed,
          replacedTeamAbbreviation: replaced.abbreviation,
          ownTeam: clubTeam,
        ),
        trainingCoaches: testTrainingCoaches(),
        trainingPlan: TrainingPlan.initial(),
        nextTrainingWeek: 1,
      );

      final repository = InMemorySaveRepository();
      await repository.writeSave(
        kCurrentFranchiseSaveId,
        SaveEnvelope(
          schemaVersion: 1,
          payload: franchiseToJson(franchise),
        ).toJson(),
      );

      await _pumpWithRepository(tester, repository);

      expect(find.text(clubTeam.name), findsOneWidget);
      expect(find.text('Your Team'), findsOneWidget);
      expect(find.text(replaced.name), findsNothing);
      final activePlayers = [
        for (final m in roster)
          if (m.status == RosterStatus.active) m.player,
      ];
      expect(
        find.textContaining('${teamOverallForPlayers(activePlayers)} OVR'),
        findsOneWidget,
      );

      // Every other drawn Atlantic team is still listed untouched.
      final otherAtlanticTeams = drawnTeams.where(
        (team) =>
            team.conference == Conference.atlantic &&
            team.abbreviation != replaced.abbreviation,
      );
      for (final team in otherAtlanticTeams) {
        expect(find.text(team.name), findsOneWidget);
      }

      // The drawn Pacific half is below the fold in the test viewport.
      await tester.scrollUntilVisible(
        find.text('Pacific Conference'),
        300,
        scrollable: find.byType(Scrollable),
      );
      final pacificTeams = drawnTeams.where(
        (team) => team.conference == Conference.pacific,
      );
      for (final team in pacificTeams) {
        expect(find.text(team.name), findsOneWidget);
      }

      // No games played yet -- every team shows a 0-0 record.
      expect(find.text('0-0'), findsNWidgets(20));
    },
  );

  testWidgets('"Schedule" and "Results" open their respective screens', (
    tester,
  ) async {
    final roster = generateStartingRoster(1);
    final franchise = Franchise(
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
    final repository = InMemorySaveRepository();
    await repository.writeSave(
      kCurrentFranchiseSaveId,
      SaveEnvelope(
        schemaVersion: 1,
        payload: franchiseToJson(franchise),
      ).toJson(),
    );

    await _pumpWithRepository(tester, repository);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('No games scheduled yet.'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Schedule'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Results'), findsOneWidget);
    expect(find.text('No games played yet.'), findsOneWidget);
  });
}
