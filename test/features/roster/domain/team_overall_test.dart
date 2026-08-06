import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';

import 'roster_test_helpers.dart';

RosterMembership _active(int overall) => RosterMembership(
  player: playerWithOverall(overall),
  status: RosterStatus.active,
);

RosterMembership _reserve(int overall, RosterStatus status) =>
    RosterMembership(player: playerWithOverall(overall), status: status);

void main() {
  test('is the mean average of the active roster', () {
    final roster = [_active(80), _active(70), _active(60)];

    expect(teamOverall(roster), 70);
  });

  test('rounds to the nearest whole number', () {
    final roster = [_active(80), _active(79), _active(79)];

    // (80 + 79 + 79) / 3 = 79.33... -> rounds to 79.
    expect(teamOverall(roster), 79);
  });

  test('ignores developmental and reserve/inactive players', () {
    final roster = [
      _active(70),
      _active(70),
      _reserve(99, RosterStatus.developmental),
      _reserve(1, RosterStatus.reserveInactive),
    ];

    expect(teamOverall(roster), 70);
  });

  test('is 0 for a roster with no active players', () {
    final roster = [
      _reserve(80, RosterStatus.developmental),
      _reserve(80, RosterStatus.reserveInactive),
    ];

    expect(teamOverall(roster), 0);
  });

  test('is 0 for an empty roster', () {
    expect(teamOverall(const []), 0);
  });
}
