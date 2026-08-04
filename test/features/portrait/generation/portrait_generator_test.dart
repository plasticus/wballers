import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';

final _weights = PortraitWeights(
  skinTone: const {'pale': 3, 'deep': 38},
  hairColorByTone: const {
    'pale': {'blonde': 22, 'black': 8},
    'deep': {'black': 55, 'blonde': 3},
  },
  hair: const {'none': 0.1, 'hair_afro': 4.0},
  neonHair: const {'natural': 95, 'limegreen': 1.25},
  eyes: const {'eyes_1center': 1},
  nose: const {'nose_1': 1},
  mouth: const {'mouth_1': 1},
  eyebrows: const {'none': 1, 'eyebrow_1': 1},
  facial: const {'none': 1, 'facial_goat': 1},
  accessories: const {'none': 1, 'goggles_1': 1},
);

void main() {
  test('the same seed produces an identical appearance', () {
    final a = generatePortraitAppearance(
      Random(7),
      isCoach: false,
      weights: _weights,
    );
    final b = generatePortraitAppearance(
      Random(7),
      isCoach: false,
      weights: _weights,
    );

    expect(a.skinTone, b.skinTone);
    expect(a.hairColor, b.hairColor);
    expect(a.hair, b.hair);
    expect(a.eyebrows, b.eyebrows);
    expect(a.accessories, b.accessories);
  });

  test('athletes never get facial hair', () {
    final random = Random(3);
    for (var i = 0; i < 100; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: false,
        weights: _weights,
      );
      expect(appearance.facial, isNull);
    }
  });

  test('coaches can roll facial hair', () {
    final random = Random(5);
    final facialValues = <String?>{};
    for (var i = 0; i < 200; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: true,
        weights: _weights,
      );
      facialValues.add(appearance.facial);
    }
    expect(facialValues, contains(isNotNull));
  });

  test('never rolls a special/neon top-hair color at generation time', () {
    final random = Random(11);
    for (var i = 0; i < 100; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: false,
        weights: _weights,
      );
      expect(appearance.topHairColor, isNull);
    }
  });

  test('translates the "none" hair sentinel to null', () {
    final onlyBald = PortraitWeights(
      skinTone: _weights.skinTone,
      hairColorByTone: _weights.hairColorByTone,
      hair: const {'none': 1.0},
      neonHair: _weights.neonHair,
      eyes: _weights.eyes,
      nose: _weights.nose,
      mouth: _weights.mouth,
      eyebrows: _weights.eyebrows,
      facial: _weights.facial,
      accessories: _weights.accessories,
    );

    final appearance = generatePortraitAppearance(
      Random(1),
      isCoach: false,
      weights: onlyBald,
    );

    expect(appearance.hair, isNull);
  });

  test('coach-only fields other than facial stay null', () {
    final appearance = generatePortraitAppearance(
      Random(9),
      isCoach: true,
      weights: _weights,
    );

    expect(appearance.shoulders, isNull);
    expect(appearance.hat, isNull);
    expect(appearance.glasses, isNull);
  });
}
