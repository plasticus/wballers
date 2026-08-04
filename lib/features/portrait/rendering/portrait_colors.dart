/// An opaque RGB triple, independent of `dart:ui`'s [Color] so the pure
/// pixel-math in `pixel_recolor.dart` doesn't need a Flutter dependency.
class RgbColor {
  const RgbColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

/// Natural hair-color key -> hex (`render.js`'s `HAIR_COLORS`). Also used
/// to color eyebrows and (coach) facial hair.
const Map<String, RgbColor> kHairColors = {
  'black': RgbColor(0x1b, 0x1b, 0x1b),
  'darkbrown': RgbColor(0x3b, 0x24, 0x17),
  'brown': RgbColor(0x5a, 0x3a, 0x22),
  'lightbrown': RgbColor(0x8a, 0x5a, 0x34),
  'blonde': RgbColor(0xd9, 0xb8, 0x72),
  'auburn': RgbColor(0x7a, 0x33, 0x20),
  'red': RgbColor(0xa8, 0x43, 0x2a),
  'gray': RgbColor(0x8f, 0x8f, 0x8f),
  'white': RgbColor(0xe8, 0xe8, 0xe8),
};

/// Unlockable novelty top-hair colors (`render.js`'s `NEON_COLORS`) --
/// never randomly generated, see `portrait_generator.dart`.
const Map<String, RgbColor> kNeonHairColors = {
  'limegreen': RgbColor(0x39, 0xff, 0x14),
  'neonpink': RgbColor(0xff, 0x2f, 0xc2),
  'skyblue': RgbColor(0x00, 0xbf, 0xff),
  'fuchsia': RgbColor(0xc7, 0x24, 0xb1),
};

/// Resolves either a natural or neon color key (`render.js`'s
/// `ALL_HAIR_COLORS`).
RgbColor? resolveHairColor(String key) =>
    kHairColors[key] ?? kNeonHairColors[key];

/// Skin-tone key -> hex (`render.js`'s `SKIN_TONES`).
const Map<String, RgbColor> kSkinTones = {
  'pale': RgbColor(0xfa, 0xe0, 0xcb),
  'light': RgbColor(0xf1, 0xc2, 0x7d),
  'medium': RgbColor(0xc6, 0x90, 0x62),
  'deep': RgbColor(0x92, 0x61, 0x40),
  'chocolate': RgbColor(0x5e, 0x3c, 0x28),
};

/// The base sprite's source colors, exact-match replaced during
/// recoloring (`render.js`'s `SKIN_BASE`/`SKIN_SHADOW`/`SHIRT_BASE`).
const kSourceSkinBase = RgbColor(241, 194, 125);
const kSourceSkinShadow = RgbColor(188, 151, 98);
const kSourceShirtBase = RgbColor(29, 66, 138);

/// Parses a `#RRGGBB` hex string (`TeamColors.primaryHex`'s format) into an
/// [RgbColor], for jersey-collar recoloring.
RgbColor parseHexColor(String hex) {
  final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
  return RgbColor((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
}
