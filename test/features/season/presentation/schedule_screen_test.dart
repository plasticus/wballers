import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/presentation/schedule_screen.dart';

void main() {
  testWidgets('lists only the GM\'s own games, all upcoming before any '
      'are played', (tester) async {
    // A full season's worth of the GM's own rows (preseason + regular
    // season + Continental Cup Round 1, ~31 games) needs to all be
    // on-screen at once -- the default test surface is too short to lay
    // out a ListView this long, which only builds items near the
    // viewport.
    tester.view.physicalSize = const Size(800, 6000);
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
    final ownGameCount = franchise.seasonProgress.schedule.games
        .where(
          (g) =>
              g.homeTeamAbbreviation == franchise.team.abbreviation ||
              g.awayTeamAbbreviation == franchise.team.abbreviation,
        )
        .length;
    // The preseason alone guarantees at least 2 games for every team.
    expect(ownGameCount, greaterThan(0));

    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Upcoming'), findsNWidgets(ownGameCount));
  });

  testWidgets('shows a final score once a game day is played', (tester) async {
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

    final advance = advanceToNextGameDay(
      Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset),
      franchise.seasonProgress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
    );
    final playedFranchise = franchise.copyWithSeasonProgress(advance.progress);

    GameResult? ownGame;
    for (final result in advance.gamesPlayed) {
      if (result.game.homeTeamAbbreviation == franchise.team.abbreviation ||
          result.game.awayTeamAbbreviation == franchise.team.abbreviation) {
        ownGame = result;
        break;
      }
    }
    // The preseason schedules every team on both of its game days, so the
    // very first game day always includes the GM's own team.
    expect(ownGame, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(franchise: playedFranchise)),
    );
    await tester.pump();

    final isHome =
        ownGame!.game.homeTeamAbbreviation == franchise.team.abbreviation;
    final ownScore = isHome ? ownGame.match.homeScore : ownGame.match.awayScore;
    final opponentScore = isHome
        ? ownGame.match.awayScore
        : ownGame.match.homeScore;
    final expectedLetter = ownScore > opponentScore ? 'W' : 'L';

    expect(
      find.text('$expectedLetter $ownScore-$opponentScore'),
      findsOneWidget,
    );
  });
}
