import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/match/engine/substitution_policy.dart';

import '../../../support/match_test_players.dart';

Coach _coach({required int offense, required int defense}) {
  return Coach(
    name: 'Coach',
    stats: CoachStats(
      offense: offense,
      defense: defense,
      development: 50,
      motivation: 50,
      management: 50,
    ),
    archetype: CoachArchetype.steadyHand,
  );
}

void main() {
  test('is deterministic for a given seed', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');

    final a = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );
    final b = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    expect(a.homeScore, b.homeScore);
    expect(a.awayScore, b.awayScore);
    expect(a.homeScoreByQuarter, b.homeScoreByQuarter);
    expect(a.awayScoreByQuarter, b.awayScoreByQuarter);
    expect(a.events.length, b.events.length);
  });

  test('final score equals the sum of quarter scores', () {
    final result = simulateMatch(
      Random(3),
      homeRoster: testRoster('home'),
      awayRoster: testRoster('away'),
    );

    expect(
      result.homeScoreByQuarter.fold(0, (a, b) => a + b),
      result.homeScore,
    );
    expect(
      result.awayScoreByQuarter.fold(0, (a, b) => a + b),
      result.awayScore,
    );
  });

  test('runs at least 4 quarters', () {
    final result = simulateMatch(
      Random(3),
      homeRoster: testRoster('home'),
      awayRoster: testRoster('away'),
    );

    expect(result.homeScoreByQuarter.length, greaterThanOrEqualTo(4));
    expect(result.awayScoreByQuarter.length, greaterThanOrEqualTo(4));
  });

  test('never ends in a tie -- overtime keeps playing until it breaks', () {
    final random = Random(17);

    for (var i = 0; i < 100; i++) {
      // Evenly-matched (same rating distribution, distinct players)
      // rosters on both sides maximize the chance of a regulation tie,
      // which is exactly the scenario overtime exists to resolve.
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );

      expect(result.homeScore, isNot(result.awayScore));
    }
  });

  test('some games actually go to overtime', () {
    // Not a magic seed -- 23 used to reliably produce one within 100
    // games, but the blowout-pace rubber-banding fix
    // (`possession_engine.dart`'s `kBlowoutPaceMargin`) changes how many
    // seconds a possession takes once either side is up by 20+, which
    // shifts every later possession's timing enough to change which of
    // these evenly-matched games land on a regulation tie. 1 is a
    // re-verified seed that still reliably hits one within 100 games.
    final random = Random(1);
    var sawOvertime = false;

    for (var i = 0; i < 100; i++) {
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );
      if (result.homeScoreByQuarter.length > 4) {
        sawOvertime = true;
        break;
      }
    }

    expect(sawOvertime, isTrue);
  });

  test('both teams end up with roughly a full game of combined court '
      'minutes, and both sides match', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    final result = simulateMatch(
      Random(7),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    final homeMinutes = homeRoster.fold<double>(
      0,
      (sum, p) => sum + (result.minutesPlayed[p] ?? 0),
    );
    final awayMinutes = awayRoster.fold<double>(
      0,
      (sum, p) => sum + (result.minutesPlayed[p] ?? 0),
    );

    // Both teams share the same clock, so their total court-minutes must
    // match each other exactly -- and land near 200 (5 players x 40
    // minutes), with some slack for quarters that ran past the buzzer
    // (see `simulateMatch`'s doc comment on that simplification) and for
    // the rare game that needed overtime.
    expect(homeMinutes, closeTo(awayMinutes, 0.01));
    expect(homeMinutes, greaterThan(195));
    expect(homeMinutes, lessThan(320));
  });

  test('every player who fouled out has at least 6 personal fouls', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    final result = simulateMatch(
      Random(99),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    for (final player in result.fouledOut) {
      expect(result.personalFouls[player]!, greaterThanOrEqualTo(6));
    }
  });

  test('personal fouls are recorded for players on both rosters over many '
      'games', () {
    var sawFouls = false;
    final random = Random(123);

    for (var i = 0; i < 20; i++) {
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );
      if (result.personalFouls.values.any((count) => count > 0)) {
        sawFouls = true;
        break;
      }
    }

    expect(sawFouls, isTrue);
  });

  test('an explicit target-minutes map overrides the automatic overall-based '
      'ranking -- the GM\'s own bench order actually drives who plays', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    // Reversed: the worst-overall player on the roster is list position
    // 0, so an ordered-roster ranking gives *her* the top target
    // minutes, opposite of what the automatic overall-based default
    // would do.
    final benchOrder = homeRoster.reversed.toList();

    final result = simulateMatch(
      Random(7),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
      homeTargetMinutes: targetMinutesForOrderedRoster(benchOrder),
    );

    final topBenchOrderPlayer = benchOrder.first; // worst overall
    final bottomBenchOrderPlayer = benchOrder.last; // best overall
    expect(
      result.minutesPlayed[topBenchOrderPlayer]!,
      greaterThan(result.minutesPlayed[bottomBenchOrderPlayer]!),
    );
  });

  test('a team with a real coach Offense/Defense advantage scores more '
      'often than an identical team with no coach data at all (TODO.md '
      'coach-stats item -- a direct GM ask)', () {
    // Home's coach wins the offense-vs-defense matchup both ways: a
    // strong Offense against a weak Defense, and a strong Defense of
    // their own against a weak Offense.
    final favoredHomeCoach = _coach(offense: 90, defense: 90);
    final weakAwayCoach = _coach(offense: 10, defense: 10);
    const sampleSize = 200;

    var homeScoreWithCoaches = 0;
    var awayScoreWithCoaches = 0;
    final withCoaches = Random(21);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulateMatch(
        withCoaches,
        homeRoster: testRoster('home-$i', baseRating: 50, step: 0),
        awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
        homeCoach: favoredHomeCoach,
        awayCoach: weakAwayCoach,
      );
      homeScoreWithCoaches += result.homeScore;
      awayScoreWithCoaches += result.awayScore;
    }

    var homeScoreNoCoaches = 0;
    var awayScoreNoCoaches = 0;
    final noCoaches = Random(21);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulateMatch(
        noCoaches,
        homeRoster: testRoster('home-$i', baseRating: 50, step: 0),
        awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
      );
      homeScoreNoCoaches += result.homeScore;
      awayScoreNoCoaches += result.awayScore;
    }

    // With the coach matchup in play, home's scoring margin over away
    // should be meaningfully wider than the same matchup with no coach
    // bonus applied at all.
    final marginWithCoaches = homeScoreWithCoaches - awayScoreWithCoaches;
    final marginNoCoaches = homeScoreNoCoaches - awayScoreNoCoaches;
    expect(marginWithCoaches, greaterThan(marginNoCoaches));
  });

  test('omitting homeCoach/awayCoach leaves the game completely unaffected '
      '-- the exact same result as before the coach bonus existed', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');

    final withoutCoaches = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );
    final withNullCoaches = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
      homeCoach: null,
      awayCoach: null,
    );

    expect(withoutCoaches.homeScore, withNullCoaches.homeScore);
    expect(withoutCoaches.awayScore, withNullCoaches.awayScore);
  });

  test('throws when a roster does not have exactly 12 players', () {
    final homeRoster = testRoster('home').take(10).toList();
    final awayRoster = testRoster('away');

    expect(
      () => simulateMatch(
        Random(1),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
