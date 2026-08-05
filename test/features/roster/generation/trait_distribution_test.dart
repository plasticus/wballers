import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/trait_distribution.dart';

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
  test('the same seed produces the same distribution', () {
    final a = distributeTraits(Random(7), _blankRoster());
    final b = distributeTraits(Random(7), _blankRoster());

    for (var i = 0; i < a.length; i++) {
      expect(a[i].player.traits, b[i].player.traits);
    }
  });

  test('assigns 3-5 total traits across a 12-player roster', () {
    final random = Random(11);
    for (var i = 0; i < 100; i++) {
      final roster = distributeTraits(random, _blankRoster());
      final totalTraits = roster.fold<int>(
        0,
        (sum, m) => sum + m.player.traits.length,
      );
      expect(totalTraits, inInclusiveRange(3, 5));
    }
  });

  test('a player having two traits is rare -- well under half of rosters', () {
    final random = Random(13);
    var rostersWithADoubleTraitPlayer = 0;
    const sampleSize = 300;

    for (var i = 0; i < sampleSize; i++) {
      final roster = distributeTraits(random, _blankRoster());
      if (roster.any((m) => m.player.traits.length >= 2)) {
        rostersWithADoubleTraitPlayer++;
      }
    }

    // Configured at a 5% per-roster chance -- allow generous slack for
    // sampling noise while still proving it's rare, not roughly-even-odds.
    expect(rostersWithADoubleTraitPlayer / sampleSize, lessThan(0.15));
  });

  test('never rolls Homegrown or both sides of an opposite pair', () {
    final random = Random(17);
    for (var i = 0; i < 100; i++) {
      final roster = distributeTraits(random, _blankRoster());
      for (final membership in roster) {
        expect(membership.player.traits, isNot(contains(Trait.homegrown)));
        for (final trait in membership.player.traits) {
          final opposite = oppositeOf(trait);
          expect(
            opposite == null || !membership.player.traits.contains(opposite),
            isTrue,
          );
        }
      }
    }
  });

  test('does not mutate the input roster', () {
    final original = _blankRoster();
    final before = original.map((m) => m.player.traits).toList();

    distributeTraits(Random(19), original);

    for (var i = 0; i < original.length; i++) {
      expect(original[i].player.traits, before[i]);
    }
  });
}
