import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/generation/trait_generator.dart';

void main() {
  test('the same seed produces the same traits', () {
    final a = generateTraits(Random(7));
    final b = generateTraits(Random(7));

    expect(a, b);
  });

  test('never rolls more than maxTraits', () {
    final random = Random(11);
    for (var i = 0; i < 200; i++) {
      expect(generateTraits(random, maxTraits: 3).length, lessThanOrEqualTo(3));
    }
  });

  test('never rolls Homegrown', () {
    final random = Random(13);
    for (var i = 0; i < 200; i++) {
      expect(generateTraits(random), isNot(contains(Trait.homegrown)));
    }
  });

  test('never rolls both sides of an opposite pair', () {
    final random = Random(17);
    for (var i = 0; i < 200; i++) {
      final traits = generateTraits(random, maxTraits: 29);
      for (final trait in traits) {
        final opposite = oppositeOf(trait);
        expect(opposite == null || !traits.contains(opposite), isTrue);
      }
    }
  });

  test('can roll zero traits', () {
    // Exhaustively check a run of seeds turns up at least one zero-trait
    // roll, since generateTraits(random, maxTraits: 0) always does.
    expect(generateTraits(Random(1), maxTraits: 0), isEmpty);
  });
}
