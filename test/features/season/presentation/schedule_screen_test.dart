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
    // Every franchise's very first game day is preseason -- flagged
    // clearly since a real, scored preseason game doesn't move the
    // standings, which read as a bug before this was surfaced on screen.
    // findsWidgets, not findsOneWidget: the preseason schedules 2 games
    // for every team, both showing this note.
    expect(
      find.textContaining('Preseason -- exhibition, doesn\'t count'),
      findsWidgets,
    );
  });

  testWidgets(
    'the Full League toggle lists every team\'s games, grouped by week, '
    'not just the GM\'s own',
    (tester) async {
      // Week 1 alone has 20 preseason games (10 per game day) -- needs a
      // tall surface to have the target game on-screen without scrolling.
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
      // An AI-vs-AI matchup -- neither side is the GM's own club, so it
      // has no reason to appear in My Team mode at all (every league team
      // plays every other at least once over a full season, so an
      // opponent's name alone can't distinguish the two modes -- the
      // whole matchup can). Restricted to week 1 (preseason schedules
      // every team across its 2 game days) so it's guaranteed to be near
      // the top of the Full League ListView.builder without scrolling.
      final aiVsAiGame = franchise.seasonProgress.schedule.games.firstWhere(
        (g) =>
            g.week == 1 &&
            g.homeTeamAbbreviation != franchise.team.abbreviation &&
            g.awayTeamAbbreviation != franchise.team.abbreviation,
      );
      final aiHomeTeam = teamByAbbreviation(
        franchise,
        aiVsAiGame.homeTeamAbbreviation,
      );
      final aiAwayTeam = teamByAbbreviation(
        franchise,
        aiVsAiGame.awayTeamAbbreviation,
      );
      final matchupText =
          '${aiAwayTeam.emoji} ${aiAwayTeam.name} @ '
          '${aiHomeTeam.emoji} ${aiHomeTeam.name}';

      await tester.pumpWidget(
        MaterialApp(home: ScheduleScreen(franchise: franchise)),
      );
      await tester.pump();

      // My Team mode: this AI-vs-AI game shouldn't show up at all.
      expect(find.text(matchupText), findsNothing);

      await tester.tap(find.text('Full League'));
      await tester.pumpAndSettle();

      expect(find.text('Week ${aiVsAiGame.week}'), findsWidgets);
      expect(find.text(matchupText), findsOneWidget);
    },
  );
}
