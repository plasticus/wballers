import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/presentation/game_result_screen.dart';

void main() {
  testWidgets('shows the final score and a box score for both teams', (
    tester,
  ) async {
    // Both teams' box scores (up to 12 rows each) need to be on-screen at
    // once -- the default test surface is too short to lay out a
    // ListView this long, which only builds items near the viewport.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
      simulationSeed: 1,
    );
    final opponent = franchise.league.aiTeams.first.team;
    final rosters = rostersByAbbreviation(franchise);
    final match = simulateMatch(
      Random(1),
      homeRoster: rosters[franchise.team.abbreviation]!,
      awayRoster: rosters[opponent.abbreviation]!,
    );
    final result = GameResult(
      game: ScheduledGame(
        week: 2,
        day: GameDay.sunday,
        homeTeamAbbreviation: franchise.team.abbreviation,
        awayTeamAbbreviation: opponent.abbreviation,
        type: GameType.regularSeason,
      ),
      match: match,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameResultScreen(franchise: franchise, result: result),
      ),
    );
    await tester.pump();

    expect(find.text('Game Result'), findsOneWidget);
    expect(find.text('FINAL'), findsOneWidget);
    expect(find.text('${match.homeScore}'), findsOneWidget);
    expect(find.text('${match.awayScore}'), findsOneWidget);
    // Once in the score card, once as the box score section header.
    expect(
      find.text('${franchise.team.location} ${franchise.team.name}'),
      findsNWidgets(2),
    );
    expect(
      find.text('${opponent.location} ${opponent.name}'),
      findsNWidgets(2),
    );
    // At least one player from each roster shows up with a stat line.
    expect(find.textContaining('PTS'), findsWidgets);
  });
}
