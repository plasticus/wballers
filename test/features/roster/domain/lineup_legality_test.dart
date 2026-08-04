import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/lineup_legality.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import 'roster_test_helpers.dart';

void main() {
  test('a full, eligible, active-only lineup is legal', () {
    final roster = [
      for (final position in Position.values)
        RosterMembership(
          player: playerWithOverall(
            50,
            id: position.name,
            primaryPosition: position,
          ),
          status: RosterStatus.active,
        ),
    ];
    final lineup = StartingLineup(
      startersByPosition: {
        for (final position in Position.values) position: position.name,
      },
    );

    expect(evaluateLineupLegality(lineup, roster).isLegal, isTrue);
  });

  test('a lineup missing a position is illegal', () {
    final roster = [
      RosterMembership(
        player: playerWithOverall(
          50,
          id: 'pg',
          primaryPosition: Position.pointGuard,
        ),
        status: RosterStatus.active,
      ),
    ];
    final lineup = const StartingLineup(
      startersByPosition: {Position.pointGuard: 'pg'},
    );

    final legality = evaluateLineupLegality(lineup, roster);

    expect(legality.isLegal, isFalse);
    expect(legality.hasAllPositionsFilled, isFalse);
  });

  test('the same player filling two positions is illegal', () {
    final player = playerWithOverall(
      50,
      id: 'combo',
      primaryPosition: Position.pointGuard,
      secondaryPositions: {Position.shootingGuard},
    );
    final roster = [
      RosterMembership(player: player, status: RosterStatus.active),
      for (final position in [
        Position.smallForward,
        Position.powerForward,
        Position.center,
      ])
        RosterMembership(
          player: playerWithOverall(
            50,
            id: position.name,
            primaryPosition: position,
          ),
          status: RosterStatus.active,
        ),
    ];
    final lineup = StartingLineup(
      startersByPosition: {
        Position.pointGuard: 'combo',
        Position.shootingGuard: 'combo',
        Position.smallForward: 'smallForward',
        Position.powerForward: 'powerForward',
        Position.center: 'center',
      },
    );

    final legality = evaluateLineupLegality(lineup, roster);

    expect(legality.isLegal, isFalse);
    expect(legality.hasNoDuplicatePlayers, isFalse);
  });

  test('a starter who is not on the active roster is illegal', () {
    final roster = [
      RosterMembership(
        player: playerWithOverall(
          50,
          id: 'pg',
          primaryPosition: Position.pointGuard,
        ),
        status: RosterStatus.developmental,
      ),
    ];
    final lineup = const StartingLineup(
      startersByPosition: {Position.pointGuard: 'pg'},
    );

    final legality = evaluateLineupLegality(lineup, roster);

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleActivePlayers, isFalse);
  });

  test('a starter assigned to a position they cannot play is illegal', () {
    final roster = [
      RosterMembership(
        player: playerWithOverall(
          50,
          id: 'pg',
          primaryPosition: Position.pointGuard,
        ),
        status: RosterStatus.active,
      ),
    ];
    // This player has no secondary positions, so Center is not eligible.
    final lineup = const StartingLineup(
      startersByPosition: {Position.center: 'pg'},
    );

    final legality = evaluateLineupLegality(lineup, roster);

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleActivePlayers, isFalse);
  });

  test('a starter id not found on the roster at all is illegal', () {
    final lineup = const StartingLineup(
      startersByPosition: {Position.pointGuard: 'ghost'},
    );

    final legality = evaluateLineupLegality(lineup, const []);

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleActivePlayers, isFalse);
  });
}
