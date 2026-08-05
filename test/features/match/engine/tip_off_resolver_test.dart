import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/engine/tip_off_resolver.dart';

import '../../../support/match_test_players.dart';

void main() {
  test('is deterministic for a given seed', () {
    final a = testPlayer(id: 'a', heightInches: 74);
    final b = testPlayer(id: 'b', heightInches: 68);

    final first = resolveTipOff(Random(4), a, b);
    final second = resolveTipOff(Random(4), a, b);

    expect(first, second);
  });

  test('a much taller jumper wins the tip clearly more often than not, all '
      'else equal', () {
    final tall = testPlayer(id: 'tall', heightInches: 78);
    final short = testPlayer(id: 'short', heightInches: 64);
    final random = Random(21);

    var tallWins = 0;
    const sampleSize = 500;
    for (var i = 0; i < sampleSize; i++) {
      if (resolveTipOff(random, tall, short)) {
        tallWins++;
      }
    }

    expect(tallWins / sampleSize, greaterThan(0.65));
  });

  test('equally tall jumpers with equal ratings split close to 50/50', () {
    final a = testPlayer(id: 'a', heightInches: 72);
    final b = testPlayer(id: 'b', heightInches: 72);
    final random = Random(33);

    var aWins = 0;
    const sampleSize = 1000;
    for (var i = 0; i < sampleSize; i++) {
      if (resolveTipOff(random, a, b)) {
        aWins++;
      }
    }

    expect(aWins / sampleSize, closeTo(0.5, 0.05));
  });
}
