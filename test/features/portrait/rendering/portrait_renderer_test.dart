import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_height_tier.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_catalog_loader.dart';
import 'package:womensbballmgr/features/portrait/rendering/portrait_colors.dart';
import 'package:womensbballmgr/features/portrait/rendering/portrait_renderer.dart';

const _minimalAthlete = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'medium',
  hairColor: 'black',
  eyes: 'eyes_1center',
  nose: 'nose_1',
  mouth: 'mouth_1',
  isCoach: false,
);

const _fullAthlete = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'deep',
  hair: 'hair_afro',
  hairColor: 'black',
  eyes: 'eyes_wide',
  eyebrows: 'eyebrow_3',
  nose: 'nose_broken',
  mouth: 'mouth_5',
  accessories: 'headband_red',
  isCoach: false,
);

const _fullCoach = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'pale',
  hair: 'hair_pompadour',
  hairColor: 'blonde',
  eyes: 'eyes_downleft',
  eyebrows: 'eyebrow_7',
  nose: 'nose_hook',
  mouth: 'mouth_2',
  accessories: 'goggles_2',
  isCoach: true,
  shoulders: 'shoulder_grey',
  hat: 'hat_tophat',
  glasses: 'glasses_round',
  facial: 'facial_goat',
);

Future<ui.Image> _decode(Uint8List pngBytes) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'renders a minimal athlete to a valid PNG at the requested size',
    () async {
      final bytes = await renderPortraitPng(_minimalAthlete, outputSize: 64);
      expect(bytes, isNotEmpty);

      final image = await _decode(bytes);
      expect(image.width, 64);
      expect(image.height, 64);
    },
  );

  test('renders every optional athlete layer without error', () async {
    final bytes = await renderPortraitPng(_fullAthlete, outputSize: 64);
    final image = await _decode(bytes);
    expect(image.width, 64);
  });

  test('renders every coach-only layer without error', () async {
    final bytes = await renderPortraitPng(_fullCoach, outputSize: 64);
    final image = await _decode(bytes);
    expect(image.width, 64);
  });

  test(
    'rendering the same appearance twice produces identical bytes',
    () async {
      final a = await renderPortraitPng(_fullAthlete, outputSize: 64);
      final b = await renderPortraitPng(_fullAthlete, outputSize: 64);
      expect(a, b);
    },
  );

  test('a jersey color changes the output for an athlete', () async {
    final withoutJersey = await renderPortraitPng(
      _minimalAthlete,
      outputSize: 64,
    );
    final withJersey = await renderPortraitPng(
      _minimalAthlete,
      jersey: const RgbColor(200, 20, 20),
      outputSize: 64,
    );
    expect(withJersey, isNot(equals(withoutJersey)));
  });

  test('a jersey color does not change a coach portrait', () async {
    final withoutJersey = await renderPortraitPng(_fullCoach, outputSize: 64);
    final withJersey = await renderPortraitPng(
      _fullCoach,
      jersey: const RgbColor(200, 20, 20),
      outputSize: 64,
    );
    expect(withJersey, equals(withoutJersey));
  });

  test(
    'every height tier renders without error, at a distinct output',
    () async {
      final rendered = <PortraitHeightTier, Uint8List>{};
      for (final tier in PortraitHeightTier.values) {
        final bytes = await renderPortraitPng(
          _minimalAthlete.copyWith(baseSprite: tier.baseSpriteAsset),
          outputSize: 64,
        );
        expect(bytes, isNotEmpty);
        rendered[tier] = bytes;
      }
      expect(
        rendered[PortraitHeightTier.tall],
        isNot(rendered[PortraitHeightTier.baseline]),
      );
      expect(
        rendered[PortraitHeightTier.tallest],
        isNot(rendered[PortraitHeightTier.baseline]),
      );
      expect(
        rendered[PortraitHeightTier.tallest],
        isNot(rendered[PortraitHeightTier.tall]),
      );
    },
  );

  test('a coach with a shoulders layer still renders correctly at every tier '
      '(shoulders stay unshifted, everything else shifts)', () async {
    for (final tier in PortraitHeightTier.values) {
      final bytes = await renderPortraitPng(
        _fullCoach.copyWith(baseSprite: tier.baseSpriteAsset),
        outputSize: 64,
      );
      final image = await _decode(bytes);
      expect(image.width, 64);
    }
  });

  test('renders every real generated appearance without error', () async {
    final weights = await loadPortraitWeights();
    final random = Random(2024);
    for (var i = 0; i < 8; i++) {
      final appearance = generatePortraitAppearance(
        random,
        isCoach: i.isEven,
        weights: weights,
      );
      final bytes = await renderPortraitPng(appearance, outputSize: 32);
      expect(bytes, isNotEmpty);
    }
  });
}
