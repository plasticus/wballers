import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/roster_legality_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../domain/roster_test_helpers.dart';

/// Same "one controlled AI team, the other 18 straight from [testLeague]"
/// shape used elsewhere in this session's Aging & Churn tests.
Franchise _franchiseWithAiRoster(List<RosterMembership> roster) {
  final baseLeague = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final league = League(
    aiTeams: [
      baseLeague.aiTeams.first.copyWithRoster(roster),
      ...baseLeague.aiTeams.skip(1),
    ],
  );
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool[1],
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: const [],
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: league,
    seasonProgress: testSeasonProgress(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool[1],
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

void main() {
  group('enforceAiRosterLegality (2026-08-11, 0D_Season_2_Roadmap.md: Aging & '
      'roster churn -- a real gate, not just a display warning)', () {
    test('a legal roster is left completely untouched', () {
      final roster = [
        RosterMembership(
          player: playerWithOverall(92, id: 'star'), // the one 4-star
          status: RosterStatus.active,
        ),
        for (var i = 0; i < 11; i++)
          RosterMembership(
            player: playerWithOverall(65, id: 'role-$i'),
            status: RosterStatus.active,
          ),
      ];
      final franchise = _franchiseWithAiRoster(roster);

      final advance = enforceAiRosterLegality(franchise);

      expect(advance.waivedPlayerIds, isEmpty);
      expect(
        advance.franchise.league.aiTeams.first.roster.map((m) => m.player.id),
        roster.map((m) => m.player.id),
      );
      expect(advance.franchise.freeAgents, isEmpty);
    });

    test('trims an illegal four-star surplus down to the cap, waiving the '
        'lowest-overall four-star player(s) into Franchise.freeAgents', () {
      final keep1 = playerWithOverall(98, id: 'keep-1');
      final keep2 = playerWithOverall(95, id: 'keep-2');
      final cut = playerWithOverall(90, id: 'cut'); // lowest of the 3
      final roster = [
        RosterMembership(player: keep1, status: RosterStatus.active),
        RosterMembership(player: keep2, status: RosterStatus.active),
        RosterMembership(player: cut, status: RosterStatus.active),
        for (var i = 0; i < 9; i++)
          RosterMembership(
            player: playerWithOverall(60, id: 'role-$i'),
            status: RosterStatus.active,
          ),
      ];
      final franchise = _franchiseWithAiRoster(roster);

      final advance = enforceAiRosterLegality(franchise);

      expect(advance.waivedPlayerIds, {'cut'});
      final survivingIds = advance.franchise.league.aiTeams.first.roster
          .map((m) => m.player.id)
          .toSet();
      expect(survivingIds, isNot(contains('cut')));
      expect(survivingIds, containsAll(['keep-1', 'keep-2']));
      expect(advance.franchise.freeAgents.map((p) => p.id), contains('cut'));
    });

    test('trims an illegal three-star-and-up surplus down to the cap, once '
        'the four-star cap is already satisfied', () {
      // 1 four-star (legal on its own) + 7 three-star (illegal:
      // combined total of 8 breaches the 6-player cap) -- the lowest
      // three-star overall should be the one(s) cut.
      final fourStar = playerWithOverall(92, id: 'four-star');
      final threeStars = [
        for (var i = 0; i < 7; i++)
          playerWithOverall(80 + i, id: 'three-$i'), // 80..86
      ];
      final roster = [
        RosterMembership(player: fourStar, status: RosterStatus.active),
        for (final p in threeStars)
          RosterMembership(player: p, status: RosterStatus.active),
        for (var i = 0; i < 4; i++)
          RosterMembership(
            player: playerWithOverall(60, id: 'role-$i'),
            status: RosterStatus.active,
          ),
      ];
      final franchise = _franchiseWithAiRoster(roster);

      final advance = enforceAiRosterLegality(franchise);

      // 1 four-star + 7 three-star = 8 total, cap is 6 -- exactly 2
      // must be cut, the 2 lowest-overall three-stars (80, 81).
      expect(advance.waivedPlayerIds, {'three-0', 'three-1'});
    });

    test('developmental/reserve players are never counted or waived', () {
      final roster = [
        for (var i = 0; i < 3; i++)
          RosterMembership(
            player: playerWithOverall(92, id: 'dev-star-$i'),
            status: RosterStatus.developmental,
          ),
        for (var i = 0; i < 9; i++)
          RosterMembership(
            player: playerWithOverall(60, id: 'role-$i'),
            status: RosterStatus.active,
          ),
      ];
      final franchise = _franchiseWithAiRoster(roster);

      final advance = enforceAiRosterLegality(franchise);

      expect(advance.waivedPlayerIds, isEmpty);
    });

    test('every other AI team is untouched -- same 19 teams, same order, '
        'same players', () {
      final keep1 = playerWithOverall(98, id: 'keep-1');
      final keep2 = playerWithOverall(95, id: 'keep-2');
      final cut = playerWithOverall(90, id: 'cut');
      final roster = [
        RosterMembership(player: keep1, status: RosterStatus.active),
        RosterMembership(player: keep2, status: RosterStatus.active),
        RosterMembership(player: cut, status: RosterStatus.active),
      ];
      final franchise = _franchiseWithAiRoster(roster);

      final advance = enforceAiRosterLegality(franchise);

      expect(advance.franchise.league.aiTeams, hasLength(19));
      for (var i = 1; i < franchise.league.aiTeams.length; i++) {
        expect(
          advance.franchise.league.aiTeams[i].team.abbreviation,
          franchise.league.aiTeams[i].team.abbreviation,
        );
        expect(
          advance.franchise.league.aiTeams[i].roster.map((m) => m.player.id),
          franchise.league.aiTeams[i].roster.map((m) => m.player.id),
        );
      }
    });
  });
}
