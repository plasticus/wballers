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
}
