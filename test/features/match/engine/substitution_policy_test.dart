import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/engine/substitution_policy.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

import '../../../support/match_test_players.dart';

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

    test('throws when the roster does not have exactly 12 players', () {
      final roster = testRoster('r').take(11).toList();

      expect(() => targetMinutesFor(roster), throwsA(isA<AssertionError>()));
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

    test('throws when the roster does not have exactly 12 players', () {
      final roster = testRoster('r').take(11).toList();

      expect(
        () => targetMinutesForOrderedRoster(roster),
        throwsA(isA<AssertionError>()),
      );
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
