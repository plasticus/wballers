import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_appearance_json.dart';

void main() {
  test('round-trips a fully-populated coach appearance', () {
    const original = PortraitAppearance(
      version: 2,
      baseSprite: 'BlankBaldwoman32.png',
      skinTone: 'deep',
      hair: 'hair_afro',
      hairColor: 'black',
      topHairColor: 'limegreen',
      eyes: 'eyes_1center',
      eyebrows: 'eyebrow_1',
      nose: 'nose_1',
      mouth: 'mouth_1',
      accessories: 'goggles_1',
      isCoach: true,
      shoulders: 'shoulder_black',
      hat: 'hat_fedora',
      glasses: 'glasses_round',
      facial: 'facial_goat',
    );

    final restored = portraitAppearanceFromJson(
      portraitAppearanceToJson(original),
    );

    expect(restored.version, original.version);
    expect(restored.baseSprite, original.baseSprite);
    expect(restored.skinTone, original.skinTone);
    expect(restored.hair, original.hair);
    expect(restored.hairColor, original.hairColor);
    expect(restored.topHairColor, original.topHairColor);
    expect(restored.eyes, original.eyes);
    expect(restored.eyebrows, original.eyebrows);
    expect(restored.nose, original.nose);
    expect(restored.mouth, original.mouth);
    expect(restored.accessories, original.accessories);
    expect(restored.isCoach, original.isCoach);
    expect(restored.shoulders, original.shoulders);
    expect(restored.hat, original.hat);
    expect(restored.glasses, original.glasses);
    expect(restored.facial, original.facial);
  });

  test('round-trips a minimal athlete appearance with null optionals', () {
    const original = PortraitAppearance(
      baseSprite: 'BlankBaldwoman32.png',
      skinTone: 'pale',
      hairColor: 'blonde',
      eyes: 'eyes_1center',
      nose: 'nose_1',
      mouth: 'mouth_1',
      isCoach: false,
    );

    final restored = portraitAppearanceFromJson(
      portraitAppearanceToJson(original),
    );

    expect(restored.hair, isNull);
    expect(restored.topHairColor, isNull);
    expect(restored.eyebrows, isNull);
    expect(restored.accessories, isNull);
    expect(restored.facial, isNull);
    expect(restored.isCoach, isFalse);
  });
}
