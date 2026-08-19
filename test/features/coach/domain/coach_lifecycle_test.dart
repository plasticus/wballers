import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_lifecycle.dart';

void main() {
  group('coachSkillTotalForAge', () {
    test('is 250 at entry age (45) -- the GM\'s own worked example', () {
      expect(coachSkillTotalForAge(45), 250);
    });

    test('is 350 at retirement age (65) -- the GM\'s own worked example', () {
      expect(coachSkillTotalForAge(65), 350);
    });

    test('matches "49 to 51 -> 270 to 280" exactly, the GM\'s own '
        'worked example that confirmed kCoachInitialLeagueMinAge/MaxAge '
        'means age, not OVR', () {
      expect(coachSkillTotalForAge(49), 270);
      expect(coachSkillTotalForAge(51), 280);
    });

    test('grows by exactly 5 per year of age (1 per stat x 5 stats)', () {
      expect(coachSkillTotalForAge(50) - coachSkillTotalForAge(49), 5);
    });
  });

  group('coachHasReachedMandatoryRetirement', () {
    test('false through the final active season (65)', () {
      expect(coachHasReachedMandatoryRetirement(65), isFalse);
    });

    test('true starting at 66', () {
      expect(coachHasReachedMandatoryRetirement(66), isTrue);
    });

    test('true for anyone older too', () {
      expect(coachHasReachedMandatoryRetirement(70), isTrue);
    });
  });

  test('kCoachMandatoryRetirementAge is exactly one season past '
      'kCoachRetirementAge', () {
    expect(kCoachMandatoryRetirementAge, kCoachRetirementAge + 1);
  });
}
