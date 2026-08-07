import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/presentation/results_screen.dart';

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
}
