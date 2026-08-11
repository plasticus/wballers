import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import 'league_test_helpers.dart';
import 'season_test_helpers.dart';
import 'training_test_helpers.dart';

/// [firstPlayerAchievementCount] grants the roster's first player that
/// many League MVP records -- used to test the special-hair-color unlock
/// gate (2026-08-10: unlocked on the *second* achievement, not the
/// first -- `SeasonAwardsAnswers.md` answer 4), which otherwise never has
/// anything to react to in a plain widget test since granting one for
/// real needs a whole All-Star Game to resolve.
Franchise franchiseForPortraitTests({int firstPlayerAchievementCount = 0}) {
  var roster = generateStartingRoster(1);
  if (firstPlayerAchievementCount > 0) {
    final first = roster.first;
    var player = first.player;
    for (var i = 0; i < firstPlayerAchievementCount; i++) {
      player = player.copyWithAchievement(
        const PlayerAchievementRecord(
          achievement: Achievement.leagueMvp,
          season: 0,
        ),
      );
    }
    roster = [
      RosterMembership(player: player, status: first.status),
      ...roster.skip(1),
    ];
  }
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: roster,
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress: testSeasonProgress(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool.first,
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
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
