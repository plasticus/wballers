import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/player/generation/archetype_generator.dart';

void main() {
  test('the same seed produces the same archetype', () {
    final a = generateArchetype(Random(7), Position.center);
    final b = generateArchetype(Random(7), Position.center);

    expect(a, b);
  });

  test('always returns an archetype valid for the given position', () {
    final random = Random(23);
    for (var i = 0; i < 200; i++) {
      final position = Position.values[i % Position.values.length];
      final archetype = generateArchetype(random, position);
      expect(kArchetypesByPosition[position], contains(archetype));
    }
  });
}
