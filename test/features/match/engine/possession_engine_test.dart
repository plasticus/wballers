import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_event.dart';
import 'package:womensbballmgr/features/match/domain/possession_result.dart';
import 'package:womensbballmgr/features/match/engine/possession_engine.dart';
import 'package:womensbballmgr/features/matchup/domain/defensive_tactic.dart';
import 'package:womensbballmgr/features/matchup/domain/offense_shape.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';

import '../../../support/match_test_players.dart';

void main() {
  test('is deterministic for a given seed', () {
    final offense = testLineup('off');
    final defense = testLineup('def');

    final a = simulatePossession(
      Random(11),
      offense: offense,
      defense: defense,
    );
    final b = simulatePossession(
      Random(11),
      offense: offense,
      defense: defense,
    );

    expect(a.end, b.end);
    expect(a.pointsScored, b.pointsScored);
    expect(a.secondsElapsed, b.secondsElapsed);
    expect(a.events.length, b.events.length);
    for (var i = 0; i < a.events.length; i++) {
      expect(a.events[i].type, b.events[i].type);
    }
  });

  test('pointsScored is only nonzero when the possession ends in a score', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(5);

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: i.isEven,
      );
      if (result.end == PossessionEnd.scored) {
        expect(result.pointsScored, greaterThan(0));
      } else {
        expect(result.pointsScored, 0);
      }
    }
  });

  test('the last event in the log matches how the possession ended', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(9);
    const turnoverEndings = {
      MatchEventType.steal,
      MatchEventType.passRedirected,
      MatchEventType.passOutOfBounds,
      MatchEventType.shotClockViolation,
    };
    // A made basket plus a missed "and-1" free throw still ends in
    // freeThrowMissed as the last event, so scored and deadBallStop share
    // that possible last type -- what actually distinguishes them is
    // pointsScored, covered by the test above this one.
    const scoredEndings = {
      MatchEventType.shotMade,
      MatchEventType.freeThrowMade,
      MatchEventType.freeThrowMissed,
      MatchEventType.assist,
    };

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: i.isEven,
      );
      final lastType = result.events.last.type;
      switch (result.end) {
        case PossessionEnd.scored:
          expect(scoredEndings, contains(lastType));
        case PossessionEnd.defensiveRebound:
          expect(lastType, MatchEventType.defensiveRebound);
        case PossessionEnd.deadBallStop:
          expect(lastType, MatchEventType.freeThrowMissed);
        case PossessionEnd.turnover:
          expect(turnoverEndings, contains(lastType));
      }
    }
  });

  test('every possession terminates within a bounded amount of elapsed '
      'time', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(3);

    for (var i = 0; i < 1000; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
      );
      expect(result.secondsElapsed, greaterThan(0));
      expect(result.secondsElapsed, lessThan(200));
    }
  });

  test('a much stronger offense scores more often than a much weaker one '
      'against the same defense', () {
    final strongOffense = testLineup('strong', rating: 85);
    final weakOffense = testLineup('weak', rating: 25);
    final defense = testLineup('def', rating: 50);
    const sampleSize = 500;

    var strongScores = 0;
    final strongRandom = Random(1);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        strongRandom,
        offense: strongOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) strongScores++;
    }

    var weakScores = 0;
    final weakRandom = Random(1);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        weakRandom,
        offense: weakOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) weakScores++;
    }

    expect(strongScores, greaterThan(weakScores));
  });

  test('a non-shooting foul only produces free throws when the defense is '
      'in bonus', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(50);

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: false,
      );
      final hasNonShootingFoul = result.events.any(
        (e) => e.type == MatchEventType.nonShootingFoul,
      );
      final hasShootingFoul = result.events.any(
        (e) => e.type == MatchEventType.shootingFoul,
      );
      if (hasNonShootingFoul && !hasShootingFoul) {
        expect(
          result.events.any(
            (e) =>
                e.type == MatchEventType.freeThrowMade ||
                e.type == MatchEventType.freeThrowMissed,
          ),
          isFalse,
        );
      }
    }
  });

  test('a non-shooting foul sends the offense to the line when the defense '
      'is in bonus, and ends the possession there', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(51);
    var sawBonusFoul = false;

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: true,
      );
      final foulIndex = result.events.indexWhere(
        (e) => e.type == MatchEventType.nonShootingFoul,
      );
      if (foulIndex == -1) continue;
      sawBonusFoul = true;
      final rest = result.events.sublist(foulIndex + 1);
      expect(rest, isNotEmpty);
      expect(
        rest.every(
          (e) =>
              e.type == MatchEventType.freeThrowMade ||
              e.type == MatchEventType.freeThrowMissed,
        ),
        isTrue,
      );
    }

    expect(sawBonusFoul, isTrue);
  });

  test('a shooting foul always sends the shooter to the line', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(52);
    var sawShootingFoul = false;

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
      );
      final foulIndex = result.events.indexWhere(
        (e) => e.type == MatchEventType.shootingFoul,
      );
      if (foulIndex == -1) continue;
      sawShootingFoul = true;
      final rest = result.events.sublist(foulIndex + 1);
      expect(rest, isNotEmpty);
      expect(
        rest.every(
          (e) =>
              e.type == MatchEventType.freeThrowMade ||
              e.type == MatchEventType.freeThrowMissed,
        ),
        isTrue,
      );
    }

    expect(sawShootingFoul, isTrue);
  });

  test('an assist always immediately follows the shotMade it credits, and '
      'names the previous ball handler', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(60);
    var sawAssist = false;

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
      );
      for (var j = 0; j < result.events.length; j++) {
        if (result.events[j].type != MatchEventType.assist) continue;
        sawAssist = true;
        final assistEvent = result.events[j];
        final priorEvent = result.events[j - 1];
        expect(priorEvent.type, MatchEventType.shotMade);
        // The scorer credited on the assist matches who actually scored.
        expect(assistEvent.secondPlayer, priorEvent.player);
        // The assisting passer is a teammate, not the scorer themself.
        expect(assistEvent.player, isNot(assistEvent.secondPlayer));
        expect(offense, contains(assistEvent.player));
      }
    }

    expect(sawAssist, isTrue);
  });

  test('a made shot with no preceding clean pass has no assist', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(61);
    var sawUnassistedScore = false;

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
      );
      for (var j = 0; j < result.events.length; j++) {
        if (result.events[j].type != MatchEventType.shotMade) continue;
        final isLast = j == result.events.length - 1;
        final nextIsAssist =
            !isLast && result.events[j + 1].type == MatchEventType.assist;
        if (!nextIsAssist) sawUnassistedScore = true;
      }
    }

    // Not every made shot follows a pass (some follow an offensive
    // rebound, or a possession that opened straight into a shot) -- there
    // should be a real mix, not every score wired up to an assist.
    expect(sawUnassistedScore, isTrue);
  });

  test('a block is only ever attributed on a miss, immediately before the '
      'rebound', () {
    final offense = testLineup('off');
    final defense = testLineup('def');
    final random = Random(62);
    var sawBlock = false;

    for (var i = 0; i < 500; i++) {
      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
      );
      for (var j = 0; j < result.events.length; j++) {
        if (result.events[j].type != MatchEventType.shotBlocked) continue;
        sawBlock = true;
        expect(result.events[j - 1].type, MatchEventType.shotMissed);
        final nextType = result.events[j + 1].type;
        expect(
          nextType,
          anyOf(
            MatchEventType.offensiveRebound,
            MatchEventType.defensiveRebound,
          ),
        );
        expect(defense, contains(result.events[j].player));
      }
    }

    expect(sawBlock, isTrue);
  });

  test('throws when a lineup does not have exactly 5 players', () {
    final offense = testLineup('off').take(4).toList();
    final defense = testLineup('def');

    expect(
      () => simulatePossession(Random(1), offense: offense, defense: defense),
      throwsA(isA<AssertionError>()),
    );
  });

  test('offenseMargin at or above kBlowoutPaceMargin makes possessions run '
      'longer overall (TODO.md item 5: blowout pace rubber-banding)', () {
    final offense = testLineup('off');
    final defense = testLineup('def');

    var totalNormal = 0.0;
    var totalProtecting = 0.0;
    const sampleSize = 200;
    for (var seed = 0; seed < sampleSize; seed++) {
      // Same seed for both, so the only thing that can differ between
      // the pair is the pacing bonus itself, not the underlying rolls.
      final normal = simulatePossession(
        Random(seed),
        offense: offense,
        defense: defense,
      );
      final protecting = simulatePossession(
        Random(seed),
        offense: offense,
        defense: defense,
        offenseMargin: kBlowoutPaceMargin,
      );
      totalNormal += normal.secondsElapsed;
      totalProtecting += protecting.secondsElapsed;
    }

    expect(totalProtecting, greaterThan(totalNormal));
  });

  test('offenseMargin just below kBlowoutPaceMargin has no pacing effect at '
      'all -- identical to a plain possession, action for action', () {
    final offense = testLineup('off');
    final defense = testLineup('def');

    final normal = simulatePossession(
      Random(11),
      offense: offense,
      defense: defense,
    );
    final almostProtecting = simulatePossession(
      Random(11),
      offense: offense,
      defense: defense,
      offenseMargin: kBlowoutPaceMargin - 1,
    );

    expect(almostProtecting.secondsElapsed, normal.secondsElapsed);
    expect(almostProtecting.pointsScored, normal.pointsScored);
  });

  group('effectiveHomeAwayRating (TODO.md item 11: home team advantage)', () {
    test('a home player with no traits gets the flat kHomeAdvantageBonus '
        'bump', () {
      final player = testPlayer(id: 'p', rating: 50);
      expect(effectiveHomeAwayRating(player, 50, true), 51); // 50 * 1.025
    });

    test('an away player with no traits is completely unchanged', () {
      final player = testPlayer(id: 'p', rating: 50);
      expect(effectiveHomeAwayRating(player, 50, false), 50);
    });

    test('Home Court Hero stacks on top of the base home bump, only at '
        'home', () {
      final hero = testPlayer(
        id: 'p',
        rating: 50,
        traits: {Trait.homeCourtHero},
      );
      // 50 * (1 + 0.025 + 0.05) = 53.75 -> rounds to 54.
      expect(effectiveHomeAwayRating(hero, 50, true), 54);
      // On the road, Home Court Hero does nothing at all.
      expect(effectiveHomeAwayRating(hero, 50, false), 50);
    });

    test('Road Warrior only helps on the road, independent of the home '
        'bump', () {
      final warrior = testPlayer(
        id: 'p',
        rating: 50,
        traits: {Trait.roadWarrior},
      );
      // 50 * 1.05 = 52.5 -> rounds to 53.
      expect(effectiveHomeAwayRating(warrior, 50, false), 53);
      // At home, Road Warrior does nothing -- only the flat home bump
      // applies, same as a player with no trait at all.
      expect(effectiveHomeAwayRating(warrior, 50, true), 51);
    });

    test('never boosts a rating past kMaxRating', () {
      final hero = testPlayer(
        id: 'p',
        rating: 99,
        traits: {Trait.homeCourtHero},
      );
      expect(effectiveHomeAwayRating(hero, 99, true), 99);
    });

    test('bonus (e.g. the coach matchup bonus) stacks on top of the '
        'home/trait bonuses (TODO.md coach-stats item)', () {
      final player = testPlayer(id: 'p', rating: 50);
      // 50 * (1 + 0.025 + 0.02) = 52.25 -> rounds to 52.
      expect(effectiveHomeAwayRating(player, 50, true, bonus: 0.02), 52);
      // Away, no traits: only the bonus applies.
      // 50 * 1.02 = 51.
      expect(effectiveHomeAwayRating(player, 50, false, bonus: 0.02), 51);
      // A negative bonus (e.g. the defending coach won the matchup)
      // actually reduces the effective rating.
      // 50 * 0.98 = 49.
      expect(effectiveHomeAwayRating(player, 50, false, bonus: -0.02), 49);
    });
  });

  group('coachMatchupBonus (TODO.md coach-stats item -- a direct GM ask)', () {
    test('is zero when both coaches are equal on the relevant stat', () {
      expect(
        coachMatchupBonus(offenseCoachOffense: 65, defenseCoachDefense: 65),
        0.0,
      );
    });

    test('a 20-point gap lands at a clean 2%, the GM\'s own worked '
        'example', () {
      expect(
        coachMatchupBonus(offenseCoachOffense: 65, defenseCoachDefense: 45),
        closeTo(0.02, 0.0001),
      );
    });

    test('is negative, not just zero, when the defending coach wins the '
        'matchup', () {
      expect(
        coachMatchupBonus(offenseCoachOffense: 45, defenseCoachDefense: 65),
        closeTo(-0.02, 0.0001),
      );
    });

    test('clamps at kCoachMatchupBonusCap for an extreme gap, in either '
        'direction', () {
      expect(
        coachMatchupBonus(offenseCoachOffense: 99, defenseCoachDefense: 1),
        kCoachMatchupBonusCap,
      );
      expect(
        coachMatchupBonus(offenseCoachOffense: 1, defenseCoachDefense: 99),
        -kCoachMatchupBonusCap,
      );
    });

    test('reaches exactly the cap at a 50-point gap, no further', () {
      expect(
        coachMatchupBonus(offenseCoachOffense: 90, defenseCoachDefense: 40),
        kCoachMatchupBonusCap,
      );
    });
  });

  test('an offense with a favorable coach matchup scores more often than '
      'an identical offense with no coach bonus at all (TODO.md coach-'
      'stats item)', () {
    final boostedOffense = testLineup('boosted', rating: 50);
    final plainOffense = testLineup('plain', rating: 50);
    final defense = testLineup('def', rating: 50);
    const sampleSize = 50000;

    var boostedScores = 0;
    final boostedRandom = Random(3);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        boostedRandom,
        offense: boostedOffense,
        defense: defense,
        offenseCoachBonus: kCoachMatchupBonusCap,
      );
      if (result.end == PossessionEnd.scored) boostedScores++;
    }

    var plainScores = 0;
    final plainRandom = Random(3);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        plainRandom,
        offense: plainOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) plainScores++;
    }

    expect(boostedScores, greaterThan(plainScores));
  });

  test('a home offense scores more often than an identical away offense '
      'against the same unboosted defense (TODO.md item 11)', () {
    final homeOffense = testLineup('home', rating: 50);
    final awayOffense = testLineup('away', rating: 50);
    final defense = testLineup('def', rating: 50);
    // kHomeAdvantageBonus is a *flat* 2.5% bump, which barely moves the
    // odds of any single roll -- the base case (no trait) needs a large
    // sample to separate from noise reliably (empirically ~0.8 points of
    // scoring rate at this rating, verified via a throwaway diagnostic
    // script before picking this sample size -- 200k keeps the expected
    // gap several standard errors clear of a false negative).
    const sampleSize = 200000;

    var homeScores = 0;
    final homeRandom = Random(1);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        homeRandom,
        offense: homeOffense,
        defense: defense,
        offenseIsHome: true,
      );
      if (result.end == PossessionEnd.scored) homeScores++;
    }

    var awayScores = 0;
    final awayRandom = Random(1);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        awayRandom,
        offense: awayOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) awayScores++;
    }

    expect(homeScores, greaterThan(awayScores));
  });

  test('a Home Court Hero-stacked home offense scores even more often than '
      'a plain home offense (TODO.md item 11)', () {
    final heroOffense = testLineup(
      'hero',
      rating: 50,
      traits: {Trait.homeCourtHero},
    );
    final plainOffense = testLineup('plain', rating: 50);
    final defense = testLineup('def', rating: 50);
    // The extra 5% (on top of the flat 2.5% both offenses already get)
    // is a bigger gap than the base test above, so a smaller sample
    // still separates cleanly from noise.
    const sampleSize = 50000;

    var heroScores = 0;
    final heroRandom = Random(2);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        heroRandom,
        offense: heroOffense,
        defense: defense,
        offenseIsHome: true,
      );
      if (result.end == PossessionEnd.scored) heroScores++;
    }

    var plainScores = 0;
    final plainRandom = Random(2);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        plainRandom,
        offense: plainOffense,
        defense: defense,
        offenseIsHome: true,
      );
      if (result.end == PossessionEnd.scored) plainScores++;
    }

    expect(heroScores, greaterThan(plainScores));
  });

  test('a Road Warrior-stacked away offense scores more often than a plain '
      'away offense (TODO.md item 11)', () {
    final warriorOffense = testLineup(
      'warrior',
      rating: 50,
      traits: {Trait.roadWarrior},
    );
    final plainOffense = testLineup('plain', rating: 50);
    final defense = testLineup('def', rating: 50);
    const sampleSize = 50000;

    var warriorScores = 0;
    final warriorRandom = Random(3);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        warriorRandom,
        offense: warriorOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) warriorScores++;
    }

    var plainScores = 0;
    final plainRandom = Random(3);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulatePossession(
        plainRandom,
        offense: plainOffense,
        defense: defense,
      );
      if (result.end == PossessionEnd.scored) plainScores++;
    }

    expect(warriorScores, greaterThan(plainScores));
  });

  group('offenseBonus/defenseBonus (2026-08-14, offense shape + defensive '
      'tactic -- a direct GM ask)', () {
    const noOffenseBonus = (interior: 0.0, perimeter: 0.0, passing: 0.0);
    const noDefenseBonus = (
      interior: 0.0,
      perimeter: 0.0,
      disruption: 0.0,
      targetedBonus: 0.0,
      spreadThinPenalty: 0.0,
    );

    test('a Post-Up-boosted offense (interior up) scores more often than '
        'an identical offense with no shape bonus', () {
      final boostedOffense = testLineup('boosted', rating: 50);
      final plainOffense = testLineup('plain', rating: 50);
      final defense = testLineup('def', rating: 50);
      const sampleSize = 50000;
      final boostedBonus = offenseBonusFor(OffenseShape.postUp);

      var boostedScores = 0;
      final boostedRandom = Random(7);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          boostedRandom,
          offense: boostedOffense,
          defense: defense,
          offenseBonus: boostedBonus,
        );
        if (result.end == PossessionEnd.scored) boostedScores++;
      }

      var plainScores = 0;
      final plainRandom = Random(7);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          plainRandom,
          offense: plainOffense,
          defense: defense,
          offenseBonus: noOffenseBonus,
        );
        if (result.end == PossessionEnd.scored) plainScores++;
      }

      expect(boostedScores, greaterThan(plainScores));
    });

    test('a Pack-the-Paint defense (interior up) holds the offense to a '
        'lower scoring rate than an identical defense with no tactic '
        'bonus', () {
      final offense = testLineup('off', rating: 50);
      final boostedDefense = testLineup('boosted-def', rating: 50);
      final plainDefense = testLineup('plain-def', rating: 50);
      const sampleSize = 50000;
      final packThePaint = defenseBonusFor(DefensiveTactic.packThePaint);

      var scoresVsBoosted = 0;
      final boostedRandom = Random(9);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          boostedRandom,
          offense: offense,
          defense: boostedDefense,
          defenseBonus: packThePaint,
        );
        if (result.end == PossessionEnd.scored) scoresVsBoosted++;
      }

      var scoresVsPlain = 0;
      final plainRandom = Random(9);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          plainRandom,
          offense: offense,
          defense: plainDefense,
          defenseBonus: noDefenseBonus,
        );
        if (result.end == PossessionEnd.scored) scoresVsPlain++;
      }

      expect(scoresVsBoosted, lessThan(scoresVsPlain));
    });

    test("Motion's small passing bonus reduces the turnover rate compared "
        'to an identical offense with no shape bonus', () {
      final boostedOffense = testLineup('boosted', rating: 50);
      final plainOffense = testLineup('plain', rating: 50);
      final defense = testLineup('def', rating: 50);
      const sampleSize = 50000;
      final motion = offenseBonusFor(OffenseShape.motion);

      var boostedTurnovers = 0;
      final boostedRandom = Random(13);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          boostedRandom,
          offense: boostedOffense,
          defense: defense,
          offenseBonus: motion,
        );
        if (result.end == PossessionEnd.turnover) boostedTurnovers++;
      }

      var plainTurnovers = 0;
      final plainRandom = Random(13);
      for (var i = 0; i < sampleSize; i++) {
        final result = simulatePossession(
          plainRandom,
          offense: plainOffense,
          defense: defense,
          offenseBonus: noOffenseBonus,
        );
        if (result.end == PossessionEnd.turnover) plainTurnovers++;
      }

      expect(boostedTurnovers, lessThan(plainTurnovers));
    });

    test('Face-Guard the Star specifically suppresses the flagged '
        "player's own shot-make rate -- not just a blanket team effect", () {
      // A 5th "star" player, id `star`, alongside 4 identical teammates --
      // `simulatePossession` picks a random ball handler each call, so
      // over a large sample every player (including the star) attempts a
      // comparable number of shots regardless of whether she's targeted;
      // only her *make rate conditional on attempting* should move.
      final offense = [
        testPlayer(id: 'star', rating: 50),
        ...List.generate(4, (i) => testPlayer(id: 'mate-$i', rating: 50)),
      ];
      final defense = testLineup('def', rating: 50);
      const sampleSize = 80000;
      final faceGuard = defenseBonusFor(DefensiveTactic.faceGuardStar);

      (int made, int attempts) tallyStarShots({required String? targetId}) {
        var made = 0;
        var attempts = 0;
        final random = Random(21);
        for (var i = 0; i < sampleSize; i++) {
          final result = simulatePossession(
            random,
            offense: offense,
            defense: defense,
            defenseBonus: faceGuard,
            defenseTargetPlayerId: targetId,
          );
          for (final event in result.events) {
            if (event.player?.id != 'star') continue;
            if (event.type == MatchEventType.shotMade) {
              made++;
              attempts++;
            } else if (event.type == MatchEventType.shotMissed) {
              attempts++;
            }
          }
        }
        return (made, attempts);
      }

      final targeted = tallyStarShots(targetId: 'star');
      final untargeted = tallyStarShots(targetId: null);

      final targetedRate = targeted.$1 / targeted.$2;
      final untargetedRate = untargeted.$1 / untargeted.$2;

      expect(targetedRate, lessThan(untargetedRate));
    });
  });
}
