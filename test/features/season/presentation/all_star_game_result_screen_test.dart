import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/played_game_stat_line.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/all_star_generator.dart';
import 'package:womensbballmgr/features/season/presentation/all_star_game_result_screen.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../roster/domain/roster_test_helpers.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

/// Pads [ids] to exactly 10 -- same reasoning as
/// `skills_competition_result_screen_test.dart`'s own `_squadOf`.
List<String> _squadOf(String label, List<String> ids) => [
  ...ids,
  for (var i = ids.length; i < 10; i++) '$label-filler-$i',
];

League _leagueWithPlayer(League league, Player player) {
  final first = league.aiTeams.first;
  return League(
    aiTeams: [
      first.copyWithRoster([
        ...first.roster,
        RosterMembership(player: player, status: RosterStatus.active),
      ]),
      ...league.aiTeams.skip(1),
    ],
  );
}

PlayedGameStatLine _line({
  required double minutes,
  required int points,
  int assists = 0,
  int rebounds = 0,
  int steals = 0,
  int blocks = 0,
}) {
  return PlayedGameStatLine(
    minutesPlayed: minutes,
    points: points,
    fieldGoalsMade: 0,
    fieldGoalAttempts: 0,
    threePointersMade: 0,
    threePointAttempts: 0,
    freeThrowsMade: 0,
    freeThrowAttempts: 0,
    offensiveRebounds: 0,
    defensiveRebounds: rebounds,
    assists: assists,
    steals: steals,
    blocks: blocks,
    turnovers: 0,
    personalFouls: 0,
  );
}

void main() {
  testWidgets(
    'shows the final score, names the real MVP, and highlights the GM\'s '
    'own player (2026-08-10, TODO.md item 5)',
    (tester) async {
      final ownStar = playerWithOverall(90, id: 'own-1', name: 'Own Star');
      final rival = playerWithOverall(85, id: 'rival-1', name: 'Rival One');
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
        roster: [
          ...roster,
          RosterMembership(player: ownStar, status: RosterStatus.active),
        ],
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        league: _leagueWithPlayer(
          testLeague(
            simulationSeed: 1,
            replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
          ),
          rival,
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

      final squads = {
        Conference.atlantic: _squadOf('atl', [ownStar.id]),
        Conference.pacific: _squadOf('pac', [rival.id]),
      };
      final playedGame = PlayedGame(
        game: const ScheduledGame(
          week: kAllStarWeek,
          day: kAllStarGameDay,
          homeTeamAbbreviation: kAtlanticAllStarsAbbreviation,
          awayTeamAbbreviation: kPacificAllStarsAbbreviation,
          type: GameType.allStarGame,
        ),
        homeScore: 150,
        awayScore: 140,
        boxScoreByPlayerId: {
          // Own star's composite (34 + 6 + 5 + 1 + 0 = 46) beats the
          // rival's (20 + 2 + 1 + 0 + 0 = 23) -- own star should win MVP.
          ownStar.id: _line(
            minutes: 30,
            points: 34,
            rebounds: 6,
            assists: 5,
            steals: 1,
          ),
          rival.id: _line(minutes: 28, points: 20, rebounds: 2, assists: 1),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AllStarGameResultScreen(
              franchise: franchise,
              playedGame: playedGame,
              squads: squads,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('All-Star Game'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      // Every player mention is followed by the team they actually play
      // for (2026-08-11, a direct GM ask) -- own star is on the GM's own
      // team, the rival is on the first AI team.
      final ownAbbreviation = kLeagueTeamPool.first.abbreviation;
      final rivalAbbreviation =
          franchise.league.aiTeams.first.team.abbreviation;
      expect(
        find.text(
          'Own Star ($ownAbbreviation) is the All-Star Game MVP -- your '
          'player!',
        ),
        findsOneWidget,
      );
      expect(find.text('Own Star ($ownAbbreviation)'), findsWidgets);
      expect(find.text('Rival One ($rivalAbbreviation)'), findsWidgets);
    },
  );

  testWidgets('tapping a box score row opens that player\'s detail screen '
      '(2026-08-11, a direct GM ask -- "I want to be able to click players '
      'and see detail screen")', (tester) async {
    // The rival's row is below the fold at the default test surface size.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ownStar = playerWithOverall(90, id: 'own-1', name: 'Own Star');
    final rival = playerWithOverall(85, id: 'rival-1', name: 'Rival One');
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
      roster: [
        ...roster,
        RosterMembership(player: ownStar, status: RosterStatus.active),
      ],
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      league: _leagueWithPlayer(
        testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ),
        rival,
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

    final squads = {
      Conference.atlantic: _squadOf('atl', [ownStar.id]),
      Conference.pacific: _squadOf('pac', [rival.id]),
    };
    final playedGame = PlayedGame(
      game: const ScheduledGame(
        week: kAllStarWeek,
        day: kAllStarGameDay,
        homeTeamAbbreviation: kAtlanticAllStarsAbbreviation,
        awayTeamAbbreviation: kPacificAllStarsAbbreviation,
        type: GameType.allStarGame,
      ),
      homeScore: 150,
      awayScore: 140,
      boxScoreByPlayerId: {
        ownStar.id: _line(
          minutes: 30,
          points: 34,
          rebounds: 6,
          assists: 5,
          steals: 1,
        ),
        rival.id: _line(minutes: 28, points: 20, rebounds: 2, assists: 1),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AllStarGameResultScreen(
            franchise: franchise,
            playedGame: playedGame,
            squads: squads,
          ),
        ),
      ),
    );
    await tester.pump();

    final rivalAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
    await tester.tap(find.text('Rival One ($rivalAbbreviation)').first);
    await tester.pumpAndSettle();

    // "Ratings" is unique to `PlayerDetailScreen` -- neither result
    // screen has a section by that name.
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('Player Not Found'), findsNothing);
  });
}
