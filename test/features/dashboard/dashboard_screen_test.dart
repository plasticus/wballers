import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/dashboard/dashboard_screen.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/mail/domain/mail_item.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/free_agent_pool_generator.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart'
    show weekLabel;
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../support/in_memory_portrait_cache.dart';
import '../../support/in_memory_save_repository.dart';
import '../../support/league_test_helpers.dart';
import '../../support/portrait_test_helpers.dart';
import '../../support/season_test_helpers.dart';
import '../../support/training_test_helpers.dart';

/// A 12th active player -- `generateStartingRoster` deliberately produces
/// only 11 now (see its own doc comment), one short of a full roster, so
/// the Dashboard's "Advance to Next Game Day" button gates itself away.
/// Most of this file's tests aren't about that gate at all and just want
/// a normal, playable franchise, so `_franchiseWith` tops the roster up
/// with this directly rather than routing every test through a real
/// free-agent signing.
RosterMembership _twelfthActiveMember() {
  return RosterMembership(
    player: Player(
      id: 'signed-extra',
      name: 'Signed Extra',
      age: 24,
      yearsOfService: 2,
      hometown: 'Anywhere, USA',
      primaryPosition: Position.center,
      secondaryPositions: const {},
      handedness: Handedness.right,
      biography: '',
      ratings: const PlayerRatings(
        speed: 55,
        agility: 55,
        strength: 55,
        stamina: 55,
        ballControl: 55,
        passing: 55,
        interiorOffense: 55,
        perimeterOffense: 55,
        perimeterDefense: 55,
        interiorDefense: 55,
        disruption: 55,
        blocking: 55,
        potential: 60,
      ),
      heightInches: 76,
      archetype: Archetype.shotBlocker,
      traits: const {},
    ),
    status: RosterStatus.active,
  );
}

