import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';

void main() {
  test('portraitWeightsFromJson parses every table', () {
    final weights = portraitWeightsFromJson({
      'skin_tone': {'pale': 3, 'deep': 38},
      'hair_color': {
        'pale': {'blonde': 22, 'black': 8},
        'deep': {'black': 55, 'blonde': 3},
      },
      'hair': {'none': 0.1, 'hair_afro': 4.0},
      'neon_hair': {'natural': 95, 'limegreen': 1.25},
      'eyes': {'eyes_1center': 1},
      'nose': {'nose_1': 1},
      'mouth': {'mouth_1': 1},
      'eyebrows': {'none': 1, 'eyebrow_1': 1},
      'facial': {'none': 1, 'facial_goat': 1},
      'accessories': {'none': 55, 'goggles_1': 2.5},
    });

    expect(weights.skinTone, {'pale': 3.0, 'deep': 38.0});
    expect(weights.hairColorByTone['pale'], {'blonde': 22.0, 'black': 8.0});
    expect(weights.hair['hair_afro'], 4.0);
    expect(weights.neonHair['natural'], 95.0);
    expect(weights.accessories['none'], 55.0);
  });

  test('pickWeighted never returns a zero-weight key', () {
    final random = Random(1);
    final weights = {'never': 0.0, 'always': 100.0};
    for (var i = 0; i < 200; i++) {
      expect(pickWeighted(random, weights), 'always');
    }
  });

  test('pickWeighted respects relative proportions over many draws', () {
    final random = Random(2);
    final weights = {'common': 90.0, 'rare': 10.0};
    var commonCount = 0;
    const sampleSize = 2000;
    for (var i = 0; i < sampleSize; i++) {
      if (pickWeighted(random, weights) == 'common') commonCount++;
    }
    final ratio = commonCount / sampleSize;
    expect(ratio, greaterThan(0.8));
    expect(ratio, lessThan(1.0));
  });

  test('pickWeighted is deterministic for a given seed', () {
    final weights = {'a': 1.0, 'b': 1.0, 'c': 1.0};
    final randomA = Random(42);
    final randomB = Random(42);
    final picksA = List.generate(20, (_) => pickWeighted(randomA, weights));
    final picksB = List.generate(20, (_) => pickWeighted(randomB, weights));
    expect(picksA, picksB);
  });
}
