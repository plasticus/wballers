import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/jersey_number_assignment.dart';

import '../domain/roster_test_helpers.dart';

List<RosterMembership> _blankRoster() {
  return [
    for (var i = 0; i < 12; i++)
      RosterMembership(
        player: playerWithOverall(50, id: 'p$i', name: 'Player $i'),
        status: RosterStatus.active,
      ),
  ];
}

void main() {
  test('assigns every player a jersey number in 0-99', () {
    final roster = assignJerseyNumbers(Random(1), _blankRoster());

    for (final membership in roster) {
      expect(membership.player.jerseyNumber, isNotNull);
      expect(membership.player.jerseyNumber, inInclusiveRange(0, 99));
    }
  });

  test('never assigns the same number to two players', () {
    final random = Random(3);
    for (var i = 0; i < 50; i++) {
      final roster = assignJerseyNumbers(random, _blankRoster());
      final numbers = roster.map((m) => m.player.jerseyNumber).toSet();
      expect(numbers.length, roster.length);
    }
  });

  test('the same seed produces the same assignment', () {
    final a = assignJerseyNumbers(Random(7), _blankRoster());
    final b = assignJerseyNumbers(Random(7), _blankRoster());

    for (var i = 0; i < a.length; i++) {
      expect(a[i].player.jerseyNumber, b[i].player.jerseyNumber);
    }
  });

  test('does not mutate the input roster', () {
    final original = _blankRoster();
    final before = original.map((m) => m.player.jerseyNumber).toList();

    assignJerseyNumbers(Random(19), original);

    for (var i = 0; i < original.length; i++) {
      expect(original[i].player.jerseyNumber, before[i]);
    }
  });
}
