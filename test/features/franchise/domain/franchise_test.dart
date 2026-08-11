import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith({required int simulationSeed, int season = 0}) {
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: [
      RosterMembership(
        player: playerWithOverall(70),
        status: RosterStatus.active,
      ),
    ],
    simulationSeed: simulationSeed,
    season: season,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress: testSeasonProgress(
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool.first,
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

void main() {
  group(
    'Franchise.seasonSeed (2026-08-10, 0D_Season_2_Roadmap.md Foundation)',
    () {
      test('equals simulationSeed exactly at season 0', () {
        final franchise = _franchiseWith(simulationSeed: 1);

        expect(franchise.seasonSeed, 1);
      });

      test('shifts by kSeasonSeedSpan per season, never colliding with '
          'another season\'s own offset range', () {
        final season0 = _franchiseWith(simulationSeed: 1);
        final season1 = _franchiseWith(simulationSeed: 1, season: 1);
        final season2 = _franchiseWith(simulationSeed: 1, season: 2);

        expect(season1.seasonSeed - season0.seasonSeed, kSeasonSeedSpan);
        expect(season2.seasonSeed - season1.seasonSeed, kSeasonSeedSpan);
      });
    },
  );
}
