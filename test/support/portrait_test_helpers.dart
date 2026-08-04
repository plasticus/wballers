import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

Franchise franchiseForPortraitTests() {
  final roster = generateStartingRoster(1);
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kInitialLeagueTeams.first,
    coach: const Coach(name: 'Jordan Ellis', stats: CoachStats.neutral),
    roster: roster,
    startingLineup: StartingLineup.bestAvailable(roster),
    simulationSeed: 1,
  );
}

/// Real asset decode/PNG-encode work can't progress inside testWidgets'
/// fake async zone -- see portrait_image_test.dart for why this loop is
/// needed. Keep tests that need this in their own file: two such tests in
/// the same file can leave the second one permanently stuck waiting on
/// asset loading (observed empirically, not fully root-caused -- looks
/// like cross-test contamination of the binary-messenger mock rather than
/// a real timing issue, since the second test passes cleanly when run
/// alone).
Future<void> letPortraitAsyncWorkFinish(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}
