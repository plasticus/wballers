import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';

import '../../../support/match_test_players.dart';

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
    final random = Random(23);
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
