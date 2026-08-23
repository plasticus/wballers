import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/engine/substitution_policy.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

import '../../../support/match_test_players.dart';

/// A 12-player roster whose 5 highest-overall players are 3 SFs and 2
/// SGs -- no PG, PF, or C at all -- while the full pool still carries the
/// usual `kTwelvePlayerPositionPlan` spread (2 PG, 3 SG, 3 SF, 2 PF,
/// 2 C). [label] only ever varies the player ids, not ratings/positions --
/// which of `targetMinutesFor`'s branches fires is driven by the
/// `teamAbbreviation` passed alongside the roster (`TeamIdentity.preferredShape`),
/// not anything about the roster itself.
List<Player> _imbalancedRoster(String label) {
  return [
    testPlayer(id: '$label-sf1', rating: 90, position: Position.smallForward),
    testPlayer(id: '$label-sf2', rating: 88, position: Position.smallForward),
    testPlayer(id: '$label-sf3', rating: 86, position: Position.smallForward),
    testPlayer(id: '$label-sg1', rating: 84, position: Position.shootingGuard),
    testPlayer(id: '$label-sg2', rating: 82, position: Position.shootingGuard),
    testPlayer(id: '$label-pg1', rating: 80, position: Position.pointGuard),
    testPlayer(id: '$label-pg2', rating: 78, position: Position.pointGuard),
    testPlayer(id: '$label-pf1', rating: 76, position: Position.powerForward),
    testPlayer(id: '$label-pf2', rating: 74, position: Position.powerForward),
    testPlayer(id: '$label-c1', rating: 72, position: Position.center),
    testPlayer(id: '$label-c2', rating: 70, position: Position.center),
    testPlayer(id: '$label-sg3', rating: 68, position: Position.shootingGuard),
  ];
}

/// Whether [targetMinutes]' own top 5 (ranks 0-4, the only entries at 26+
/// target minutes -- rank 5 onward tops out at 14, see
/// `_targetMinutesByRank`) covers all 5 standard positions.
bool _hasStandardTopFive(Map<Player, int> targetMinutes) {
  final starters = targetMinutes.entries
      .where((entry) => entry.value >= 26)
      .map((entry) => entry.key)
      .toSet();
  return starters.map((p) => p.primaryPosition).toSet().length == 5;
}

