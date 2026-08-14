import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/matchup/domain/defensive_tactic.dart';

void main() {
  group('defenseBonusFor', () {
    test('balanced is the zero-everywhere baseline', () {
      final bonus = defenseBonusFor(DefensiveTactic.balanced);
      expect(bonus.interior, 0.0);
      expect(bonus.perimeter, 0.0);
      expect(bonus.disruption, 0.0);
      expect(bonus.targetedBonus, 0.0);
      expect(bonus.spreadThinPenalty, 0.0);
    });

    test('pack the paint trades perimeter defense for interior defense, '
        'no targeting', () {
      final bonus = defenseBonusFor(DefensiveTactic.packThePaint);
      expect(bonus.interior, greaterThan(0));
      expect(bonus.perimeter, lessThan(0));
      expect(bonus.targetedBonus, 0.0);
      expect(bonus.spreadThinPenalty, 0.0);
    });

    test('extend & pressure trades interior defense for perimeter '
        'defense and disruption, no targeting', () {
      final bonus = defenseBonusFor(DefensiveTactic.extendAndPressure);
      expect(bonus.interior, lessThan(0));
      expect(bonus.perimeter, greaterThan(0));
      expect(bonus.disruption, greaterThan(0));
      expect(bonus.targetedBonus, 0.0);
      expect(bonus.spreadThinPenalty, 0.0);
    });

    test('face-guard the star only ever touches targeting, never the '
        'blanket team-wide fields', () {
      final bonus = defenseBonusFor(DefensiveTactic.faceGuardStar);
      expect(bonus.interior, 0.0);
      expect(bonus.perimeter, 0.0);
      expect(bonus.disruption, 0.0);
      expect(bonus.targetedBonus, greaterThan(0));
      expect(bonus.spreadThinPenalty, lessThan(0));
    });

    test('every bonus stays comfortably under the coach-bonus scale '
        '(+/-5%) except the deliberately larger targeted bonus', () {
      for (final tactic in DefensiveTactic.values) {
        final bonus = defenseBonusFor(tactic);
        for (final value in [
          bonus.interior,
          bonus.perimeter,
          bonus.disruption,
          bonus.spreadThinPenalty,
        ]) {
          expect(value.abs(), lessThan(0.05));
        }
      }
      // The one deliberate exception -- Face-Guard the Star concentrates
      // a real bonus, at a real cost elsewhere.
      expect(
        defenseBonusFor(DefensiveTactic.faceGuardStar).targetedBonus,
        0.09,
      );
    });
  });

  group('DefensiveTacticInfo', () {
    test('every tactic has a non-empty label and shorthand', () {
      for (final tactic in DefensiveTactic.values) {
        expect(tactic.label, isNotEmpty);
        expect(tactic.shorthand, isNotEmpty);
      }
    });

    test('labels are all distinct', () {
      final labels = DefensiveTactic.values.map((t) => t.label).toSet();
      expect(labels, hasLength(DefensiveTactic.values.length));
    });
  });
}
