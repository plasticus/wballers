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
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';
import 'package:womensbballmgr/features/training/presentation/training_report_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith({List<Player> freeAgents = const []}) {
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

    final repository = await _seededRepository(franchise);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: TrainingReportScreen(franchise: franchise, report: report),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('2 players changed.'), findsOneWidget);
    expect(find.text(_playerLabel(growingPlayer)), findsOneWidget);
    expect(find.text(_playerLabel(decliningPlayer)), findsOneWidget);
    expect(find.text('Ball Control +1'), findsOneWidget);
    expect(find.text('Passing +2'), findsOneWidget);
    expect(find.text('Speed -2'), findsOneWidget);
    // Growth (net +3) sorted above decline (net -2).
    final growthCardY = tester
        .getTopLeft(find.text(_playerLabel(growingPlayer)))
        .dy;
    final declineCardY = tester
        .getTopLeft(find.text(_playerLabel(decliningPlayer)))
        .dy;
    expect(growthCardY, lessThan(declineCardY));
  });

  testWidgets('shows an empty-state message when nothing changed', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    const report = TrainingReport(week: 1, results: []);

    final repository = await _seededRepository(franchise);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: TrainingReportScreen(franchise: franchise, report: report),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No one moved the needle this week.'), findsOneWidget);
  });

  testWidgets(
    'shows a waived (dropped) player\'s real name, not "Former Player" '
    '-- a direct GM report (2026-08-23): 2 clearly distinct bench '
    'players, released (not retired) the same week, both showed up '
    'here with the exact same generic label',
    (tester) async {
      final waived = playerWithOverall(
        62,
        id: 'waived-1',
        name: 'Riley Okafor',
        primaryPosition: Position.pointGuard,
      );
      final franchise = _franchiseWith(freeAgents: [waived]);
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

      final repository = await _seededRepository(franchise);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: TrainingReportScreen(franchise: franchise, report: report),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Riley Okafor'), findsOneWidget);
      expect(find.textContaining('Former Player'), findsNothing);
    },
  );
}

/// Mirrors `training_report_screen.dart`'s private `_playerLabel` -- can't
/// import a private function, so this is kept in sync by hand.
String _playerLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  return '${player.primaryPosition.abbreviation} $jersey${player.name}';
}
