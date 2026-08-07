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
import 'package:womensbballmgr/features/news/presentation/news_screen.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

Franchise _franchiseWith({List<TrainingReport> trainingReports = const []}) {
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
    nextTrainingWeek: trainingReports.length + 1,
    trainingReports: trainingReports,
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
  testWidgets('shows an empty state before any news exists', (tester) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: NewsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No news yet'), findsOneWidget);
  });

  testWidgets(
    'lists training reports newest-first, and tapping one opens its detail',
    (tester) async {
      final playerId = generateStartingRoster(1).first.player.id;
      final franchise = _franchiseWith(
        trainingReports: [
          TrainingReport(
            week: 1,
            results: [
              PlayerGrowthResult(
                playerId: playerId,
                fieldDeltas: const {PlayerRatingField.speed: 1},
                overallBefore: 50,
                overallAfter: 50,
              ),
            ],
          ),
          const TrainingReport(week: 2, results: []),
        ],
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: NewsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Week 2 Training Report'), findsOneWidget);
      expect(find.text('Week 1 Training Report'), findsOneWidget);
      // Newest (week 2) listed above the older one (week 1).
      final week2Y = tester.getTopLeft(find.text('Week 2 Training Report')).dy;
      final week1Y = tester.getTopLeft(find.text('Week 1 Training Report')).dy;
      expect(week2Y, lessThan(week1Y));

      await tester.tap(find.text('Week 1 Training Report'));
      await tester.pumpAndSettle();

      expect(find.text('Training Report'), findsOneWidget);
      // The detail screen's own body content for that report.
      expect(find.text('1 player changed.'), findsOneWidget);
    },
  );

  testWidgets('prompts to create a franchise when none exists', (tester) async {
    final repository = InMemorySaveRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: NewsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });
}
