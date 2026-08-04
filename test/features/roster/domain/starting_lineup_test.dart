import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import 'roster_test_helpers.dart';

void main() {
  group('isEligible', () {
    test('a player is eligible for their primary position', () {
      final player = playerWithOverall(
        50,
        primaryPosition: Position.pointGuard,
      );
      expect(StartingLineup.isEligible(player, Position.pointGuard), isTrue);
    });

    test('a player is eligible for a secondary position', () {
      final player = playerWithOverall(
        50,
        primaryPosition: Position.pointGuard,
        secondaryPositions: {Position.shootingGuard},
      );
      expect(StartingLineup.isEligible(player, Position.shootingGuard), isTrue);
    });

    test('a player is not eligible for an unrelated position', () {
      final player = playerWithOverall(
        50,
        primaryPosition: Position.pointGuard,
      );
      expect(StartingLineup.isEligible(player, Position.center), isFalse);
    });
  });

  group('StartingLineup.bestAvailable', () {
    test('picks the highest-overall eligible player at each position', () {
      final roster = [
        RosterMembership(
          player: playerWithOverall(
            60,
            id: 'pg-weak',
            primaryPosition: Position.pointGuard,
          ),
          status: RosterStatus.active,
        ),
        RosterMembership(
          player: playerWithOverall(
            80,
            id: 'pg-strong',
            primaryPosition: Position.pointGuard,
          ),
          status: RosterStatus.active,
        ),
      ];

      final lineup = StartingLineup.bestAvailable(roster);

      expect(lineup.startersByPosition[Position.pointGuard], 'pg-strong');
    });

    test('never assigns the same player to two positions', () {
      // A combo guard who's the best available at both PG and SG.
      final comboGuard = playerWithOverall(
        90,
        id: 'combo',
        primaryPosition: Position.pointGuard,
        secondaryPositions: {Position.shootingGuard},
      );
      final weakerShootingGuard = playerWithOverall(
        50,
        id: 'sg-weak',
        primaryPosition: Position.shootingGuard,
      );
      final roster = [
        RosterMembership(player: comboGuard, status: RosterStatus.active),
        RosterMembership(
          player: weakerShootingGuard,
          status: RosterStatus.active,
        ),
      ];

      final lineup = StartingLineup.bestAvailable(roster);

      expect(lineup.startersByPosition[Position.pointGuard], 'combo');
      expect(lineup.startersByPosition[Position.shootingGuard], 'sg-weak');
    });

    test('leaves a position unset when no active player is eligible', () {
      final roster = [
        RosterMembership(
          player: playerWithOverall(50, primaryPosition: Position.pointGuard),
          status: RosterStatus.active,
        ),
      ];

      final lineup = StartingLineup.bestAvailable(roster);

      expect(lineup.startersByPosition.containsKey(Position.center), isFalse);
    });

    test('ignores developmental and reserve players', () {
      final roster = [
        RosterMembership(
          player: playerWithOverall(
            99,
            id: 'bench-star',
            primaryPosition: Position.pointGuard,
          ),
          status: RosterStatus.developmental,
        ),
        RosterMembership(
          player: playerWithOverall(
            40,
            id: 'active-pg',
            primaryPosition: Position.pointGuard,
          ),
          status: RosterStatus.active,
        ),
      ];

      final lineup = StartingLineup.bestAvailable(roster);

      expect(lineup.startersByPosition[Position.pointGuard], 'active-pg');
    });
  });
}
