import 'dart:typed_data';

import 'portrait_colors.dart';

/// The proportional shadow-tone calculation `render.js` applies whenever a
/// base/shadow color pair gets retargeted -- keeps the shadow's relative
/// darkness consistent across skin tones instead of using one fixed shadow.
RgbColor proportionalShadow(RgbColor targetBase) {
  return RgbColor(
    (targetBase.r * kSourceSkinShadow.r / kSourceSkinBase.r).round(),
    (targetBase.g * kSourceSkinShadow.g / kSourceSkinBase.g).round(),
    (targetBase.b * kSourceSkinShadow.b / kSourceSkinBase.b).round(),
  );
}

/// Recolors magenta-placeholder pixels in [pixels] (RGBA, row-major,
/// straight alpha) to [target], preserving each pixel's brightness via its
/// red-channel value -- mirrors `render.js`'s `getRecoloredMagenta`.
/// Mutates [pixels] in place.
///
/// A pixel is a placeholder when it's non-transparent, its red and blue
/// channels are equal, and its green channel is at most 5 (any brightness
/// of magenta, not just pure #ff00ff).
void recolorMagentaPlaceholder(Uint8List pixels, RgbColor target) {
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a == 0) continue;
    if (r == b && g <= 5 && r > 0) {
      final factor = r / 255;
      pixels[i] = (target.r * factor).round();
      pixels[i + 1] = (target.g * factor).round();
      pixels[i + 2] = (target.b * factor).round();
    }
  }
}

/// Recolors the base sprite's skin (and proportional shadow), and, if
/// [jersey] is given, its shirt collar, via exact source-color matching --
/// mirrors `render.js`'s `getRecoloredBase`. Mutates [pixels] in place.
void recolorBaseSprite(
  Uint8List pixels, {
  required RgbColor skin,
  RgbColor? jersey,
}) {
  final shadow = proportionalShadow(skin);
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    if (r == kSourceSkinBase.r &&
        g == kSourceSkinBase.g &&
        b == kSourceSkinBase.b) {
      pixels[i] = skin.r;
      pixels[i + 1] = skin.g;
      pixels[i + 2] = skin.b;
    } else if (r == kSourceSkinShadow.r &&
        g == kSourceSkinShadow.g &&
        b == kSourceSkinShadow.b) {
      pixels[i] = shadow.r;
      pixels[i + 1] = shadow.g;
      pixels[i + 2] = shadow.b;
    } else if (jersey != null &&
        r == kSourceShirtBase.r &&
        g == kSourceShirtBase.g &&
        b == kSourceShirtBase.b) {
      pixels[i] = jersey.r;
      pixels[i + 1] = jersey.g;
      pixels[i + 2] = jersey.b;
    }
  }
}

/// Recolors the nose asset's shadow pixels to match [skin]'s proportional
/// shadow -- mirrors `render.js`'s `getRecoloredNose`. Mutates [pixels] in
/// place.
void recolorNoseShadow(Uint8List pixels, RgbColor skin) {
  final shadow = proportionalShadow(skin);
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a == 0) continue;
    if (r == kSourceSkinShadow.r &&
        g == kSourceSkinShadow.g &&
        b == kSourceSkinShadow.b) {
      pixels[i] = shadow.r;
      pixels[i + 1] = shadow.g;
      pixels[i + 2] = shadow.b;
    }
  }
}
