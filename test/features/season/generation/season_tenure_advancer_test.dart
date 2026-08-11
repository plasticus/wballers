import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/generation/season_tenure_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith(List<RosterMembership> roster) {
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

void main() {
  group('advancePlayerTenure (2026-08-11, 0D_Season_2_Roadmap.md: Aging & '
      'roster churn)', () {
    test('increments age and yearsOfService for every own-roster player, '
        'regardless of RosterStatus', () {
      final active = playerWithOverall(
        70,
        id: 'active',
        age: 24,
        yearsOfService: 2,
      );
      final reserve = playerWithOverall(
        60,
        id: 'reserve',
        age: 30,
        yearsOfService: 8,
      );
      final franchise = _franchiseWith([
        RosterMembership(player: active, status: RosterStatus.active),
        RosterMembership(player: reserve, status: RosterStatus.reserveInactive),
      ]);

      final advanced = advancePlayerTenure(franchise);

      final newActive = advanced.roster
          .firstWhere((m) => m.player.id == 'active')
          .player;
      final newReserve = advanced.roster
          .firstWhere((m) => m.player.id == 'reserve')
          .player;
      expect(newActive.age, 25);
      expect(newActive.yearsOfService, 3);
      // reserveInactive is skipped by training/decline, but not by
      // aging -- everyone gets a year older regardless of playing
      // time (`advancePlayerTenure`'s own doc comment).
      expect(newReserve.age, 31);
      expect(newReserve.yearsOfService, 9);
    });

    test('increments every AI team\'s roster too, not just the GM\'s own', () {
      final franchise = _franchiseWith(const []);

      final advanced = advancePlayerTenure(franchise);

      for (var i = 0; i < franchise.league.aiTeams.length; i++) {
        final original = franchise.league.aiTeams[i].roster;
        final updated = advanced.league.aiTeams[i].roster;
        expect(updated, hasLength(original.length));
        for (var j = 0; j < original.length; j++) {
          expect(updated[j].player.age, original[j].player.age + 1);
          expect(
            updated[j].player.yearsOfService,
            original[j].player.yearsOfService + 1,
          );
        }
      }
    });

    test('leaves every AI team\'s coach and identity untouched', () {
      final franchise = _franchiseWith(const []);

      final advanced = advancePlayerTenure(franchise);

      for (var i = 0; i < franchise.league.aiTeams.length; i++) {
        expect(
          advanced.league.aiTeams[i].coach.name,
          franchise.league.aiTeams[i].coach.name,
        );
        expect(
          advanced.league.aiTeams[i].team.abbreviation,
          franchise.league.aiTeams[i].team.abbreviation,
        );
      }
    });
  });
}
