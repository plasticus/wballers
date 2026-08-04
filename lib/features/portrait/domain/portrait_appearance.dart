/// Compact, persisted appearance data for one athlete's or coach's
/// portrait (`portraits.md`). The rendered PNG is derived, rebuildable data
/// -- never store it here, only what's needed to regenerate it.
///
/// Optional fields use `null` for "nothing selected" (mirrors `weights.json`'s
/// `none`/`natural` sentinel choices, translated at generation time so the
/// domain model itself never carries magic strings).
class PortraitAppearance {
  const PortraitAppearance({
    this.version = 1,
    required this.baseSprite,
    required this.skinTone,
    this.hair,
    required this.hairColor,
    this.topHairColor,
    required this.eyes,
    this.eyebrows,
    required this.nose,
    required this.mouth,
    this.accessories,
    required this.isCoach,
    this.shoulders,
    this.hat,
    this.glasses,
    this.facial,
  }) : assert(version > 0, 'version must be positive'),
       assert(baseSprite != '', 'baseSprite must not be empty'),
       assert(skinTone != '', 'skinTone must not be empty'),
       assert(hairColor != '', 'hairColor must not be empty'),
       assert(eyes != '', 'eyes must not be empty'),
       assert(nose != '', 'nose must not be empty'),
       assert(mouth != '', 'mouth must not be empty'),
       assert(
         isCoach ||
             (shoulders == null &&
                 hat == null &&
                 glasses == null &&
                 facial == null),
         'shoulders/hat/glasses/facial are coach-only',
       );

  /// Bumped whenever the renderer's output would change for the same
  /// appearance data (new base art, new recoloring rule, etc.), so a
  /// cached PNG can be invalidated without touching this data.
  final int version;

  final String baseSprite;

  /// A `PortraitWeights.skinTone` key (e.g. `medium`).
  final String skinTone;

  /// A `PortraitManifest.hair` filename without extension, or `null` for
  /// bald.
  final String? hair;

  /// A natural hair-color key (`PortraitWeights.hairColorByTone`'s values).
  /// Applied to eyebrows and (coach) facial hair; also to hair itself
  /// unless [topHairColor] overrides it.
  final String hairColor;

  /// An unlockable novelty color key, applied only to the top-hair layer.
  /// `null` uses [hairColor] there too.
  final String? topHairColor;

  final String eyes;

  /// A `PortraitManifest.eyebrows` filename without extension, or `null`.
  final String? eyebrows;

  final String nose;
  final String mouth;

  /// A `PortraitManifest.accessories` filename without extension, or
  /// `null`. At most one at a time, per the reference renderer.
  final String? accessories;

  /// Gates the coach-only fields below and the jersey-collar recolor
  /// (coaches don't wear a team jersey in the base sprite).
  final bool isCoach;

  final String? shoulders;
  final String? hat;
  final String? glasses;

  /// A `PortraitManifest.facial` filename without extension, or `null`.
  /// Never generated for athletes (`portraits.md`).
  final String? facial;
}
