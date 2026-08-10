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
  test(
    'is a plain mean when every player is within the full-weight top-6 '
    '(ranks 1-6 all carry the same weight, same as an unweighted average)',
    () {
      final roster = [_active(80), _active(70), _active(60)];

      expect(teamOverall(roster), 70);
    },
  );

  test('rounds to the nearest whole number', () {
    final roster = [_active(80), _active(79), _active(79)];

    // (80 + 79 + 79) / 3 = 79.33... -> rounds to 79.
    expect(teamOverall(roster), 79);
  });

  test('weights ranks 1-6 at 100%, 7-8 at 80%, and 9-12 at 60% -- a deep bench '
      'moves the number less than a flat average would (`Aug9bugs.md` #12, '
      'a direct GM ask)', () {
    final roster = [
      for (var i = 0; i < 6; i++) _active(80), // ranks 1-6, weight 1.0
      for (var i = 0; i < 2; i++) _active(60), // ranks 7-8, weight 0.8
      for (var i = 0; i < 4; i++) _active(40), // ranks 9-12, weight 0.6
    ];

    // weighted: (6*80*1.0 + 2*60*0.8 + 4*40*0.6) / (6*1.0 + 2*0.8 + 4*0.6)
    //         = (480 + 96 + 96) / (6 + 1.6 + 2.4) = 672 / 10 = 67.2 -> 67
    expect(teamOverall(roster), 67);
    // A flat average of the same 12 players would be 63 -- the weighted
    // result is meaningfully higher, since it's the low-weight bench
    // players (not the full-weight top 6) dragging a flat average down.
    expect(teamOverall(roster), greaterThan((6 * 80 + 2 * 60 + 4 * 40) ~/ 12));
  });

  test('weighting follows roster *list order* (rank), not a re-sort by '
      'rating -- the same set of players ranked differently produces a '
      'different team overall', () {
    final strong = _active(90);
    final weak = _active(50);
    final middling = [for (var i = 0; i < 10; i++) _active(70)];

    // The 90 is buried at the bottom of the depth chart (rank 12, 60%
    // weight); the 50 leads the lineup (rank 1, 100% weight).
    final weakFirst = teamOverall([weak, ...middling, strong]);
    // Same 12 players, weak and strong swapped in rank -- now the 90
    // gets full weight and the 50 is buried instead.
    final strongFirst = teamOverall([strong, ...middling, weak]);

    expect(strongFirst, greaterThan(weakFirst));
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
