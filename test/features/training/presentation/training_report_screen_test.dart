import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';
import 'package:womensbballmgr/features/training/presentation/training_report_screen.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

Franchise _franchiseWith() {
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

void main() {
  testWidgets('shows a growth chip and a decline chip, sorted growth first', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final growingPlayer = franchise.roster[0].player;
    final decliningPlayer = franchise.roster[1].player;
    final report = TrainingReport(
      week: 3,
      results: [
        PlayerGrowthResult(
          playerId: decliningPlayer.id,
          fieldDeltas: const {PlayerRatingField.speed: -2},
          overallBefore: 60,
          overallAfter: 60,
        ),
        PlayerGrowthResult(
          playerId: growingPlayer.id,
          fieldDeltas: const {
            PlayerRatingField.ballControl: 1,
            PlayerRatingField.passing: 2,
          },
          overallBefore: 50,
          overallAfter: 50,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingReportScreen(franchise: franchise, report: report),
      ),
    );
    await tester.pump();

    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('2 players changed.'), findsOneWidget);
    expect(find.text(growingPlayer.name), findsOneWidget);
    expect(find.text(decliningPlayer.name), findsOneWidget);
    expect(find.text('Ball Control +1'), findsOneWidget);
    expect(find.text('Passing +2'), findsOneWidget);
    expect(find.text('Speed -2'), findsOneWidget);
    // Growth (net +3) sorted above decline (net -2).
    final growthCardY = tester.getTopLeft(find.text(growingPlayer.name)).dy;
    final declineCardY = tester.getTopLeft(find.text(decliningPlayer.name)).dy;
    expect(growthCardY, lessThan(declineCardY));
  });

  testWidgets('shows an empty-state message when nothing changed', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    const report = TrainingReport(week: 1, results: []);

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingReportScreen(franchise: franchise, report: report),
      ),
    );
    await tester.pump();

    expect(find.text('No one moved the needle this week.'), findsOneWidget);
  });
}
