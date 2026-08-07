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
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../support/in_memory_save_repository.dart';
import '../../support/league_test_helpers.dart';
import '../../support/season_test_helpers.dart';
import '../../support/training_test_helpers.dart';

Franchise _franchiseWith({
  SeasonProgress? seasonProgress,
  List<TrainingReport> trainingReports = const [],
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
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
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
  testWidgets('shows the season record and an upcoming-games preview', (
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
    expect(find.text('Upcoming Games'), findsOneWidget);
    expect(find.text('Advance to Next Game Day'), findsOneWidget);
  });

  testWidgets('does not show the hero splash once a franchise exists', (
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

    expect(find.text('Women\'s Basketball Manager'), findsNothing);
    expect(
      find.text('Build a franchise. Shape a league. Leave a legacy.'),
      findsNothing,
    );
  });

  testWidgets('shows the hero splash when there is no franchise yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Women\'s Basketball Manager'), findsOneWidget);
  });

  testWidgets('shows the team emoji as a logo on the team card', (
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

    expect(find.text(kLeagueTeamPool.first.emoji), findsOneWidget);
  });

  testWidgets(
    'lists the next 3 upcoming games with date, opponent, and record',
    (tester) async {
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final upcoming = upcomingGamesFor(
        franchise.seasonProgress,
        franchise.team.abbreviation,
      );
      expect(upcoming, hasLength(3));

      for (final game in upcoming) {
        final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
        final opponentAbbreviation = isHome
            ? game.awayTeamAbbreviation
            : game.homeTeamAbbreviation;
        final opponent = kLeagueTeamPool.firstWhere(
          (t) => t.abbreviation == opponentAbbreviation,
        );
        expect(
          find.text(
            '${formatFictionalDate(game.week, game.day)} '
            '${isHome ? 'vs' : '@'} ${opponent.emoji} ${opponent.name} '
            '(0-0)',
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'marks a preseason game in the upcoming-games list -- doesn\'t count '
    'toward the record',
    (tester) async {
      final base = _franchiseWith();
      final opponentAbbreviation = base.league.aiTeams.first.team.abbreviation;
      final franchise = base.copyWithSeasonProgress(
        SeasonProgress(
          schedule: SeasonSchedule(
            games: [
              ScheduledGame(
                week: 1,
                day: GameDay.sunday,
                homeTeamAbbreviation: base.team.abbreviation,
                awayTeamAbbreviation: opponentAbbreviation,
                type: GameType.preseason,
              ),
            ],
          ),
          playedGames: const [],
          nextGameDayIndex: 0,
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

      expect(find.text('PRESEASON'), findsOneWidget);
    },
  );

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

  testWidgets('once a champion is crowned, offers "View Season Recap"', (
    tester,
  ) async {
    // The trophy banner and its button need to be on-screen for tap() to
    // hit test it, same rationale as the other Dashboard-button tests.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = _franchiseWith();
    final league = base.league;
    final totalGameDays = gameDaysInOrder(base.seasonProgress.schedule).length;
    final finals = ScheduledGame(
      week: 24,
      day: GameDay.thursday,
      homeTeamAbbreviation: league.aiTeams[0].team.abbreviation,
      awayTeamAbbreviation: league.aiTeams[1].team.abbreviation,
      type: GameType.postseason,
      postseasonRound: 3,
    );
    final franchise = _franchiseWith(
      seasonProgress: SeasonProgress(
        schedule: base.seasonProgress.schedule,
        playedGames: [PlayedGame(game: finals, homeScore: 90, awayScore: 80)],
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

    expect(find.textContaining('are the champions!'), findsOneWidget);
    expect(find.text('View Season Recap'), findsOneWidget);

    await tester.tap(find.text('View Season Recap'));
    await tester.pumpAndSettle();

    expect(find.text('Season Recap'), findsOneWidget);
  });

  group('training-ready affordance', () {
    testWidgets('is not shown before a full training week has been played', (
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

      expect(find.text('Training Report Ready'), findsNothing);
    });

    testWidgets(
      'appears once the preseason week is fully played, and tapping it '
      'resolves training and opens the report',
      (tester) async {
        // The Training card sits below the Season card -- needs a taller
        // surface for its button to be on-screen for tap(), same rationale
        // as the Advance-to-Next-Game-Day test above.
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final base = _franchiseWith();
        // The preseason (week 1) has 2 game days -- both played means the
        // week is fully complete and ready for training.
        final franchise = _franchiseWith(
          seasonProgress: SeasonProgress(
            schedule: base.seasonProgress.schedule,
            playedGames: const [],
            nextGameDayIndex: 2,
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

        expect(find.text('Training Report Ready'), findsOneWidget);

        await tester.tap(find.text('View Training Report'));
        await tester.pumpAndSettle();

        expect(find.text('Training Report'), findsOneWidget);
        expect(find.text('Week 1'), findsOneWidget);

        final saved = await repository.readSave(kCurrentFranchiseSaveId);
        final savedFranchise = franchiseFromJson(
          SaveEnvelope.fromJson(saved!).payload,
        );
        expect(savedFranchise.nextTrainingWeek, 2);
        expect(savedFranchise.trainingReports, hasLength(1));
      },
    );
  });

  testWidgets(
    'shows a Recent News preview at the bottom of the Dashboard, tappable '
    'to the full report',
    (tester) async {
      // The Recent News card sits at the very bottom of the scroll, below
      // the Season card's upcoming-games list -- needs a tall surface to
      // be on-screen and tap-hittable.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const report = TrainingReport(week: 3, results: []);
      final franchise = _franchiseWith(trainingReports: const [report]);
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Week 3 Training Report'), findsOneWidget);

      await tester.tap(find.textContaining('Week 3 Training Report'));
      await tester.pumpAndSettle();

      expect(find.text('Training Report'), findsOneWidget);
      expect(find.text('Week 3'), findsOneWidget);
    },
  );

  group('AppShell', () {
    testWidgets('has a News tab that opens NewsScreen', (tester) async {
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsWidgets);

      await tester.tap(find.widgetWithText(NavigationDestination, 'News'));
      await tester.pumpAndSettle();

      // The AppBar title switches to "News" (findsWidgets since the
      // NavigationDestination label reads the same).
      expect(find.text('News'), findsWidgets);
      expect(find.textContaining('No news yet'), findsOneWidget);
    });
  });
}
