import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';
import 'package:womensbballmgr/features/training/presentation/season_to_date_report_screen.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith({
  List<TrainingReport> trainingReports = const [],
  List<Player> freeAgents = const [],
}) {
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
    freeAgents: freeAgents,
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
    nextTrainingWeek: 3,
    trainingReports: trainingReports,
  );
}

void main() {
  testWidgets('sums growth across multiple weeks, sorted most-improved '
      'first, without folding in season-end aging (2026-08-10, TODO.md '
      'item 5)', (tester) async {
    final franchise = _franchiseWith();
    final steadyGrower = franchise.roster[0].player;
    final bigGrower = franchise.roster[1].player;
    final week1 = TrainingReport(
      week: 1,
      results: [
        PlayerGrowthResult(
          playerId: steadyGrower.id,
          fieldDeltas: const {PlayerRatingField.passing: 2},
          overallBefore: 50,
          overallAfter: 50,
        ),
        PlayerGrowthResult(
          playerId: bigGrower.id,
          fieldDeltas: const {PlayerRatingField.agility: 3},
          overallBefore: 60,
          overallAfter: 60,
        ),
      ],
    );
    final week2 = TrainingReport(
      week: 2,
      results: [
        PlayerGrowthResult(
          playerId: steadyGrower.id,
          fieldDeltas: const {PlayerRatingField.passing: 1},
          overallBefore: 50,
          overallAfter: 51,
        ),
        PlayerGrowthResult(
          playerId: bigGrower.id,
          fieldDeltas: const {PlayerRatingField.agility: 4},
          overallBefore: 60,
          overallAfter: 62,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonToDateReportScreen(
          franchise: _franchiseWith(trainingReports: [week1, week2]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Season To Date Report'), findsOneWidget);
    expect(
      find.text(
        '2 players moved so far this season, most improved '
        'first.',
      ),
      findsOneWidget,
    );
    // Summed across both weeks: passing +3, agility +7.
    expect(find.text('Passing +3'), findsOneWidget);
    expect(find.text('Agility +7'), findsOneWidget);
    // The bigger mover (+7) sorts above the smaller one (+3).
    final bigGrowerY = tester.getTopLeft(find.text(_playerLabel(bigGrower))).dy;
    final steadyGrowerY = tester
        .getTopLeft(find.text(_playerLabel(steadyGrower)))
        .dy;
    expect(bigGrowerY, lessThan(steadyGrowerY));
    // Season-long OVR swing shown too, same as SeasonRecapScreen's own
    // player-development section.
    expect(find.text('OVR: 60 -> 62 (+2)'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when no training has resolved '
      'yet this season', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SeasonToDateReportScreen(franchise: _franchiseWith())),
    );
    await tester.pump();

    expect(
      find.text('No training has resolved yet this season.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a player\'s own field deltas sort largest-first within their row',
    (tester) async {
      final franchise = _franchiseWith();
      final player = franchise.roster[0].player;
      final report = TrainingReport(
        week: 1,
        results: [
          PlayerGrowthResult(
            playerId: player.id,
            fieldDeltas: const {
              PlayerRatingField.disruption: 3,
              PlayerRatingField.agility: 7,
              PlayerRatingField.passing: 5,
            },
            overallBefore: 50,
            overallAfter: 51,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SeasonToDateReportScreen(
            franchise: _franchiseWith(trainingReports: [report]),
          ),
        ),
      );
      await tester.pump();

      final agilityX = tester.getTopLeft(find.text('Agility +7')).dx;
      final passingX = tester.getTopLeft(find.text('Passing +5')).dx;
      final disruptionX = tester.getTopLeft(find.text('Disruption +3')).dx;
      expect(agilityX, lessThan(passingX));
      expect(passingX, lessThan(disruptionX));
    },
  );

  testWidgets(
    'shows a waived (dropped) player\'s real name, not "Former Player" '
    '-- a direct GM report (2026-08-23): 2 clearly distinct bench '
    'players, released (not retired) mid-season, both showed up here '
    'with the exact same generic label',
    (tester) async {
      final waived = playerWithOverall(
        62,
        id: 'waived-1',
        name: 'Riley Okafor',
        primaryPosition: Position.pointGuard,
      );
      final report = TrainingReport(
        week: 1,
        results: [
          PlayerGrowthResult(
            playerId: waived.id,
            fieldDeltas: const {PlayerRatingField.agility: 1},
            overallBefore: 61,
            overallAfter: 62,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SeasonToDateReportScreen(
            franchise: _franchiseWith(
              trainingReports: [report],
              freeAgents: [waived],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Riley Okafor'), findsOneWidget);
      expect(find.textContaining('Former Player'), findsNothing);
    },
  );
}

/// Mirrors `season_to_date_report_screen.dart`'s private `_playerLabel` --
/// can't import a private function, so this is kept in sync by hand.
String _playerLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  return '${player.primaryPosition.abbreviation} $jersey${player.name}';
}
