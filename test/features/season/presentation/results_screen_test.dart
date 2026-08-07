import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/presentation/results_screen.dart';

import '../../../support/franchise_test_helpers.dart';

void main() {
  testWidgets('shows an empty state before any games are played', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(home: ResultsScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('No games played yet.'), findsOneWidget);
  });

  testWidgets(
    'lists every game played so far, newest first, and tapping one opens '
    'its box score',
    (tester) async {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );

      // Play the first two game days (the preseason).
      var progress = franchise.seasonProgress;
      final rosters = rostersByAbbreviation(franchise);
      for (var i = 0; i < 2; i++) {
        final advance = advanceToNextGameDay(
          Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset + i),
          progress,
          rostersByAbbreviation: rosters,
        );
        progress = advance.progress;
      }
      final playedFranchise = franchise.copyWithSeasonProgress(progress);
      expect(progress.playedGames.length, greaterThan(10));

      await tester.pumpWidget(
        MaterialApp(home: ResultsScreen(franchise: playedFranchise)),
      );
      await tester.pump();

      expect(find.text('Results'), findsOneWidget);
      // Both game days played here are preseason -- every visible row
      // should note it doesn't count toward the standings.
      expect(
        find.textContaining('Preseason -- exhibition, doesn\'t count'),
        findsWidgets,
      );
      // Newest-first: the most recently played game (the last one in
      // playedGames' arrival order) renders as the very first row, so its
      // score is on-screen without any scrolling -- ListView.builder only
      // builds what's near the viewport, so this also doubles as
      // confirmation the ordering is actually reversed, not just present.
      final lastPlayedGame = progress.playedGames.last;
      expect(find.text('${lastPlayedGame.awayScore}'), findsWidgets);

      // Tapping that first row (the most recently played game) opens its
      // box score.
      await tester.tap(find.text('${lastPlayedGame.awayScore}').first);
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsOneWidget);
      expect(find.text('FINAL'), findsOneWidget);
      expect(find.textContaining('PTS'), findsWidgets);
      // At least one box score row shows a real position + jersey number,
      // not just a bare name -- the current roster join actually resolved.
      expect(
        find.textContaining(RegExp(r'^(PG|SG|SF|PF|C) #\d+ ')),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'PlayedGameDetailScreen lists the GM\'s own team\'s box score before '
    'the opponent\'s, even when the GM played at home',
    (tester) async {
      // Both teams' box scores need to be on-screen at once to compare
      // their vertical order.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final opponent = franchise.league.aiTeams.first.team;
      final rosters = rostersByAbbreviation(franchise);
      // The GM's own team is the home team here -- this screen's old
      // fixed order was away-then-home, so a home GM is exactly the case
      // that used to render the opponent's box score first.
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
      final played = PlayedGame.fromResult(
        result,
        rostersByAbbreviation: rosters,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PlayedGameDetailScreen(franchise: franchise, played: played),
        ),
      );
      await tester.pump();

      // Each team's name appears twice: once in the score card, once as
      // the box score section header -- the second occurrence is the one
      // whose position actually matters here.
      final ownSectionY = tester
          .getTopLeft(find.text(franchise.team.name).at(1))
          .dy;
      final opponentSectionY = tester
          .getTopLeft(find.text(opponent.name).at(1))
          .dy;
      expect(ownSectionY, lessThan(opponentSectionY));
    },
  );
}
