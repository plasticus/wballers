import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/generation/player_generator.dart';

void main() {
  test('the same seed produces an identical player', () {
    final a = generatePlayer(Random(7), primaryPosition: Position.center);
    final b = generatePlayer(Random(7), primaryPosition: Position.center);

    expect(a.name, b.name);
    expect(a.age, b.age);
    expect(a.yearsOfService, b.yearsOfService);
    expect(a.hometown, b.hometown);
    expect(a.handedness, b.handedness);
    expect(a.ratings.speed, b.ratings.speed);
    expect(a.ratings.strength, b.ratings.strength);
    expect(a.ratings.potential, b.ratings.potential);
  });

  test('different seeds usually produce different players', () {
    final a = generatePlayer(Random(1), primaryPosition: Position.center);
    final b = generatePlayer(Random(2), primaryPosition: Position.center);

    expect(a.name != b.name || a.ratings.overall != b.ratings.overall, isTrue);
  });

  test('every generated rating stays within the 1-99 scale', () {
    final random = Random(99);
    for (var i = 0; i < 200; i++) {
      final player = generatePlayer(
        random,
        primaryPosition: Position.values[i % Position.values.length],
        qualityCenter: 90, // pushed toward the edge on purpose
        qualitySpread: 30,
      );
      final r = player.ratings;
      for (final value in [
        r.speed,
        r.agility,
        r.strength,
        r.stamina,
        r.ballControl,
        r.passing,
        r.interiorOffense,
        r.perimeterOffense,
        r.perimeterDefense,
        r.interiorDefense,
        r.disruption,
        r.blocking,
        r.potential,
      ]) {
        expect(value, greaterThanOrEqualTo(kMinRating));
        expect(value, lessThanOrEqualTo(kMaxRating));
      }
    }
  });

  test('yearsOfService is consistent with age (debut no earlier than 19)', () {
    final random = Random(123);
    for (var i = 0; i < 100; i++) {
      final player = generatePlayer(
        random,
        primaryPosition: Position.pointGuard,
      );
      expect(player.yearsOfService, greaterThanOrEqualTo(0));
      expect(player.yearsOfService, lessThanOrEqualTo(player.age - 19));
    }
  });

  test('centers skew stronger and slower than point guards on average', () {
    const sampleSize = 300;
    final random = Random(42);

    var centerStrengthTotal = 0;
    var centerSpeedTotal = 0;
    for (var i = 0; i < sampleSize; i++) {
      final p = generatePlayer(random, primaryPosition: Position.center);
      centerStrengthTotal += p.ratings.strength;
      centerSpeedTotal += p.ratings.speed;
    }

    var guardStrengthTotal = 0;
    var guardSpeedTotal = 0;
    for (var i = 0; i < sampleSize; i++) {
      final p = generatePlayer(random, primaryPosition: Position.pointGuard);
      guardStrengthTotal += p.ratings.strength;
      guardSpeedTotal += p.ratings.speed;
    }

    expect(
      centerStrengthTotal / sampleSize,
      greaterThan(guardStrengthTotal / sampleSize),
    );
    expect(
      centerSpeedTotal / sampleSize,
      lessThan(guardSpeedTotal / sampleSize),
    );
  });
}
