import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/engine/contest_resolver.dart';

void main() {
  group('contestProbability', () {
    test('equal ratings land exactly at the midpoint of floor/ceiling', () {
      final probability = contestProbability(
        attackerRating: 60,
        defenderRating: 60,
      );

      expect(probability, closeTo(0.5, 1e-9));
    });

    test('a higher attacker rating raises the probability above 50%', () {
      final probability = contestProbability(
        attackerRating: 80,
        defenderRating: 50,
      );

      expect(probability, greaterThan(0.5));
    });

    test('a lower attacker rating lowers the probability below 50%', () {
      final probability = contestProbability(
        attackerRating: 40,
        defenderRating: 70,
      );

      expect(probability, lessThan(0.5));
    });

    test('probability increases monotonically with the rating gap', () {
      final probabilities = [
        for (var defender = 20; defender <= 80; defender += 10)
          contestProbability(attackerRating: 50, defenderRating: defender),
      ];

      for (var i = 1; i < probabilities.length; i++) {
        expect(probabilities[i], lessThan(probabilities[i - 1]));
      }
    });

    test('even a hopeless mismatch never drops below floor', () {
      final probability = contestProbability(
        attackerRating: 1,
        defenderRating: 99,
        floor: 0.05,
        ceiling: 0.95,
      );

      expect(probability, closeTo(0.05, 0.01));
    });

    test('even a dominant mismatch never reaches ceiling', () {
      final probability = contestProbability(
        attackerRating: 99,
        defenderRating: 1,
        floor: 0.05,
        ceiling: 0.95,
      );

      expect(probability, closeTo(0.95, 0.01));
    });

    test('a higher steepness widens the gap in probability for the same '
        'rating difference', () {
      final gentle = contestProbability(
        attackerRating: 70,
        defenderRating: 50,
        steepness: 0.02,
      );
      final steep = contestProbability(
        attackerRating: 70,
        defenderRating: 50,
        steepness: 0.1,
      );

      expect(steep, greaterThan(gentle));
    });
  });

  group('resolveContest', () {
    test('is deterministic for a given seed', () {
      final a = resolveContest(
        Random(7),
        attackerRating: 65,
        defenderRating: 55,
      );
      final b = resolveContest(
        Random(7),
        attackerRating: 65,
        defenderRating: 55,
      );

      expect(a, b);
    });

    test('win rate across many rolls converges to contestProbability', () {
      const sampleSize = 5000;
      final random = Random(2024);
      final expected = contestProbability(
        attackerRating: 70,
        defenderRating: 55,
      );

      var wins = 0;
      for (var i = 0; i < sampleSize; i++) {
        if (resolveContest(random, attackerRating: 70, defenderRating: 55)) {
          wins++;
        }
      }

      expect(wins / sampleSize, closeTo(expected, 0.03));
    });

    test('always fails when probability is clamped to the floor and the '
        'roll lands above it', () {
      final random = _FixedRandom(0.5);

      final result = resolveContest(
        random,
        attackerRating: 1,
        defenderRating: 99,
        floor: 0.05,
        ceiling: 0.95,
      );

      expect(result, isFalse);
    });

    test('always succeeds when probability is clamped to the ceiling and '
        'the roll lands below it', () {
      final random = _FixedRandom(0.5);

      final result = resolveContest(
        random,
        attackerRating: 99,
        defenderRating: 1,
        floor: 0.05,
        ceiling: 0.95,
      );

      expect(result, isTrue);
    });
  });
}

/// A [Random] stub that always returns the same [nextDouble] value, for
/// pinning down boundary behavior without depending on a real seed's
/// sequence.
class _FixedRandom implements Random {
  _FixedRandom(this._value);

  final double _value;

  @override
  double nextDouble() => _value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}
