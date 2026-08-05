import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_event.dart';
import 'package:womensbballmgr/features/match/domain/possession_result.dart';
import 'package:womensbballmgr/features/match/engine/possession_engine.dart';

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
}
