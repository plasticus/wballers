import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/market/generation/player_market_preview_generator.dart';
import 'package:womensbballmgr/features/market/presentation/player_market_screen.dart';

Franchise _newFranchise() => createExpansionFranchise(
  gmName: 'Jordan Ellis',
  clubName: 'Comets',
  homeCity: 'Springfield, IL',
  conference: Conference.atlantic,
  replacedTeamAbbreviation: 'BOS',
  colors: kStarterPalettes.first,
  emoji: '🏀',
  simulationSeed: 1,
);

void main() {
  testWidgets(
    'shows the 3 tabs, opening on Free Agents with a preview disclaimer',
    (tester) async {
      // All 10 preview rows need to be on-screen at once, same "plain
      // ListView only builds near the viewport" reasoning every other
      // long-list test in this codebase already works around.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();

      await tester.pumpWidget(
        MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
      );
      await tester.pump();

      expect(find.text('Player Market'), findsOneWidget);
      expect(find.text('Free Agents'), findsWidgets); // tab + banner text
      expect(find.text('Trade Block'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // The disclaimer is unmissable, not fine print.
      expect(
        find.textContaining('Preview only -- there\'s no free-agent pool'),
        findsOneWidget,
      );

      // 10 free agents, each labeled "Free Agent" (not a team name) --
      // folded into the identity subtitle line, not its own standalone
      // Text, hence textContaining rather than an exact match.
      expect(
        find.textContaining('Free Agent ·'),
        findsNWidgets(kPlayerMarketPreviewCount),
      );
    },
  );

  testWidgets('the Trade Block tab shows real AI teams, one per player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();

    await tester.pumpWidget(
      MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
    );
    await tester.pump();

    await tester.tap(find.text('Trade Block'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Preview only -- there\'s no trade system'),
      findsOneWidget,
    );
    // The screen's own preview picks, recomputed the same way it
    // generates them internally (same seed formula) -- whichever real
    // team its first pick actually belongs to shows up as that row's
    // subtitle, not "Free Agent".
    final picks = pickTradeBlockPreview(
      franchise,
      Random(franchise.simulationSeed + kTradeBlockPreviewSeedOffset),
    );
    final firstPickTeam = picks.first.team;
    expect(
      find.textContaining('${firstPickTeam.emoji} ${firstPickTeam.name}'),
      findsWidgets,
    );
    expect(find.textContaining('Free Agent ·'), findsNothing);
  });

  testWidgets('the Draft tab shows a college per prospect, not a team', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();

    await tester.pumpWidget(
      MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
    );
    await tester.pump();

    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Preview only -- there\'s no draft-day flow'),
      findsOneWidget,
    );
    // The screen's own preview prospects, recomputed the same way --
    // the first prospect's real college shows up as that row's subtitle.
    final prospects = generateDraftPreview(
      Random(franchise.simulationSeed + kDraftPreviewSeedOffset),
    );
    expect(
      find.textContaining('${prospects.first.college.name} ·'),
      findsWidgets,
    );
    expect(find.textContaining('Free Agent ·'), findsNothing);
  });
}
