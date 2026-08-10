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
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/presentation/player_detail_screen.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/played_game_stat_line.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

const _statLine = PlayedGameStatLine(
  minutesPlayed: 30,
  points: 20,
  fieldGoalsMade: 8,
  fieldGoalAttempts: 15,
  threePointersMade: 2,
  threePointAttempts: 5,
  freeThrowsMade: 2,
  freeThrowAttempts: 2,
  offensiveRebounds: 1,
  defensiveRebounds: 5,
  assists: 4,
  steals: 1,
  blocks: 1,
  turnovers: 2,
  personalFouls: 2,
);

Franchise _franchiseWith({
  required RosterMembership target,
  List<PlayedGame> playedGames = const [],
}) {
  final roster = [target, ...generateStartingRoster(1).skip(1)];
  final baseProgress = testSeasonProgress(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ownTeam: kLeagueTeamPool.first,
  );
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
    seasonProgress: SeasonProgress(
      schedule: baseProgress.schedule,
      playedGames: playedGames,
      nextGameDayIndex: baseProgress.nextGameDayIndex,
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
  testWidgets('shows ratings, traits, and an empty-state note for a player '
      'with no games played yet', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final target = playerWithOverall(
      65,
      name: 'Riley Okafor',
      traits: {Trait.leader},
    );
    final franchise = _franchiseWith(
      target: RosterMembership(player: target, status: RosterStatus.active),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayerDetailScreen(franchise: franchise, playerId: target.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Riley Okafor'), findsOneWidget);
    // Position name first, full-word, archetype in parens after it -- not
    // the raw camelCase enum identifier.
    expect(find.text('Point Guard (Floor General)'), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('Leader'), findsOneWidget);
    expect(find.text('No games played yet this season.'), findsOneWidget);
    expect(find.text('No awards earned yet.'), findsOneWidget);
    // Every individual rating field is listed, not just the group overalls.
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Interior Offense'), findsOneWidget);
    expect(find.text('Potential'), findsOneWidget);
  });

  testWidgets('aggregates this-season stats from played games', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final target = playerWithOverall(65, name: 'Riley Okafor');
    final franchise = _franchiseWith(
      target: RosterMembership(player: target, status: RosterStatus.active),
      playedGames: [
        PlayedGame(
          game: ScheduledGame(
            week: 2,
            day: GameDay.sunday,
            homeTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
            awayTeamAbbreviation: 'ZZZ',
            type: GameType.regularSeason,
          ),
          homeScore: 90,
          awayScore: 80,
          boxScoreByPlayerId: {target.id: _statLine},
        ),
        PlayedGame(
          game: ScheduledGame(
            week: 2,
            day: GameDay.thursday,
            homeTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
            awayTeamAbbreviation: 'ZZZ',
            type: GameType.regularSeason,
          ),
          homeScore: 88,
          awayScore: 70,
          boxScoreByPlayerId: {target.id: _statLine},
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayerDetailScreen(franchise: franchise, playerId: target.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 games played'), findsOneWidget);
    // Both games used the same stat line, so per-game averages equal the
    // single game's own numbers exactly.
    expect(
      find.text('20.0 PPG · 6.0 RPG · 4.0 APG · 1.0 SPG · 1.0 BPG'),
      findsOneWidget,
    );
    expect(find.textContaining('FG 53%'), findsOneWidget);
  });

  testWidgets('lists earned awards', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final target = playerWithOverall(
      65,
      name: 'Riley Okafor',
      achievements: const [
        PlayerAchievementRecord(achievement: Achievement.leagueMvp, season: 0),
      ],
    );
    final franchise = _franchiseWith(
      target: RosterMembership(player: target, status: RosterStatus.active),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayerDetailScreen(franchise: franchise, playerId: target.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('League MVP (Season 0)'), findsOneWidget);
  });

  group('Drop from Roster', () {
    testWidgets('shows a confirmation dialog; cancelling leaves the roster '
        'untouched', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final target = playerWithOverall(65, name: 'Riley Okafor');
      final franchise = _franchiseWith(
        target: RosterMembership(player: target, status: RosterStatus.active),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: PlayerDetailScreen(
              franchise: franchise,
              playerId: target.id,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Drop from Roster'));
      await tester.pumpAndSettle();
      expect(find.text('Drop this player?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.roster.any((m) => m.player.id == target.id),
        isTrue,
      );
    });

    testWidgets(
      'confirming releases the player to free agency, clears their jersey '
      'number, and confirms with a SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final target = playerWithOverall(
          65,
          name: 'Riley Okafor',
        ).copyWithJerseyNumber(23);
        final franchise = _franchiseWith(
          target: RosterMembership(
            player: target,
            status: RosterStatus.active,
          ),
        );
        final repository = await _seededRepository(franchise);

        // A real navigation stack, not a bare `home:` -- the Drop flow
        // pops back to whatever's underneath after releasing the player,
        // same as it does from the real roster screen; a `PlayerDetailScreen`
        // with nothing beneath it (as every other test in this file uses,
        // none of which pop) would leave `Navigator.pop()` nothing to
        // return to.
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [saveRepositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              home: const Scaffold(body: Text('Roster')),
            ),
          ),
        );
        await tester.pump();
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) =>
                PlayerDetailScreen(franchise: franchise, playerId: target.id),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Drop from Roster'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Drop'));
        await tester.pumpAndSettle();

        // Back on the underlying screen, with the confirmation SnackBar.
        expect(find.text('Roster'), findsOneWidget);
        expect(
          find.text('Riley Okafor was released to free agency.'),
          findsOneWidget,
        );

        final saved = await repository.readSave(kCurrentFranchiseSaveId);
        final savedFranchise = franchiseFromJson(
          SaveEnvelope.fromJson(saved!).payload,
        );
        expect(
          savedFranchise.roster.any((m) => m.player.id == target.id),
          isFalse,
        );
        final droppedPlayer = savedFranchise.freeAgents.firstWhere(
          (p) => p.id == target.id,
        );
        // Cleared, not carried over -- a fresh free agent never has one,
        // and signFreeAgent assigns a new one anyway if re-signed.
        expect(droppedPlayer.jerseyNumber, isNull);
      },
    );
  });
}
