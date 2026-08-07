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
  testWidgets('shows the roster\'s first player, once each, across all 5 card '
      'variations, with jersey number and years of WBL experience', (
    tester,
  ) async {
    // All 5 cards need to be on-screen at once -- the default test
    // surface is too short to lay out every card in the plain `ListView`
    // without scrolling, which (like `DepthChartScreen`'s reorderable
    // list) only builds items near the viewport.
    tester.view.physicalSize = const Size(800, 3600);
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

    // Every one of the 5 cards names the player somewhere in its
    // identity line, jersey number included.
    final expectedJersey = player.jerseyNumber != null
        ? '#${player.jerseyNumber}'
        : '';
    expect(
      find.textContaining('$expectedJersey ${player.name}'),
      findsNWidgets(5),
    );

    // Years of WBL experience: a new requirement across every card here.
    final years = player.yearsOfService;
    final experienceLabel = '$years ${years == 1 ? 'yr' : 'yrs'} WBL';
    expect(find.textContaining(experienceLabel), findsNWidgets(5));

    // Card 1's OVR text (plain number + "OVR" caption).
    expect(find.text('${player.ratings.overall}'), findsWidgets);
    expect(find.text('OVR'), findsWidgets);
  });
}
