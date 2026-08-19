import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';
import 'package:womensbballmgr/features/season/presentation/team_calendar_screen.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

Franchise _franchiseWith(SeasonProgress seasonProgress) {
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: generateStartingRoster(1),
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress: seasonProgress,
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

void main() {
  // A small, hand-built schedule -- not a real generated one -- so every
  // row this screen can produce (a played own game, a bye with no note, a
  // Cup elimination, a bye *with* the elimination note, and every
  // milestone) is deterministically present, rather than depending on
  // whatever a random seed's real schedule happens to contain.
  // Real AI teams from this playthrough's own drawn league -- not
  // arbitrary `kLeagueTeamPool` indices, which aren't guaranteed to be
  // among the 19 teams `generateLeague` actually drew for this seed.
  final league = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final ownTeam = kLeagueTeamPool.first.abbreviation;
  final opponent = league.aiTeams[0].team;
  final byeWeekAi1 = league.aiTeams[1].team.abbreviation;
  final byeWeekAi2 = league.aiTeams[2].team.abbreviation;
  final eliminator = league.aiTeams[3].team;
  final round2Ai1 = league.aiTeams[4].team.abbreviation;
  final round2Ai2 = league.aiTeams[5].team.abbreviation;

  final ownWin = ScheduledGame(
    week: 2,
    day: GameDay.sunday,
    homeTeamAbbreviation: ownTeam,
    awayTeamAbbreviation: opponent.abbreviation,
    type: GameType.regularSeason,
  );
  final sameWeekBye = ScheduledGame(
    week: 2,
    day: GameDay.thursday,
    homeTeamAbbreviation: byeWeekAi1,
    awayTeamAbbreviation: byeWeekAi2,
    type: GameType.regularSeason,
  );
  final cupRound1Loss = ScheduledGame(
    week: kContinentalCupRound1Week,
    day: kContinentalCupGameDay,
    homeTeamAbbreviation: eliminator.abbreviation,
    awayTeamAbbreviation: ownTeam,
    type: GameType.continentalCup,
    continentalCupRound: 1,
  );
  final cupRound2Bye = ScheduledGame(
    week: kContinentalCupRound2Week,
    day: kContinentalCupGameDay,
    homeTeamAbbreviation: round2Ai1,
    awayTeamAbbreviation: round2Ai2,
    type: GameType.continentalCup,
    continentalCupRound: 2,
  );

  final seasonProgress = SeasonProgress(
    schedule: SeasonSchedule(
      games: [ownWin, sameWeekBye, cupRound1Loss, cupRound2Bye],
    ),
    playedGames: [
      PlayedGame(game: ownWin, homeScore: 80, awayScore: 70),
      PlayedGame(game: cupRound1Loss, homeScore: 90, awayScore: 80),
    ],
    nextGameDayIndex: 4,
  );

  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: TeamCalendarScreen(franchise: _franchiseWith(seasonProgress)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a played own game with its real result', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('vs ${opponent.emoji} ${opponent.name}'), findsOneWidget);
    expect(find.text('W 80-70'), findsOneWidget);
  });

  testWidgets(
    'shows a plain bye day (no Cup note) for a week the league played but '
    'this team didn\'t, alongside the separately-noted Cup elimination bye',
    (tester) async {
      await pumpCalendar(tester);

      // 2 byes total (week 2 Thursday, week 6 Thursday) but only 1
      // elimination note -- proves the week 2 bye specifically stays
      // plain rather than picking up a note of its own.
      expect(find.text('Bye'), findsNWidgets(2));
      expect(find.textContaining("you're out (eliminated"), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Continental Cup Round 1 loss as a real game, not a bye',
    (tester) async {
      await pumpCalendar(tester);

      expect(
        find.text('at ${eliminator.emoji} ${eliminator.name}'),
        findsOneWidget,
      );
      expect(find.text('L 80-90'), findsOneWidget);
    },
  );

  testWidgets(
    'notes a later Cup round bye as an elimination, not just a plain bye '
    '(2026-08-15, a direct GM ask: "if it\'s a cup day... the cup games '
    'should be noted")',
    (tester) async {
      await pumpCalendar(tester);

      expect(
        find.textContaining(
          "Continental Cup Round 2 -- you're out (eliminated in Round 1)",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('lists the regular-season-end, postseason, and draft milestones '
      '(2026-08-15, a direct GM ask: "end of regular season date, draft '
      'date, everything relevant to my team")', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('Regular Season Ends'), findsOneWidget);
    expect(find.text('Postseason: First Round'), findsOneWidget);
    expect(find.text('Postseason: Semifinals'), findsOneWidget);
    expect(find.text('Postseason: Finals'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Once the postseason wraps up'), findsOneWidget);
  });

  testWidgets('lists the Trade Deadline milestone, locked to the end of Week 6 '
      '(2026-08-19, a direct GM call)', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('Trade Deadline'), findsOneWidget);
    expect(find.text('Trades close once Week 7 begins'), findsOneWidget);
  });
}
