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

  /// A stable, content-based fingerprint of every field that actually
  /// changes the rendered pixels -- [version] and [isCoach] deliberately
  /// excluded, since neither is data the portrait editor lets the GM
  /// change (version tracks the *renderer's* own revisions; isCoach is
  /// fixed for a given owner). Used as part of the portrait cache key
  /// (`portrait_service.dart`'s `portraitCacheKey`) so a real edit -- a
  /// different hair style, a different skin tone, anything -- always
  /// misses whatever PNG was cached for the *previous* look, instead of
  /// silently reusing it. A real bug this exact gap caused (2026-08-18, a
  /// direct GM report: "when I edit my coach's look, it doesn't seem
  /// like it sticks... only saves on that editor page, never shows up
  /// in actual usage"): the cache key used to be keyed on [version] and
  /// the owner id alone, both of which stay identical across an edit --
  /// every other screen kept reading the same cache entry the editor's
  /// own preview had already moved past.
  String get contentFingerprint => [
    baseSprite,
    skinTone,
    hair,
    hairColor,
    topHairColor,
    eyes,
    eyebrows,
    nose,
    mouth,
    accessories,
    shoulders,
    hat,
    glasses,
    facial,
  ].join('|');

  /// Returns a copy with the given fields replaced. Nullable fields
  /// distinguish "leave unchanged" (the parameter's default,
  /// [_unsetSentinel]) from "explicitly set to null" (an actual `null`
  /// argument) -- the portrait editor needs both, e.g. picking a new hair
  /// style vs. picking "Bald".
  PortraitAppearance copyWith({
    int? version,
    String? baseSprite,
    String? skinTone,
    Object? hair = _unsetSentinel,
    String? hairColor,
    Object? topHairColor = _unsetSentinel,
    String? eyes,
    Object? eyebrows = _unsetSentinel,
    String? nose,
    String? mouth,
    Object? accessories = _unsetSentinel,
    bool? isCoach,
    Object? shoulders = _unsetSentinel,
    Object? hat = _unsetSentinel,
    Object? glasses = _unsetSentinel,
    Object? facial = _unsetSentinel,
  }) {
    return PortraitAppearance(
      version: version ?? this.version,
      baseSprite: baseSprite ?? this.baseSprite,
      skinTone: skinTone ?? this.skinTone,
      hair: identical(hair, _unsetSentinel) ? this.hair : hair as String?,
      hairColor: hairColor ?? this.hairColor,
      topHairColor: identical(topHairColor, _unsetSentinel)
          ? this.topHairColor
          : topHairColor as String?,
      eyes: eyes ?? this.eyes,
      eyebrows: identical(eyebrows, _unsetSentinel)
          ? this.eyebrows
          : eyebrows as String?,
      nose: nose ?? this.nose,
      mouth: mouth ?? this.mouth,
      accessories: identical(accessories, _unsetSentinel)
          ? this.accessories
          : accessories as String?,
      isCoach: isCoach ?? this.isCoach,
      shoulders: identical(shoulders, _unsetSentinel)
          ? this.shoulders
          : shoulders as String?,
      hat: identical(hat, _unsetSentinel) ? this.hat : hat as String?,
      glasses: identical(glasses, _unsetSentinel)
          ? this.glasses
          : glasses as String?,
      facial: identical(facial, _unsetSentinel)
          ? this.facial
          : facial as String?,
    );
  }
}

const Object _unsetSentinel = Object();
