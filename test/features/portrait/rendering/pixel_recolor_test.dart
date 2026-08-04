import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/rendering/pixel_recolor.dart';
import 'package:womensbballmgr/features/portrait/rendering/portrait_colors.dart';

Uint8List _pixel(int r, int g, int b, int a) {
  return Uint8List.fromList([r, g, b, a]);
}

void main() {
  group('recolorMagentaPlaceholder', () {
    test('recolors full-brightness magenta to the target color exactly', () {
      final pixels = _pixel(255, 0, 255, 255);
      recolorMagentaPlaceholder(pixels, const RgbColor(0x1b, 0x1b, 0x1b));
      expect(pixels, _pixel(0x1b, 0x1b, 0x1b, 255));
    });

    test('scales darker magenta shades proportionally, preserving shading', () {
      // Half-brightness magenta placeholder (r == b == 128, g <= 5).
      final pixels = _pixel(128, 0, 128, 255);
      recolorMagentaPlaceholder(pixels, const RgbColor(200, 100, 50));
      final factor = 128 / 255;
      expect(pixels[0], (200 * factor).round());
      expect(pixels[1], (100 * factor).round());
      expect(pixels[2], (50 * factor).round());
      expect(pixels[3], 255);
    });

    test('leaves transparent pixels untouched', () {
      final pixels = _pixel(255, 0, 255, 0);
      recolorMagentaPlaceholder(pixels, const RgbColor(0, 0, 0));
      expect(pixels, _pixel(255, 0, 255, 0));
    });

    test('leaves non-magenta pixels untouched', () {
      final pixels = _pixel(10, 20, 30, 255);
      recolorMagentaPlaceholder(pixels, const RgbColor(0, 0, 0));
      expect(pixels, _pixel(10, 20, 30, 255));
    });

    test('leaves black (r == b == 0) untouched -- not a placeholder', () {
      final pixels = _pixel(0, 0, 0, 255);
      recolorMagentaPlaceholder(pixels, const RgbColor(9, 9, 9));
      expect(pixels, _pixel(0, 0, 0, 255));
    });
  });

  group('recolorBaseSprite', () {
    test('recolors exact skin-base pixels to the target skin tone', () {
      final pixels = _pixel(
        kSourceSkinBase.r,
        kSourceSkinBase.g,
        kSourceSkinBase.b,
        255,
      );
      const target = RgbColor(0x92, 0x61, 0x40); // deep
      recolorBaseSprite(pixels, skin: target);
      expect(pixels, _pixel(target.r, target.g, target.b, 255));
    });

    test('recolors exact skin-shadow pixels to a proportional shadow', () {
      final pixels = _pixel(
        kSourceSkinShadow.r,
        kSourceSkinShadow.g,
        kSourceSkinShadow.b,
        255,
      );
      const target = RgbColor(0x92, 0x61, 0x40);
      recolorBaseSprite(pixels, skin: target);
      final shadow = proportionalShadow(target);
      expect(pixels, _pixel(shadow.r, shadow.g, shadow.b, 255));
    });

    test('leaves the shirt collar untouched when no jersey color given', () {
      final pixels = _pixel(
        kSourceShirtBase.r,
        kSourceShirtBase.g,
        kSourceShirtBase.b,
        255,
      );
      recolorBaseSprite(pixels, skin: const RgbColor(1, 2, 3));
      expect(
        pixels,
        _pixel(kSourceShirtBase.r, kSourceShirtBase.g, kSourceShirtBase.b, 255),
      );
    });

    test('recolors the shirt collar when a jersey color is given', () {
      final pixels = _pixel(
        kSourceShirtBase.r,
        kSourceShirtBase.g,
        kSourceShirtBase.b,
        255,
      );
      const jersey = RgbColor(200, 10, 10);
      recolorBaseSprite(pixels, skin: const RgbColor(1, 2, 3), jersey: jersey);
      expect(pixels, _pixel(jersey.r, jersey.g, jersey.b, 255));
    });

    test('leaves unrelated pixels untouched', () {
      final pixels = _pixel(5, 6, 7, 255);
      recolorBaseSprite(
        pixels,
        skin: const RgbColor(1, 2, 3),
        jersey: const RgbColor(9, 9, 9),
      );
      expect(pixels, _pixel(5, 6, 7, 255));
    });
  });

  group('recolorNoseShadow', () {
    test('recolors exact skin-shadow pixels proportionally', () {
      final pixels = _pixel(
        kSourceSkinShadow.r,
        kSourceSkinShadow.g,
        kSourceSkinShadow.b,
        255,
      );
      const target = RgbColor(0x5e, 0x3c, 0x28); // chocolate
      recolorNoseShadow(pixels, target);
      final shadow = proportionalShadow(target);
      expect(pixels, _pixel(shadow.r, shadow.g, shadow.b, 255));
    });

    test('leaves transparent pixels untouched', () {
      final pixels = _pixel(
        kSourceSkinShadow.r,
        kSourceSkinShadow.g,
        kSourceSkinShadow.b,
        0,
      );
      recolorNoseShadow(pixels, const RgbColor(1, 2, 3));
      expect(pixels[3], 0);
    });

    test('leaves non-shadow pixels untouched', () {
      final pixels = _pixel(1, 2, 3, 255);
      recolorNoseShadow(pixels, const RgbColor(9, 9, 9));
      expect(pixels, _pixel(1, 2, 3, 255));
    });
  });

  test('proportionalShadow scales each channel by the source ratio', () {
    final shadow = proportionalShadow(kSourceSkinBase);
    expect(shadow.r, kSourceSkinShadow.r);
    expect(shadow.g, kSourceSkinShadow.g);
    expect(shadow.b, kSourceSkinShadow.b);
  });

  test('resolveHairColor finds both natural and neon keys', () {
    expect(resolveHairColor('black'), kHairColors['black']);
    expect(resolveHairColor('limegreen'), kNeonHairColors['limegreen']);
    expect(resolveHairColor('not-a-color'), isNull);
  });
}
