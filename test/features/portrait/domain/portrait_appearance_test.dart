import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';

PortraitAppearance _athlete({
  String? shoulders,
  String? hat,
  String? glasses,
  String? facial,
}) {
  return PortraitAppearance(
    baseSprite: 'BlankBaldwoman32.png',
    skinTone: 'medium',
    hairColor: 'black',
    eyes: 'eyes_1center',
    nose: 'nose_1',
    mouth: 'mouth_1',
    isCoach: false,
    shoulders: shoulders,
    hat: hat,
    glasses: glasses,
    facial: facial,
  );
}

void main() {
  test('defaults version to 1 and optional fields to null', () {
    final appearance = _athlete();

    expect(appearance.version, 1);
    expect(appearance.hair, isNull);
    expect(appearance.topHairColor, isNull);
    expect(appearance.eyebrows, isNull);
    expect(appearance.accessories, isNull);
  });

  test('rejects coach-only fields on a non-coach appearance', () {
    expect(
      () => _athlete(shoulders: 'shoulder_black'),
      throwsA(isA<AssertionError>()),
    );
    expect(() => _athlete(hat: 'hat_fedora'), throwsA(isA<AssertionError>()));
    expect(
      () => _athlete(glasses: 'glasses_round'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => _athlete(facial: 'facial_goat'),
      throwsA(isA<AssertionError>()),
    );
  });

  test('allows coach-only fields when isCoach is true', () {
    final coach = PortraitAppearance(
      baseSprite: 'BlankBaldwoman32.png',
      skinTone: 'medium',
      hairColor: 'black',
      eyes: 'eyes_1center',
      nose: 'nose_1',
      mouth: 'mouth_1',
      isCoach: true,
      shoulders: 'shoulder_black',
      hat: 'hat_fedora',
      glasses: 'glasses_round',
      facial: 'facial_goat',
    );

    expect(coach.shoulders, 'shoulder_black');
    expect(coach.hat, 'hat_fedora');
    expect(coach.glasses, 'glasses_round');
    expect(coach.facial, 'facial_goat');
  });

  group('copyWith', () {
    test('leaves every field unchanged when nothing is passed', () {
      final original = _athlete();
      final copy = original.copyWith();

      expect(copy.version, original.version);
      expect(copy.skinTone, original.skinTone);
      expect(copy.hairColor, original.hairColor);
      expect(copy.hair, original.hair);
    });

    test('updates a non-nullable field without disturbing others', () {
      final original = _athlete();
      final copy = original.copyWith(skinTone: 'deep');

      expect(copy.skinTone, 'deep');
      expect(copy.hairColor, original.hairColor);
      expect(copy.eyes, original.eyes);
    });

    test('setting a nullable field to a value works', () {
      final original = _athlete();
      final copy = original.copyWith(hair: 'hair_afro');

      expect(copy.hair, 'hair_afro');
    });

    test('explicitly clearing a nullable field to null works', () {
      final withHair = _athlete().copyWith(hair: 'hair_afro');
      final bald = withHair.copyWith(hair: null);

      expect(withHair.hair, 'hair_afro');
      expect(bald.hair, isNull);
    });

    test('omitting a nullable field preserves its existing value', () {
      final withHair = _athlete().copyWith(hair: 'hair_afro');
      final stillHasHair = withHair.copyWith(skinTone: 'deep');

      expect(stillHasHair.hair, 'hair_afro');
    });
  });
}
