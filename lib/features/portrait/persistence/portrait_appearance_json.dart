import '../domain/portrait_appearance.dart';

Map<String, dynamic> portraitAppearanceToJson(PortraitAppearance appearance) {
  return {
    'version': appearance.version,
    'baseSprite': appearance.baseSprite,
    'skinTone': appearance.skinTone,
    'hair': appearance.hair,
    'hairColor': appearance.hairColor,
    'topHairColor': appearance.topHairColor,
    'eyes': appearance.eyes,
    'eyebrows': appearance.eyebrows,
    'nose': appearance.nose,
    'mouth': appearance.mouth,
    'accessories': appearance.accessories,
    'isCoach': appearance.isCoach,
    'shoulders': appearance.shoulders,
    'hat': appearance.hat,
    'glasses': appearance.glasses,
    'facial': appearance.facial,
  };
}

PortraitAppearance portraitAppearanceFromJson(Map<String, dynamic> json) {
  return PortraitAppearance(
    version: json['version'] as int,
    baseSprite: json['baseSprite'] as String,
    skinTone: json['skinTone'] as String,
    hair: json['hair'] as String?,
    hairColor: json['hairColor'] as String,
    topHairColor: json['topHairColor'] as String?,
    eyes: json['eyes'] as String,
    eyebrows: json['eyebrows'] as String?,
    nose: json['nose'] as String,
    mouth: json['mouth'] as String,
    accessories: json['accessories'] as String?,
    isCoach: json['isCoach'] as bool,
    shoulders: json['shoulders'] as String?,
    hat: json['hat'] as String?,
    glasses: json['glasses'] as String?,
    facial: json['facial'] as String?,
  );
}
