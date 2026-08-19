import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';
import 'package:womensbballmgr/features/match/engine/fatigue.dart';
import 'package:womensbballmgr/features/matchup/domain/coaching_option.dart';

import '../../../support/match_test_players.dart';

void main() {
  group('CoachingOptionInfo', () {
    test('every option has a non-empty label and shorthand', () {
      for (final option in CoachingOption.values) {
        expect(option.label, isNotEmpty);
        expect(option.shorthand, isNotEmpty);
      }
    });

    test('labels are all distinct', () {
      final labels = CoachingOption.values.map((o) => o.label).toSet();
      expect(labels, hasLength(CoachingOption.values.length));
    });
  });

  group('coachingBonusFor', () {
    test('null resolves to no effect', () {
      expect(coachingBonusFor(null), kNoCoachingOptionBonus);
    });

    test('every option nets more pro than con -- the whole point of this '
        'catalog standing in for a morale mechanic', () {
      // Fire the Team Up / Rest a Player are instant actions, not a
      // continuous bonus -- they correctly resolve to "no effect" here
      // and are exercised separately below.
      final continuous = CoachingOption.values.where(
        (o) =>
            o != CoachingOption.fireTheTeamUp &&
            o != CoachingOption.restAPlayer,
      );
      for (final option in continuous) {
        final bonus = coachingBonusFor(option);
        final pros =
            [
              bonus.offenseBonus,
              bonus.defenseBonus,
              bonus.disruptionBonus,
              bonus.reboundingBonus,
            ].where((v) => v > 0).length +
            (bonus.staminaDrainMultiplier < 1.0 ? 1 : 0);
        final cons =
            [
              bonus.offenseBonus,
              bonus.defenseBonus,
              bonus.perimeterDefenseBonus,
            ].where((v) => v < 0).length +
            (bonus.staminaDrainMultiplier > 1.0 ? 1 : 0);
        expect(
          pros,
          greaterThanOrEqualTo(cons),
          reason: '${option.label} has more downside than upside',
        );
      }
    });

    test('focus defense/offense are mirror-image tradeoffs', () {
      final defense = coachingBonusFor(CoachingOption.focusDefense);
      expect(defense.defenseBonus, 0.05);
      expect(defense.offenseBonus, -0.025);

      final offense = coachingBonusFor(CoachingOption.focusOffense);
      expect(offense.offenseBonus, 0.05);
      expect(offense.defenseBonus, -0.025);
    });

    test('full-court press: defense up, no downside on offense, but '
        'burns more stamina and slows only the opponent', () {
      final bonus = coachingBonusFor(CoachingOption.fullCourtPress);
      expect(bonus.defenseBonus, greaterThan(0));
      expect(bonus.offenseBonus, 0.0);
      expect(bonus.staminaDrainMultiplier, greaterThan(1.0));
      expect(bonus.opponentPaceSecondsBonus, greaterThan(0.0));
      expect(bonus.ownPaceSecondsBonus, 0.0);
    });

    test('park the bus slows both sides equally, no rating change at all', () {
      final bonus = coachingBonusFor(CoachingOption.parkTheBus);
      expect(bonus.ownPaceSecondsBonus, greaterThan(0.0));
      expect(bonus.opponentPaceSecondsBonus, bonus.ownPaceSecondsBonus);
      expect(bonus.offenseBonus, 0.0);
      expect(bonus.defenseBonus, 0.0);
      expect(bonus.staminaDrainMultiplier, 1.0);
    });

    test('pace yourself slows both sides and eases stamina drain', () {
      final bonus = coachingBonusFor(CoachingOption.paceYourself);
      expect(bonus.ownPaceSecondsBonus, greaterThan(0.0));
      expect(bonus.opponentPaceSecondsBonus, bonus.ownPaceSecondsBonus);
      expect(bonus.staminaDrainMultiplier, lessThan(1.0));
    });

    test('pick up the pace speeds only its own offense, at a stamina '
        'cost, with a disruption bump', () {
      final bonus = coachingBonusFor(CoachingOption.pickUpThePace);
      expect(bonus.ownPaceSecondsBonus, lessThan(0.0));
      expect(bonus.opponentPaceSecondsBonus, 0.0);
      expect(bonus.staminaDrainMultiplier, greaterThan(1.0));
      expect(bonus.disruptionBonus, greaterThan(0.0));
    });

    test('attack the boards: rebounding up, perimeter defense down, '
        'nothing else touched', () {
      final bonus = coachingBonusFor(CoachingOption.attackTheBoards);
      expect(bonus.reboundingBonus, greaterThan(0.0));
      expect(bonus.perimeterDefenseBonus, lessThan(0.0));
      expect(bonus.offenseBonus, 0.0);
      expect(bonus.defenseBonus, 0.0);
    });

    test('stop the bleeding: defense up, genuinely no downside anywhere', () {
      final bonus = coachingBonusFor(CoachingOption.stopTheBleeding);
      expect(bonus.defenseBonus, greaterThan(0.0));
      expect(bonus.offenseBonus, 0.0);
      expect(bonus.perimeterDefenseBonus, 0.0);
      expect(bonus.staminaDrainMultiplier, 1.0);
    });

    test('fire the team up / rest a player are instant actions -- no '
        'continuous bonus', () {
      expect(
        coachingBonusFor(CoachingOption.fireTheTeamUp),
        kNoCoachingOptionBonus,
      );
      expect(
        coachingBonusFor(CoachingOption.restAPlayer),
        kNoCoachingOptionBonus,
      );
    });

    test('every magnitude stays at or under the engine-wide 5% bonus '
        'scale', () {
      for (final option in CoachingOption.values) {
        final bonus = coachingBonusFor(option);
        for (final value in [
          bonus.offenseBonus,
          bonus.defenseBonus,
          bonus.disruptionBonus,
          bonus.perimeterDefenseBonus,
          bonus.reboundingBonus,
        ]) {
          expect(value.abs(), lessThanOrEqualTo(0.05));
        }
      }
    });
  });

  group('motivationBonusMultiplier', () {
    test('the rating scale midpoint (50) is exactly 1.0x -- "the coach '
        'has 50 motivation, they just get the standard bonuses"', () {
      expect(motivationBonusMultiplier(50), 1.0);
    });

    test('the min/max ends land on the locked 0.25x/1.75x range '
        '(2026-08-19, a direct GM ask)', () {
      expect(
        motivationBonusMultiplier(kMinRating),
        kMotivationBonusMultiplierAtMin,
      );
      expect(
        motivationBonusMultiplier(kMaxRating),
        kMotivationBonusMultiplierAtMax,
      );
    });

    test('never reaches or exceeds 2.0x -- "I don\'t want it to ever '
        'double the bonus"', () {
      for (
        var motivation = kMinRating;
        motivation <= kMaxRating;
        motivation++
      ) {
        expect(motivationBonusMultiplier(motivation), lessThan(2.0));
      }
    });

    test('never goes negative, even at the very bottom of the scale', () {
      expect(motivationBonusMultiplier(kMinRating), greaterThan(0.0));
    });

    test('monotonically increasing with motivation', () {
      var previous = motivationBonusMultiplier(kMinRating);
      for (
        var motivation = kMinRating + 1;
        motivation <= kMaxRating;
        motivation++
      ) {
        final current = motivationBonusMultiplier(motivation);
        expect(current, greaterThan(previous));
        previous = current;
      }
    });
  });

  group('applyMotivationToCoachingBonus', () {
    test('a 1.0x multiplier (Motivation 50) leaves every field '
        'unchanged', () {
      final bonus = coachingBonusFor(CoachingOption.focusDefense);
      expect(applyMotivationToCoachingBonus(bonus, 1.0), bonus);
    });

    test('scales the 5 rating-percentage fields, both the pro and con '
        'side of a tradeoff', () {
      final bonus = coachingBonusFor(CoachingOption.focusDefense);
      final scaled = applyMotivationToCoachingBonus(bonus, 1.75);
      expect(scaled.defenseBonus, closeTo(0.0875, 1e-9)); // 0.05 * 1.75
      expect(scaled.offenseBonus, closeTo(-0.04375, 1e-9)); // -0.025 * 1.75
    });

    test('leaves pace-seconds and stamina-multiplier fields untouched -- '
        'out of scope for this pass', () {
      final bonus = coachingBonusFor(CoachingOption.fullCourtPress);
      final scaled = applyMotivationToCoachingBonus(bonus, 1.75);
      expect(scaled.opponentPaceSecondsBonus, bonus.opponentPaceSecondsBonus);
      expect(scaled.ownPaceSecondsBonus, bonus.ownPaceSecondsBonus);
      expect(scaled.staminaDrainMultiplier, bonus.staminaDrainMultiplier);
    });

    test('a below-50 multiplier shrinks the bonus toward zero without '
        'ever flipping its sign', () {
      final bonus = coachingBonusFor(CoachingOption.attackTheBoards);
      final scaled = applyMotivationToCoachingBonus(bonus, 0.25);
      expect(scaled.reboundingBonus, greaterThan(0.0));
      expect(scaled.reboundingBonus, lessThan(bonus.reboundingBonus));
      expect(scaled.perimeterDefenseBonus, lessThan(0.0));
      expect(
        scaled.perimeterDefenseBonus,
        greaterThan(bonus.perimeterDefenseBonus),
      );
    });
  });

  group('applyFireTheTeamUp', () {
    test('bumps every roster player by the flat boost', () {
      final roster = testRoster('team');
      final energy = {for (final p in roster) p: 50.0};
      final result = applyFireTheTeamUp(energy, roster);
      for (final p in roster) {
        expect(result[p], 50.0 + kFireTheTeamUpEnergyBoost);
      }
    });

    test('clamps at the energy ceiling rather than overshooting', () {
      final roster = testRoster('team');
      final energy = {for (final p in roster) p: kMaxEnergy - 1};
      final result = applyFireTheTeamUp(energy, roster);
      for (final p in roster) {
        expect(result[p], kMaxEnergy);
      }
    });

    test('does not mutate the input map', () {
      final roster = testRoster('team');
      final energy = {for (final p in roster) p: 50.0};
      applyFireTheTeamUp(energy, roster);
      for (final p in roster) {
        expect(energy[p], 50.0);
      }
    });
  });

  group('pickPlayerToRest', () {
    test('picks whoever has the lowest energy among onCourt', () {
      final lineup = testLineup('home');
      final energy = {
        for (var i = 0; i < lineup.length; i++) lineup[i]: 80.0 - i * 10,
      };
      expect(pickPlayerToRest(energy, lineup), lineup.last);
    });

    test('a player missing from the energy map reads as full energy, '
        'never picked over an actually-tracked low player', () {
      final lineup = testLineup('home');
      final energy = {lineup.first: 10.0};
      expect(pickPlayerToRest(energy, lineup), lineup.first);
    });

    test('null for an empty on-court list', () {
      expect(pickPlayerToRest(const {}, const []), isNull);
    });
  });

  group('offerCoachingOptions', () {
    test('offers exactly 3 options when nothing special is eligible', () {
      final random = Random(1);
      final offered = offerCoachingOptions(
        random,
        stoppage: CoachingBreakStoppage.firstHalf,
        opponentUnansweredRun: 0,
      );
      expect(offered, hasLength(3));
      expect(offered.toSet(), hasLength(3)); // no duplicates
    });

    test('stop the bleeding is guaranteed a slot once the run threshold '
        'is hit', () {
      for (var seed = 0; seed < 20; seed++) {
        final offered = offerCoachingOptions(
          Random(seed),
          stoppage: CoachingBreakStoppage.firstHalf,
          opponentUnansweredRun: kStopTheBleedingRunThreshold,
        );
        expect(offered, contains(CoachingOption.stopTheBleeding));
        expect(offered, hasLength(3));
      }
    });

    test('stop the bleeding never appears below the run threshold', () {
      for (var seed = 0; seed < 50; seed++) {
        final offered = offerCoachingOptions(
          Random(seed),
          stoppage: CoachingBreakStoppage.secondHalf,
          opponentUnansweredRun: kStopTheBleedingRunThreshold - 1,
        );
        expect(offered, isNot(contains(CoachingOption.stopTheBleeding)));
      }
    });

    test('park the bus never appears at a first-half break', () {
      for (var seed = 0; seed < 50; seed++) {
        final offered = offerCoachingOptions(
          Random(seed),
          stoppage: CoachingBreakStoppage.firstHalf,
          opponentUnansweredRun: 0,
        );
        expect(offered, isNot(contains(CoachingOption.parkTheBus)));
      }
    });

    test('park the bus can appear at a second-half break', () {
      final seenParkTheBus = List.generate(200, (seed) {
        final offered = offerCoachingOptions(
          Random(seed),
          stoppage: CoachingBreakStoppage.secondHalf,
          opponentUnansweredRun: 0,
        );
        return offered.contains(CoachingOption.parkTheBus);
      });
      expect(seenParkTheBus, contains(true));
    });
  });
}
