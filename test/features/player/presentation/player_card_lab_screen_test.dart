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
    'shows the roster\'s first player across 5 card variations, then a '
    'made-up long-named, traited player across 5 more that combine the '
    'GM\'s favorites',
    (tester) async {
      // All 10 cards need to be on-screen at once -- the default test
      // surface is too short to lay out every card in the plain `ListView`
      // without scrolling, which (like `DepthChartScreen`'s reorderable
      // list) only builds items near the viewport.
      tester.view.physicalSize = const Size(800, 7200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = franchiseForPortraitTests();
      final player = franchise.roster.first.player;

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
      expect(find.text('1. Bigger, Same Shape'), findsOneWidget);
      expect(find.text('2. OVR Badge'), findsOneWidget);
      expect(find.text('3. Stat Chips'), findsOneWidget);
      expect(find.text('4. Two-Line Header'), findsOneWidget);
      expect(find.text('5. Minimal'), findsOneWidget);
      expect(find.text('6. OVR Badge + Stat Chips'), findsOneWidget);
      expect(find.text('7. Lastname, First'), findsOneWidget);
      expect(find.text('8. Jersey Badge on Photo'), findsOneWidget);
      expect(find.text('9. Jersey Gets Its Own Column'), findsOneWidget);
      expect(find.text('10. Refined'), findsOneWidget);

      // Every one of the first 5 cards names the roster player somewhere
      // in its identity line, jersey number included.
      final expectedJersey = player.jerseyNumber != null
          ? '#${player.jerseyNumber}'
          : '';
      expect(
        find.textContaining('$expectedJersey ${player.name}'),
        findsNWidgets(5),
      );

      // "EXP: N" / "Rookie" formatting, not "N yrs WBL" -- across every
      // card, both rounds (10 total).
      final years = player.yearsOfService;
      final experienceLabel = years == 0 ? 'Rookie' : 'EXP: $years';
      expect(find.textContaining(experienceLabel), findsNWidgets(5));
      expect(find.textContaining('EXP: 5'), findsNWidgets(5));

      // Round 2's made-up player: long name, jersey #23, and both traits
      // show up across its 5 cards -- neither #2 nor #3 showed traits at
      // all in the first batch. findsWidgets (not an exact count): the
      // intro paragraph also names the player once, on top of however
      // many cards spell the name first-then-last (card #7 reverses it,
      // checked separately below).
      expect(
        find.textContaining('Alexandria Castellanos-Whitmore'),
        findsWidgets,
      );
      expect(find.textContaining('#23'), findsWidgets);
      expect(find.text('Leader'), findsNWidgets(5));
      expect(find.text('Sharpshooter'), findsNWidgets(5));

      // Card 7's last-name-first format.
      expect(
        find.textContaining('Castellanos-Whitmore, Alexandria'),
        findsOneWidget,
      );
    },
  );
}
