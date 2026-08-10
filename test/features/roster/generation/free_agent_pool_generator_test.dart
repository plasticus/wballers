import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/generation/free_agent_pool_generator.dart';

void main() {
  test('generates the requested count, deterministically for a given '
      'seed', () {
    final a = generateFreeAgentPool(Random(1), count: 12);
    final b = generateFreeAgentPool(Random(1), count: 12);

    expect(a, hasLength(12));
    expect(a.map((p) => p.name), b.map((p) => p.name));
    expect(
      a.map((p) => p.ratings.potential),
      b.map((p) => p.ratings.potential),
    );
  });

  test('exactly one player is the deliberately-planted decent prospect, '
      'reliably distinguishable from every filler -- not just usually', () {
    // Across many seeds, not just one -- this needs to be a structural
    // guarantee (the Assistant GM mail card finds this player by
    // scanning for the pool's highest potential), not a fluke that
    // happens to hold for a couple of hand-picked seeds.
    for (var seed = 0; seed < 500; seed++) {
      final pool = generateFreeAgentPool(Random(seed));
      final byPotential = [...pool]
        ..sort((a, b) => b.ratings.potential.compareTo(a.ratings.potential));

      expect(
        byPotential.first.ratings.potential,
        inInclusiveRange(77, 83),
        reason:
            'seed $seed: the decent prospect should land near '
            '$kDecentFreeAgentPotential potential',
      );
      // A real gap, not a coin-flip margin -- the runner-up is
      // meaningfully lower, every time.
      expect(
        byPotential.first.ratings.potential - byPotential[1].ratings.potential,
        greaterThanOrEqualTo(5),
        reason: 'seed $seed',
      );
    }
  });

  test('filler quality stays below roster level -- max OVR around 65, per '
      'the GM\'s own guideline', () {
    final random = Random(9);
    var maxOverall = 0;
    for (var i = 0; i < 200; i++) {
      for (final player in generateFreeAgentPool(random)) {
        if (player.ratings.overall > maxOverall) {
          maxOverall = player.ratings.overall;
        }
      }
    }
    expect(maxOverall, lessThanOrEqualTo(70));
  });

  test('the decent prospect is a 23-year-old international rookie -- a '
      'direct GM ask so a high-potential pickup has real runway to grow', () {
    for (var seed = 0; seed < 100; seed++) {
      final pool = generateFreeAgentPool(Random(seed));
      final decent = pool.reduce(
        (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
      );

      expect(decent.age, kDecentFreeAgentAge, reason: 'seed $seed');
      expect(
        decent.yearsOfService,
        0,
        reason: 'seed $seed: a rookie, not a late-debuting veteran',
      );
      expect(
        decent.college,
        isNull,
        reason: 'seed $seed: should read as international, not domestic',
      );
    }
  });

  test('different seeds produce meaningfully different pools', () {
    final a = generateFreeAgentPool(Random(10));
    final b = generateFreeAgentPool(Random(20));

    final aNames = a.map((p) => p.name).toSet();
    final bNames = b.map((p) => p.name).toSet();

    expect(aNames, isNot(equals(bNames)));
  });
}
