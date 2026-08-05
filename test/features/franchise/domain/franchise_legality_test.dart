import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise_legality.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWithRoster(List<RosterMembership> roster) {
  return Franchise(
    id: 'test-franchise',
    gmName: 'Test GM',
    team: kLeagueTeamPool.first,
    coach: const Coach(name: 'Test Coach', stats: CoachStats.neutral),
    roster: roster,
    startingLineup: const StartingLineup(startersByPosition: {}),
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
}

void main() {
  test('a legal active roster with no developmental players is legal', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Player $i'),
          status: RosterStatus.active,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isTrue);
  });

  test('reserve/inactive members never count toward any cap', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Active $i'),
          status: RosterStatus.active,
        ),
      // Even five-star reserves shouldn't push the five-star count up.
      for (var i = 0; i < 5; i++)
        RosterMembership(
          player: playerWithOverall(95, name: 'Reserve $i'),
          status: RosterStatus.reserveInactive,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isTrue);
    expect(legality.fiveStarCount, 0);
  });

  test('too many active five-star players makes the franchise illegal', () {
    final roster = [
      for (var i = 0; i < 3; i++)
        RosterMembership(
          player: playerWithOverall(95, name: 'Star $i'),
          status: RosterStatus.active,
        ),
      for (var i = 0; i < 9; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Role $i'),
          status: RosterStatus.active,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalFiveStarCount, isFalse);
  });

  test('an ineligible developmental player makes the franchise illegal', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Active $i'),
          status: RosterStatus.active,
        ),
      RosterMembership(
        player: playerWithOverall(50, name: 'Veteran', yearsOfService: 8),
        status: RosterStatus.developmental,
      ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleDevelopmentalPlayers, isFalse);
  });
}
