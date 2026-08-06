import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/player/presentation/player_card_lab_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

// Kept as its own file, exactly one test -- rendering several real
// `PortraitImage`s at once is already the heaviest single case this
// project's test suite exercises, and `letPortraitAsyncWorkFinish`'s own
// doc comment warns a second such test sharing a file can leave later
// tests permanently stuck on asset loading.
void main() {
  testWidgets(
    'shows the roster\'s first player, once each, across all 4 card layouts',
    (tester) async {
      // All 4 cards need to be on-screen at once -- the default test
      // surface is too short to lay out every card in the plain `ListView`
      // without scrolling, which (like `DepthChartScreen`'s reorderable
      // list) only builds items near the viewport.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = franchiseForPortraitTests();
      final playerName = franchise.roster.first.player.name;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
          child: MaterialApp(home: PlayerCardLabScreen(franchise: franchise)),
        ),
      );
      await letPortraitAsyncWorkFinish(tester);

      expect(find.text('Player Card Lab'), findsOneWidget);
      // Once per layout: intro line, plus 4 cards each naming the player.
      expect(find.text(playerName), findsNWidgets(4));
      expect(
        find.text('1. Compact Row (current roster-row style)'),
        findsOneWidget,
      );
      expect(find.text('2. Trading Card'), findsOneWidget);
      expect(find.text('3. Ticket Stat Strip'), findsOneWidget);
      expect(find.text('4. Scoreboard Tile'), findsOneWidget);
    },
  );
}