Franchise _franchiseWith({
  SeasonProgress? seasonProgress,
  List<TrainingReport> trainingReports = const [],
  // A full 12 by default -- most tests here just want a normal, playable
  // franchise. The Assistant-GM-mail/advance-gate test below is the one
  // exception, and passes false to see the real 11-player starting shape.
  bool includeTwelfthMember = true,
  List<Player> freeAgents = const [],
  Set<String> readMailIds = const {},
  DraftInProgress? draftInProgress,
}) {
  final roster = [
    ...generateStartingRoster(1),
    if (includeTwelfthMember) _twelfthActiveMember(),
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
    freeAgents: freeAgents,
    nextTrainingWeek: 1,
    trainingReports: trainingReports,
    readMailIds: readMailIds,
    draftInProgress: draftInProgress,
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

  testWidgets(
    'shows a Return to Draft button instead of Advance to Next Game Day '
    'while a draft is in progress, and it actually opens Draft Day -- a '
    'real bug, live on-device (2026-08-19, a direct GM report): "I left '
    'the draft to look at my roster. And now .. where did the draft go?! '
    'No idea... During the draft, there should not be an advance to next '
    'game day button -- there should just be a button to jump you back '
    'into the draft"',
    (tester) async {
      final franchise = _franchiseWith(
        draftInProgress: DraftInProgress(
          order: [kLeagueTeamPool.first.abbreviation, 'ZZZ'],
          rounds: 3,
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

      expect(find.text('Advance to Next Game Day'), findsNothing);
      expect(find.text('Draft In Progress'), findsOneWidget);
      expect(find.text('Return to Draft'), findsOneWidget);

      await tester.tap(find.text('Return to Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Draft Day'), findsOneWidget);
    },
  );

  testWidgets('shows the current fictional date and week on the Season card '
      '(2026-08-09, a direct GM ask)', (tester) async {
    // Nothing played yet -- "current" is the season's very first game
    // day, the preseason opener, which formatFictionalDate/weekLabel
    // both special-case to read "Week 0".
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(weekLabel(1)), findsOneWidget);
  });

  testWidgets(
    'splices a Trade Deadline row into Upcoming Games once the Week 6/7 '
    'boundary is one of the next few games, while the window\'s still '
    'open (2026-08-19, a direct GM call: "it\'ll show up on... the '
    'little dashboard calendar, too")',
    (tester) async {
      final ownAbbreviation = kLeagueTeamPool.first.abbreviation;
      final league = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: ownAbbreviation,
      );
      final opponent = league.aiTeams[0].team.abbreviation;
      ScheduledGame ownGameAt(int week) => ScheduledGame(
        week: week,
        day: GameDay.sunday,
        homeTeamAbbreviation: ownAbbreviation,
        awayTeamAbbreviation: opponent,
        type: GameType.regularSeason,
      );
      final franchise = _franchiseWith(
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [ownGameAt(5), ownGameAt(6), ownGameAt(7)],
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

      expect(find.textContaining('Trade Deadline'), findsOneWidget);
    },
  );

  testWidgets('never shows the Trade Deadline row once the window\'s already '
      'closed', (tester) async {
    final ownAbbreviation = kLeagueTeamPool.first.abbreviation;
    final league = testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: ownAbbreviation,
    );
    final opponent = league.aiTeams[0].team.abbreviation;
    final franchise = _franchiseWith(
      seasonProgress: SeasonProgress(
        schedule: SeasonSchedule(
          games: [
            ScheduledGame(
              week: 7,
              day: GameDay.sunday,
              homeTeamAbbreviation: ownAbbreviation,
              awayTeamAbbreviation: opponent,
              type: GameType.regularSeason,
            ),
          ],
        ),
        playedGames: const [],
        // Already on the clock for the Week 7 game itself.
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

    expect(find.textContaining('Trade Deadline'), findsNothing);
  });

  testWidgets(
    'doesn\'t show the Trade Deadline row while it\'s still further out '
    'than the visible upcoming games',
    (tester) async {
      final ownAbbreviation = kLeagueTeamPool.first.abbreviation;
      final league = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: ownAbbreviation,
      );
      final opponent = league.aiTeams[0].team.abbreviation;
      ScheduledGame ownGameAt(int week) => ScheduledGame(
        week: week,
        day: GameDay.sunday,
        homeTeamAbbreviation: ownAbbreviation,
        awayTeamAbbreviation: opponent,
        type: GameType.regularSeason,
      );
      final franchise = _franchiseWith(
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [ownGameAt(2), ownGameAt(3), ownGameAt(4)],
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

      expect(find.textContaining('Trade Deadline'), findsNothing);
    },
  );

  testWidgets(
    'shows an Assistant GM mail card naming the pool\'s best prospect, and '
    'hides the advance button, while the roster is short a player',
    (tester) async {
      final freeAgents = generateFreeAgentPool(
        Random(1 + kFreeAgentPoolSeedOffset),
      );
      final franchise = _franchiseWith(
        includeTwelfthMember: false,
        freeAgents: freeAgents,
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From Your Assistant GM'), findsOneWidget);
      final prospect = freeAgents.reduce(
        (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
      );
      expect(find.textContaining(prospect.name), findsOneWidget);
      expect(find.text('Open Player Market'), findsOneWidget);

      // Nothing to press -- the gate is real, not just a UI suggestion.
      expect(find.text('Advance to Next Game Day'), findsNothing);
      expect(
        find.textContaining('Sign a free agent to fill your roster'),
        findsOneWidget,
      );
    },
  );

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

      // Either the GM's own game was part of that day -- in which case
      // tapping just opened `MatchPreviewScreen`'s "Play Game", not the
      // result yet -- or it wasn't (straight to a snackbar summarizing
      // what happened across the league). Which one depends on the
      // generated schedule, not something worth pinning down here.
      final wentToPreview = find.text('Play Game').evaluate().isNotEmpty;
      if (wentToPreview) {
        // Watch Live defaults on (2026-08-18, `TODO.md` item 8's live-game
        // architecture stage 5) -- this test is about the day actually
        // advancing and persisting, not watching a real game play out beat
        // by beat in real time, so it opts out first.
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.tap(find.text('Play Game'));
        await tester.pumpAndSettle();
      }

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

  testWidgets(
    'shows a Continental Cup Week note on the Season card when the next '
    'game day is a Cup round, even with no game of the GM\'s own that day '
    '(2026-08-10, TODO.md item 12)',
    (tester) async {
      final league = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      );
      final ai1 = league.aiTeams[0].team.abbreviation;
      final ai2 = league.aiTeams[1].team.abbreviation;
      final franchise = _franchiseWith(
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [
              ScheduledGame(
                week: 4,
                day: GameDay.thursday,
                homeTeamAbbreviation: ai1,
                awayTeamAbbreviation: ai2,
                type: GameType.continentalCup,
                continentalCupRound: 1,
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

      expect(find.text('Continental Cup Week'), findsOneWidget);
      // Not eliminated -- no follow-up note.
      expect(find.textContaining('eliminated'), findsNothing);
    },
  );

  testWidgets(
    'adds an elimination follow-up note once the GM\'s own team is already '
    'out of the Cup (2026-08-10, TODO.md item 12)',
    (tester) async {
      final league = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      );
      final ownAbbreviation = kLeagueTeamPool.first.abbreviation;
      final eliminator = league.aiTeams[0].team.abbreviation;
      final ai1 = league.aiTeams[1].team.abbreviation;
      final ai2 = league.aiTeams[2].team.abbreviation;
      final franchise = _franchiseWith(
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [
              ScheduledGame(
                week: 6,
                day: GameDay.thursday,
                homeTeamAbbreviation: ai1,
                awayTeamAbbreviation: ai2,
                type: GameType.continentalCup,
                continentalCupRound: 2,
              ),
            ],
          ),
          playedGames: [
            // The GM's own team lost Round 1 -- already out.
            PlayedGame(
              game: ScheduledGame(
                week: 4,
                day: GameDay.thursday,
                homeTeamAbbreviation: eliminator,
                awayTeamAbbreviation: ownAbbreviation,
                type: GameType.continentalCup,
                continentalCupRound: 1,
              ),
              homeScore: 80,
              awayScore: 70,
            ),
          ],
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

      expect(find.text('Continental Cup Week'), findsOneWidget);
      expect(find.textContaining('eliminated in the Round 1'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a "No Game Today" note on a plain regular-season bye day -- no '
    'Continental Cup involved at all (2026-08-15, a direct GM report: '
    '"I need to know why" my team isn\'t playing this game day)',
    (tester) async {
      final league = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      );
      final ai1 = league.aiTeams[0].team.abbreviation;
      final ai2 = league.aiTeams[1].team.abbreviation;
      final franchise = _franchiseWith(
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [
              ScheduledGame(
                week: 9,
                day: GameDay.sunday,
                homeTeamAbbreviation: ai1,
                awayTeamAbbreviation: ai2,
                type: GameType.regularSeason,
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

      expect(find.text('No Game Today'), findsOneWidget);
      expect(find.text('Continental Cup Week'), findsNothing);
    },
  );

  testWidgets('advancing through a Continental Cup-only game day names the Cup '
      'specifically in the snackbar (2026-08-10, TODO.md item 12)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final league = testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    );
    final ai1 = league.aiTeams[0].team.abbreviation;
    final ai2 = league.aiTeams[1].team.abbreviation;
    final franchise = _franchiseWith(
      seasonProgress: SeasonProgress(
        schedule: SeasonSchedule(
          games: [
            // Round 5 (the Final) specifically -- any earlier round
            // makes `advanceToNextGameDay` try to auto-generate the
            // *next* round from "today's results", which asserts on
            // a real full field (e.g. Round 1 needs all 10 games'
            // worth of results); Round 5 is the championship, nothing
            // auto-generates after it, so a single hand-built game is
            // safe to advance through.
            ScheduledGame(
              week: 12,
              day: GameDay.thursday,
              homeTeamAbbreviation: ai1,
              awayTeamAbbreviation: ai2,
              type: GameType.continentalCup,
              continentalCupRound: 5,
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
        // `DashboardScreen` itself has no `Scaffold` (it's always
        // hosted inside `AppShell`'s in the real app) -- every other
        // test in this file only ever reaches `MatchPreviewScreen`'s
        // own route, never this screen's own `showSnackBar` call, so
        // this is the first test that actually needs one here.
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Advance to Next Game Day'));
    await tester.pumpAndSettle();

    // The GM's own team has no game this day (both scheduled teams are
    // AI), so this always lands on the snackbar branch, never a
    // MatchPreviewScreen/GameResultScreen detour.
    expect(
      find.text('Simulating 1 Continental Cup game across the league.'),
      findsOneWidget,
    );
  });

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

  testWidgets(
    'once a champion is crowned, also offers "Available Head Coaches" '
    '(2026-08-19, a direct GM ask: "During the offseason, maybe there\'s '
    'a new button on the Dashboard")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = _franchiseWith();
      final league = base.league;
      final totalGameDays = gameDaysInOrder(
        base.seasonProgress.schedule,
      ).length;
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
          overrides: [
            saveRepositoryProvider.overrideWithValue(repository),
            portraitCacheProvider.overrideWithValue(InMemoryPortraitCache()),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Available Head Coaches'), findsOneWidget);

      await tester.tap(find.text('Available Head Coaches'));
      await letPortraitAsyncWorkFinish(tester);

      expect(find.text('Available Head Coaches'), findsWidgets);
      expect(find.text('Hire'), findsWidgets);
    },
  );

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
      // Already read -- this test is only about the Recent News preview
      // list, not the unread-report affordance covered by the
      // 'training-ready affordance' group above.
      final franchise = _franchiseWith(
        trainingReports: const [report],
        readMailIds: {trainingReportMailId(3)},
      );
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
    testWidgets('bounces to MainMenuScreen when the active save fails to load '
        '(2026-08-10, a direct GM report: no automatic recovery before this)', (
      tester,
    ) async {
      final repository = InMemorySaveRepository();
      // Not franchiseToJson's real output -- an empty payload that
      // franchiseFromJson can't possibly parse, standing in for a save
      // that fails to load at boot (an old save from before a schema
      // change, most likely -- this codebase's own delete-and-recreate
      // save convention means that's expected, not a bug to migrate
      // around).
      await repository.writeSave(
        kCurrentFranchiseSaveId,
        const SaveEnvelope(schemaVersion: 1, payload: {}).toJson(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a save to play, or start a new one.'),
        findsOneWidget,
      );
      expect(find.text('Could not load your franchise save.'), findsNothing);
    });

    testWidgets('has a Mail tab that opens MailScreen', (tester) async {
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

      await tester.tap(find.widgetWithText(NavigationDestination, 'Mail'));
      await tester.pumpAndSettle();

      // The AppBar title switches to "Mail" (findsWidgets since the
      // NavigationDestination label reads the same). A full roster
      // (`_franchiseWith`'s default) always has at least the
      // roster-complete system message now (2026-08-10) -- there's no
      // "genuinely empty" inbox for a real franchise anymore.
      expect(find.text('Mail'), findsWidgets);
      expect(find.text('Roster Set'), findsOneWidget);
    });

    testWidgets('has a Settings button in the AppBar that opens '
        'SettingsScreen', (tester) async {
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Text Size'), findsOneWidget);
    });

    testWidgets('has a Game Guide button in the AppBar that opens '
        'GuideScreen', (tester) async {
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Game Guide'), findsOneWidget);
      expect(find.text('Coaching'), findsOneWidget);
      expect(find.text('How Training Works'), findsOneWidget);
    });

    testWidgets(
      'shows a red unread badge on the Mail tab while the roster is short '
      'a player, and it clears once the inbox is opened',
      (tester) async {
        final freeAgents = generateFreeAgentPool(
          Random(1 + kFreeAgentPoolSeedOffset),
        );
        final franchise = _franchiseWith(
          includeTwelfthMember: false,
          freeAgents: freeAgents,
        );
        final repository = await _seededRepository(franchise);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [saveRepositoryProvider.overrideWithValue(repository)],
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Badge), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Badge), matching: find.text('1')),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(NavigationDestination, 'Mail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Last Roster Spot'));
        await tester.pumpAndSettle();

        // Pop back off the mail detail route to the shell, then back to
        // Dashboard -- the badge is gone now that the one mail item has
        // been opened.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Dashboard'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Badge), findsNothing);
      },
    );
  });
}
