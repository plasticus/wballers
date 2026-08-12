import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/draft/domain/draft_prospect.dart';
import 'package:womensbballmgr/features/draft/presentation/draft_day_screen.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/college.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

DraftProspect _prospect(String id, int overall) {
  return DraftProspect(
    player: playerWithOverall(overall, id: id, name: 'Prospect $id'),
    college: kColleges.first,
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
  testWidgets('shows the best-available prospects when it is the GM\'s '
      'turn, ordered best to worst', (tester) async {
    final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
    final base = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool[1],
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: const [],
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      league: testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ),
      seasonProgress: SeasonProgress(
        schedule: const SeasonSchedule(games: []),
        playedGames: const [],
        nextGameDayIndex: 0,
      ),
      trainingCoaches: const [
        TrainingCoach(name: 'Coach A'),
        TrainingCoach(name: 'Coach B'),
        TrainingCoach(name: 'Coach C'),
      ],
      trainingPlan: TrainingPlan.initial(),
      nextTrainingWeek: 1,
    ).copyWithDraftClass([_prospect('p1', 80), _prospect('p2', 70)]);
    final franchise = base.copyWithDraftInProgress(
      DraftInProgress(order: [ownAbbreviation, 'AAA'], rounds: 1),
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DraftDayScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Round 1 of 3'), findsOneWidget);
    expect(find.text('On the Clock: You'), findsOneWidget);
    expect(find.text('PG Prospect p1'), findsOneWidget);
    expect(find.text('PG Prospect p2'), findsOneWidget);
    expect(find.text('Draft'), findsNWidgets(2));
  });

  testWidgets(
    'drafting a prospect resolves the rest of the draft and shows the '
    'completion summary once every pick has landed',
    (tester) async {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final base = Franchise(
        id: 'franchise-1',
        gmName: 'Taylor Reed',
        team: kLeagueTeamPool[1],
        coach: const Coach(
          name: 'Jordan Ellis',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: const [],
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        league: testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ),
        seasonProgress: SeasonProgress(
          schedule: const SeasonSchedule(games: []),
          playedGames: const [],
          nextGameDayIndex: 0,
        ),
        trainingCoaches: const [
          TrainingCoach(name: 'Coach A'),
          TrainingCoach(name: 'Coach B'),
          TrainingCoach(name: 'Coach C'),
        ],
        trainingPlan: TrainingPlan.initial(),
        nextTrainingWeek: 1,
      ).copyWithDraftClass([_prospect('p1', 80), _prospect('p2', 70)]);
      // order.length (2) * rounds (1) == 2 total picks -- one for the GM,
      // one the AI team auto-resolves right after, so a single "Draft"
      // tap should finish the whole thing.
      final franchise = base.copyWithDraftInProgress(
        DraftInProgress(order: [ownAbbreviation, 'AAA'], rounds: 1),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DraftDayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Draft').first);
      await tester.pumpAndSettle();

      expect(find.text('Draft Complete'), findsOneWidget);
      expect(find.text('Your Picks'), findsOneWidget);
      expect(find.text('PG Prospect p1'), findsOneWidget);

      final context = tester.element(find.text('Draft Complete'));
      final container = ProviderScope.containerOf(context);
      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.draftInProgress, isNull);
      expect(updated.draftClass, isEmpty);
      expect(updated.roster.any((m) => m.player.id == 'p1'), isTrue);
    },
  );

  testWidgets(
    'the Position filter narrows the prospect list (2026-08-11, a direct '
    'GM ask: "I need to be able to sort by all the stuff, or filter. '
    'Like filter for position...")',
    (tester) async {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final base =
          Franchise(
            id: 'franchise-1',
            gmName: 'Taylor Reed',
            team: kLeagueTeamPool[1],
            coach: const Coach(
              name: 'Jordan Ellis',
              stats: CoachStats.neutral,
              archetype: CoachArchetype.steadyHand,
            ),
            roster: const [],
            simulationSeed: 1,
            replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
            league: testLeague(
              simulationSeed: 1,
              replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
            ),
            seasonProgress: SeasonProgress(
              schedule: const SeasonSchedule(games: []),
              playedGames: const [],
              nextGameDayIndex: 0,
            ),
            trainingCoaches: const [
              TrainingCoach(name: 'Coach A'),
              TrainingCoach(name: 'Coach B'),
              TrainingCoach(name: 'Coach C'),
            ],
            trainingPlan: TrainingPlan.initial(),
            nextTrainingWeek: 1,
          ).copyWithDraftClass([
            DraftProspect(
              player: playerWithOverall(
                80,
                id: 'p1',
                name: 'Prospect p1',
                primaryPosition: Position.pointGuard,
              ),
              college: kColleges.first,
            ),
            DraftProspect(
              player: playerWithOverall(
                70,
                id: 'p2',
                name: 'Prospect p2',
                primaryPosition: Position.center,
              ),
              college: kColleges.first,
            ),
          ]);
      final franchise = base.copyWithDraftInProgress(
        DraftInProgress(order: [ownAbbreviation, 'AAA'], rounds: 1),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DraftDayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('PG Prospect p1'), findsOneWidget);
      expect(find.text('C Prospect p2'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C').last);
      await tester.pumpAndSettle();

      expect(find.text('PG Prospect p1'), findsNothing);
      expect(find.text('C Prospect p2'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when there is no draft in progress', (
    tester,
  ) async {
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool[1],
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: const [],
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      league: testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ),
      seasonProgress: SeasonProgress(
        schedule: const SeasonSchedule(games: []),
        playedGames: const [],
        nextGameDayIndex: 0,
      ),
      trainingCoaches: const [
        TrainingCoach(name: 'Coach A'),
        TrainingCoach(name: 'Coach B'),
        TrainingCoach(name: 'Coach C'),
      ],
      trainingPlan: TrainingPlan.initial(),
      nextTrainingWeek: 1,
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DraftDayScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('There\'s no draft in progress right now.'),
      findsOneWidget,
    );
  });
}
