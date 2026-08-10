import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
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

  group('positional trends (TODO.md item 9, full GM spec)', () {
    // Independent single-player draws (an empty existingRoster every
    // call, not a shared 12-slot roster) -- measures the underlying roll
    // distribution directly, without a small typical-numbers pool
    // getting artificially exhausted by 12 same-position players sharing
    // one roster.
    int? draw(Random random, Position position) {
      final player = assignJerseyNumberAvoiding(
        random,
        playerWithOverall(50, primaryPosition: position),
        const [],
      );
      return player.jerseyNumber;
    }

    test('never lands on 00 (0), 69, or 88', () {
      final random = Random(1);
      for (var i = 0; i < 3000; i++) {
        final position = Position.values[i % Position.values.length];
        final n = draw(random, position)!;
        expect(n, isNot(anyOf(0, 69, 88)));
      }
    });

    test('Guards land in 0-5/low-teens roughly 85% of the time', () {
      final random = Random(2);
      const sampleSize = 5000;
      var typicalHits = 0;
      for (var i = 0; i < sampleSize; i++) {
        final n = draw(random, Position.pointGuard)!;
        if ((n >= 1 && n <= 5) || (n >= 10 && n <= 15)) typicalHits++;
      }
      expect(typicalHits / sampleSize, closeTo(0.85, 0.03));
    });

    test('Forwards land in the 20s/30s roughly 85% of the time', () {
      final random = Random(3);
      const sampleSize = 5000;
      var typicalHits = 0;
      for (var i = 0; i < sampleSize; i++) {
        final n = draw(random, Position.powerForward)!;
        if (n >= 20 && n <= 39) typicalHits++;
      }
      expect(typicalHits / sampleSize, closeTo(0.85, 0.03));
    });

    test('Centers land in high-teens/30s/40s more often than pure chance '
        'would suggest, but less reliably than Guards/Forwards land in '
        'their own typical ranges -- the loosest of the three groups', () {
      final random = Random(4);
      const sampleSize = 5000;
      var typicalHits = 0;
      for (var i = 0; i < sampleSize; i++) {
        final n = draw(random, Position.center)!;
        if ((n >= 16 && n <= 19) || (n >= 30 && n <= 49)) typicalHits++;
      }
      // Not a clean 70% -- Centers' own "common outlier" numbers (40, 41,
      // 42, 44) sit *inside* the high-teens/30s/40s range too, and the
      // "anything else" bucket has a real chance of landing there by pure
      // luck across a range this wide. 0.70*1 (typical) + 0.15*(4/14)
      // (outlier overlap) + 0.15*(24/97) (anything else overlap) ~= 0.78,
      // not the raw 70% category weight.
      expect(typicalHits / sampleSize, closeTo(0.78, 0.03));
    });

    test('the common-outlier pool shows up at roughly the GM-specified '
        'rate for a Guard (10%) and a Center (15%)', () {
      const outliers = {44, 55, 66, 77, 99, 91, 41, 42, 40, 50, 60, 70, 80, 90};
      const sampleSize = 5000;

      final guardRandom = Random(5);
      var guardOutlierHits = 0;
      for (var i = 0; i < sampleSize; i++) {
        if (outliers.contains(draw(guardRandom, Position.pointGuard))) {
          guardOutlierHits++;
        }
      }
      expect(guardOutlierHits / sampleSize, closeTo(0.10, 0.03));

      final centerRandom = Random(6);
      var centerOutlierHits = 0;
      for (var i = 0; i < sampleSize; i++) {
        if (outliers.contains(draw(centerRandom, Position.center))) {
          centerOutlierHits++;
        }
      }
      // Not a clean 15% either, for the same reason as the typical-range
      // test above -- 4 of the 14 outlier numbers (40, 41, 42, 44) are
      // also in Centers' own typical pool, so drawing "typical" has a
      // real chance of landing on one anyway: 0.15*1 (outlier) +
      // 0.70*(4/24) (typical overlap) + 0.15*(14/97) (anything else) ~=
      // 0.29.
      expect(centerOutlierHits / sampleSize, closeTo(0.29, 0.03));
    });
  });
}
