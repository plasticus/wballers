import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/postseason_advancer.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/presentation/season_recap_screen.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

/// Plays a real franchise all the way through the regular season,
/// Continental Cup, and postseason -- same "play it for real, don't fake
/// the data" approach `current_franchise_provider_test.dart`'s own
/// postseason test uses.
Franchise _playFullSeason(int simulationSeed) {
  var franchise = createExpansionFranchise(
    gmName: 'Jordan Ellis',
    clubName: 'Comets',
    homeCity: 'Springfield, IL',
    conference: Conference.atlantic,
    replacedTeamAbbreviation: 'BOS',
    colors: kStarterPalettes.first,
    emoji: '🏀',
    simulationSeed: simulationSeed,
  );
  final rosters = rostersByAbbreviation(franchise);

  var progress = franchise.seasonProgress;
  var guard = 0;
  while (!progress.isComplete && guard < 60) {
    final advance = advanceToNextGameDay(
      Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset + guard),
      progress,
      rostersByAbbreviation: rosters,
    );
    progress = advance.progress;
    guard++;
  }
  franchise = franchise.copyWithSeasonProgress(progress);

  final postseasonAdvance = simulatePostseason(
    Random(franchise.simulationSeed + kPostseasonAdvanceSeedOffset),
    franchise.seasonProgress,
    leagueTeams: allLeagueTeams(franchise),
    rostersByAbbreviation: rosters,
  );
  return franchise.copyWithSeasonProgress(postseasonAdvance.progress);
}

void main() {
  testWidgets('shows the champion and the GM\'s own final record', (
    tester,
  ) async {
    final franchise = _playFullSeason(1);
    final champion = seasonChampion(franchise.seasonProgress.playedGames);
    expect(champion, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('Season Recap'), findsOneWidget);
    expect(find.textContaining('Final record:'), findsOneWidget);
    expect(find.text('What\'s Next', skipOffstage: false), findsOneWidget);

    if (champion == franchise.team.abbreviation) {
      expect(find.text('🏆 You are the champions!'), findsOneWidget);
    } else {
      expect(find.textContaining('are the champions.'), findsOneWidget);
    }
  });

  testWidgets('shows a missed-the-playoffs message when the GM\'s own team '
      'never appears in a postseason game', (tester) async {
    final roster = generateStartingRoster(1);
    final baseProgress = testSeasonProgress(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool.first,
    );
    final league = testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    );
    // Two real AI teams from this franchise's own league play the
    // Finals -- teamByAbbreviation would throw on a made-up abbreviation
    // that isn't actually part of the league.
    final finalist1 = league.aiTeams[0].team.abbreviation;
    final finalist2 = league.aiTeams[1].team.abbreviation;
    final finals = ScheduledGame(
      week: 24,
      day: GameDay.thursday,
      homeTeamAbbreviation: finalist1,
      awayTeamAbbreviation: finalist2,
      type: GameType.postseason,
      postseasonRound: 3,
    );
    final franchise = Franchise(
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
      league: league,
      seasonProgress: SeasonProgress(
        schedule: baseProgress.schedule,
        playedGames: [PlayedGame(game: finals, homeScore: 90, awayScore: 80)],
        nextGameDayIndex: 999,
      ),
      trainingCoaches: testTrainingCoaches(),
      trainingPlan: TrainingPlan.initial(),
      nextTrainingWeek: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('🏆 You are the champions!'), findsNothing);
    expect(find.textContaining('You missed the playoffs'), findsOneWidget);
  });
}
