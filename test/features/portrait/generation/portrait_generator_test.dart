import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_height_tier.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_manifest.dart';
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

final _manifest = PortraitManifest(
  hair: const ['hair_afro.png'],
  eyes: const ['eyes_1center.png'],
  eyebrows: const ['eyebrow_1.png'],
  nose: const ['nose_1.png'],
  mouth: const ['mouth_1.png'],
  facial: const ['facial_goat.png'],
  accessories: const ['goggles_1.png'],
  shoulders: const ['shoulder_black.png', 'shoulder_grey.png'],
  hats: const ['hat_fedora.png'],
  glasses: const ['glasses_round.png'],
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

  test('coaches never get facial hair either -- every character in this game '
      'is a woman, so the beard/mustache pool never gets drawn from at '
      'random-generation time (the portrait editor can still opt a coach '
      'into it deliberately)', () {
    final random = Random(5);
    for (var i = 0; i < 200; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: true,
        weights: _weights,
      );
      expect(appearance.facial, isNull);
    }
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

  test(
    'hat and glasses always stay null -- no weight table exists for them',
    () {
      final appearance = generatePortraitAppearance(
        Random(9),
        isCoach: true,
        weights: _weights,
        manifest: _manifest,
      );

      expect(appearance.hat, isNull);
      expect(appearance.glasses, isNull);
    },
  );

  test('shoulders stay null when no manifest is given', () {
    final appearance = generatePortraitAppearance(
      Random(9),
      isCoach: true,
      weights: _weights,
    );

    expect(appearance.shoulders, isNull);
  });

  test('a coach always gets shoulders when a manifest is given -- '
      'player-edit.html never leaves this blank for a coach', () {
    final random = Random(13);
    for (var i = 0; i < 50; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: true,
        weights: _weights,
        manifest: _manifest,
      );
      expect(appearance.shoulders, isNotNull);
      expect(_manifest.shoulders, contains('${appearance.shoulders}.png'));
    }
  });

  test('a player never gets shoulders, manifest or not', () {
    final random = Random(17);
    for (var i = 0; i < 50; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: false,
        weights: _weights,
        manifest: _manifest,
      );
      expect(appearance.shoulders, isNull);
    }
  });

  test(
    'a coach never gets goggles, even when they are the only other option',
    () {
      final gogglesOrNone = PortraitWeights(
        skinTone: _weights.skinTone,
        hairColorByTone: _weights.hairColorByTone,
        hair: _weights.hair,
        neonHair: _weights.neonHair,
        eyes: _weights.eyes,
        nose: _weights.nose,
        mouth: _weights.mouth,
        eyebrows: _weights.eyebrows,
        facial: _weights.facial,
        accessories: const {'goggles_1': 1, 'headband_black': 1},
      );

      final random = Random(19);
      for (var i = 0; i < 50; i++) {
        final appearance = generatePortraitAppearance(
          random,
          isCoach: true,
          weights: gogglesOrNone,
        );
        expect(appearance.accessories, isNot(startsWith('goggles')));
      }
    },
  );

  test('defaults to the baseline base sprite when no heightTier is given', () {
    final appearance = generatePortraitAppearance(
      Random(1),
      isCoach: false,
      weights: _weights,
    );
    expect(appearance.baseSprite, PortraitHeightTier.baseline.baseSpriteAsset);
  });

  test('heightTier selects the matching base sprite', () {
    for (final tier in PortraitHeightTier.values) {
      final appearance = generatePortraitAppearance(
        Random(1),
        isCoach: false,
        weights: _weights,
        heightTier: tier,
      );
      expect(appearance.baseSprite, tier.baseSpriteAsset);
    }
  });

  test('a coach always renders at the baseline tier -- no height stat', () {
    final appearance = generatePortraitAppearance(
      Random(1),
      isCoach: true,
      weights: _weights,
    );
    expect(appearance.baseSprite, PortraitHeightTier.baseline.baseSpriteAsset);
  });

  test('a player can still get goggles', () {
    final onlyGoggles = PortraitWeights(
      skinTone: _weights.skinTone,
      hairColorByTone: _weights.hairColorByTone,
      hair: _weights.hair,
      neonHair: _weights.neonHair,
      eyes: _weights.eyes,
      nose: _weights.nose,
      mouth: _weights.mouth,
      eyebrows: _weights.eyebrows,
      facial: _weights.facial,
      accessories: const {'goggles_1': 1},
    );

    final appearance = generatePortraitAppearance(
      Random(21),
      isCoach: false,
      weights: onlyGoggles,
    );

    expect(appearance.accessories, 'goggles_1');
  });
}