void main() {
  group('targetMinutesFor', () {
    test('assigns minutes summing to 200 across a 12-player roster', () {
      final roster = testRoster('r');

      final targetMinutes = targetMinutesFor(roster);

      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
    });

    test('gives the highest-rated player the most minutes', () {
      final roster = testRoster('r');
      final best = roster.reduce(
        (a, b) => a.ratings.overall >= b.ratings.overall ? a : b,
      );

      final targetMinutes = targetMinutesFor(roster);

      expect(
        targetMinutes[best],
        targetMinutes.values.reduce((a, b) => a > b ? a : b),
      );
    });

    test('still assigns minutes summing to 200 for a short-handed roster '
        '(2026-08-20, injuries: a player or two parked in Reserve/'
        'Inactive)', () {
      final roster = testRoster('r').take(11).toList();

      final targetMinutes = targetMinutesFor(roster);

      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
    });

    test('throws when fewer than 5 players are given', () {
      expect(
        () => targetMinutesFor(testRoster('r').take(4).toList()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('an over-cap roster (more than 12 active) no longer throws -- only '
        'the top 12 by overall actually get real minutes, everyone else '
        'gets 0 (2026-08-23, a direct GM design call: "you can roll an '
        'illegal roster through preseason" -- this used to throw a '
        'RangeError deep in targetMinutesForOrderedRoster instead, the '
        'exact silent "Play Game just spins" crash mechanism)', () {
      final roster = [
        ...testRoster('r'),
        testPlayer(id: 'extra-1', rating: 40),
        testPlayer(id: 'extra-2', rating: 30),
        testPlayer(id: 'extra-3', rating: 20),
      ];

      final targetMinutes = targetMinutesFor(roster);

      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
      expect(targetMinutes.values.where((m) => m == 0), hasLength(3));
      for (final extra in roster.skip(12)) {
        expect(targetMinutes[extra], 0);
      }
    });

    test('balances roughly half of position-imbalanced rosters, leaving '
        'the rest naturally non-standard -- a direct GM follow-up '
        '(2026-08-15) walked back an earlier "balance every AI team" fix: '
        '"I don\'t want them all to field standard lineups... having some '
        'non-standard ones is really cool... that\'s why I said 50%, not '
        '100%"', () {
      const trials = 200;
      var balancedCount = 0;
      for (var i = 0; i < trials; i++) {
        final targetMinutes = targetMinutesFor(
          _imbalancedRoster('t$i'),
          teamAbbreviation: 'T$i',
        );
        if (_hasStandardTopFive(targetMinutes)) {
          balancedCount++;
        }
      }

      // Both branches actually fire...
      expect(balancedCount, greaterThan(0));
      expect(balancedCount, lessThan(trials));
      // ...and land somewhere in the neighborhood of half -- a wide band,
      // not an exact-50% assertion, since this is a deterministic hash
      // split rather than a true coin flip.
      expect(balancedCount, greaterThan(trials * 0.25));
      expect(balancedCount, lessThan(trials * 0.75));
    });

    test('when a team lands on the balanced half, its top 5 covers every '
        'standard position, promoting the best bench player up at any '
        'missing one without ever displacing the single highest-overall '
        'player', () {
      for (var i = 0; i < 50; i++) {
        final roster = _imbalancedRoster('balanced$i');
        final targetMinutes = targetMinutesFor(
          roster,
          teamAbbreviation: 'BAL$i',
        );
        if (!_hasStandardTopFive(targetMinutes)) continue;

        final best = roster.reduce(
          (a, b) => a.ratings.overall >= b.ratings.overall ? a : b,
        );
        expect(targetMinutes[best], 30);
        expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
        return;
      }
      fail('expected at least one balanced roster within 50 tries');
    });

    test('when a team lands on the non-balanced half, its top 5 keeps '
        'whatever positional duplication the plain overall sort produced '
        '-- the preserved "interesting" variety, not a residual bug', () {
      for (var i = 0; i < 50; i++) {
        final roster = _imbalancedRoster('unbalanced$i');
        final targetMinutes = targetMinutesFor(
          roster,
          teamAbbreviation: 'UNB$i',
        );
        if (_hasStandardTopFive(targetMinutes)) continue;

        // Skipping the rebalance doesn't break anything else about the
        // assignment.
        final best = roster.reduce(
          (a, b) => a.ratings.overall >= b.ratings.overall ? a : b,
        );
        expect(targetMinutes[best], 30);
        expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
        return;
      }
      fail('expected at least one non-balanced roster within 50 tries');
    });
  });

  group('targetMinutesForOrderedRoster', () {
    test('assigns minutes by list position, not overall -- no resort', () {
      // Reverse of testRoster's own descending-overall order: the worst
      // player is first, the best is last.
      final orderedWorstFirst = testRoster('r').reversed.toList();

      final targetMinutes = targetMinutesForOrderedRoster(orderedWorstFirst);

      // Rank 1 (index 0, the worst-rated player here) gets the top target
      // minutes -- proves this reads list position, not
      // PlayerRatings.overall the way targetMinutesFor does.
      expect(targetMinutes[orderedWorstFirst.first], 30);
      expect(targetMinutes[orderedWorstFirst.last], 4);
      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
    });

    test('throws when fewer than 5 players are given', () {
      expect(
        () => targetMinutesForOrderedRoster(testRoster('r').take(4).toList()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('an over-cap roster (more than 12 active) assigns real minutes to '
        'only the first 12 in list order, 0 to the rest -- no crash '
        '(2026-08-23, a direct GM design call: "you can roll an illegal '
        'roster through preseason" -- the GM\'s own real bench order, not '
        'an overall resort, since this is the variant the GM\'s own team '
        'goes through)', () {
      final overCap = [
        ...testRoster('r'),
        testPlayer(id: 'extra-1', rating: 90),
        testPlayer(id: 'extra-2', rating: 90),
      ];

      final targetMinutes = targetMinutesForOrderedRoster(overCap);

      for (var i = 0; i < 12; i++) {
        expect(targetMinutes[overCap[i]], greaterThan(0), reason: 'rank $i');
      }
      expect(targetMinutes[overCap[12]], 0);
      expect(targetMinutes[overCap[13]], 0);
      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
    });

    test('a short-handed roster (injuries parked in Reserve/Inactive) '
        'leaves the 5 starters\' minutes untouched and spreads the '
        'shortfall across the bench (2026-08-20, a direct GM question: '
        '"do we need to plan minutes differently?")', () {
      // 2 players missing from a full 12 -- the GM's own "we\'re missing
      // out on 8 minutes of time" example.
      final roster = testRoster('r').take(10).toList();

      final targetMinutes = targetMinutesForOrderedRoster(roster);

      // Starters (ranks 1-5) keep exactly the same minutes a full roster
      // would have given them.
      expect(targetMinutes[roster[0]], 30);
      expect(targetMinutes[roster[1]], 30);
      expect(targetMinutes[roster[2]], 30);
      expect(targetMinutes[roster[3]], 26);
      expect(targetMinutes[roster[4]], 26);
      // The bench (ranks 6-10) absorbs all 8 shortfall minutes, spread as
      // evenly as an integer split allows.
      expect(targetMinutes[roster[5]], 16);
      expect(targetMinutes[roster[6]], 16);
      expect(targetMinutes[roster[7]], 10);
      expect(targetMinutes[roster[8]], 9);
      expect(targetMinutes[roster[9]], 7);
      expect(targetMinutes.values.fold(0, (a, b) => a + b), 200);
    });

    test('sums to exactly 200 for every roster size from 5 to 12', () {
      for (var size = 5; size <= 12; size++) {
        final roster = testRoster('r').take(size).toList();
        final targetMinutes = targetMinutesForOrderedRoster(roster);
        expect(
          targetMinutes.values.fold(0, (a, b) => a + b),
          200,
          reason: 'roster size $size',
        );
      }
    });
  });

  group('pickOnCourt', () {
    test('picks the 5 highest-target-minutes players when nobody has '
        'played yet', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      final expectedStarters =
          ([
                ...roster,
              ]..sort((a, b) => targetMinutes[b]!.compareTo(targetMinutes[a]!)))
              .take(5)
              .toSet();

      final onCourt = pickOnCourt(
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {},
      );

      expect(onCourt.toSet(), expectedStarters);
    });

    test('excludes fouled-out players', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      final best = roster.first;

      final onCourt = pickOnCourt(
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {best},
      );

      expect(onCourt, isNot(contains(best)));
      expect(onCourt.length, 5);
    });

    test('prefers a player who is further behind their target minutes', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      // The worst-rated player has the lowest target minutes but has
      // played none of them, while everyone else is already fully caught
      // up -- they should still get picked over a caught-up starter.
      final worst = roster.last;
      final minutesPlayed = {
        for (final p in roster) p: targetMinutes[p]!.toDouble(),
      }..[worst] = 0;

      final onCourt = pickOnCourt(
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: minutesPlayed,
        fouledOut: {},
      );

      expect(onCourt, contains(worst));
    });

    test('throws when fewer than 5 players are available', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      final fouledOut = roster.take(8).toSet();

      expect(
        () => pickOnCourt(
          roster: roster,
          targetMinutes: targetMinutes,
          minutesPlayed: {},
          fouledOut: fouledOut,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('substituteForFoulOut', () {
    test('replaces exactly the fouled-out player and nobody else', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      final onCourt = pickOnCourt(
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {},
      );
      final foulingPlayer = onCourt[2];

      final result = substituteForFoulOut(
        foulingPlayer: foulingPlayer,
        onCourt: onCourt,
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {foulingPlayer},
      );

      expect(result.length, 5);
      expect(result, isNot(contains(foulingPlayer)));
      for (var i = 0; i < onCourt.length; i++) {
        if (i == 2) continue;
        expect(result[i], onCourt[i]);
      }
    });

    test('never picks a replacement who is already on court', () {
      final roster = testRoster('r');
      final targetMinutes = targetMinutesFor(roster);
      final onCourt = pickOnCourt(
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {},
      );
      final foulingPlayer = onCourt.first;

      final result = substituteForFoulOut(
        foulingPlayer: foulingPlayer,
        onCourt: onCourt,
        roster: roster,
        targetMinutes: targetMinutes,
        minutesPlayed: {},
        fouledOut: {foulingPlayer},
      );

      final Set<Player> resultSet = result.toSet();
      expect(resultSet.length, 5);
    });
  });
}
