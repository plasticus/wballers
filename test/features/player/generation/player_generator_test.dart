import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/generation/player_generator.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';

final _portraitWeights = PortraitWeights(
  skinTone: const {'medium': 1},
  hairColorByTone: const {
    'medium': {'black': 1},
  },
  hair: const {'hair_afro': 1},
  neonHair: const {'natural': 1},
  eyes: const {'eyes_1center': 1},
  nose: const {'nose_1': 1},
  mouth: const {'mouth_1': 1},
  eyebrows: const {'eyebrow_1': 1},
  facial: const {'none': 1},
  accessories: const {'none': 1},
);

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
    expect(a.archetype, b.archetype);
    expect(a.traits, b.traits);
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

  test('every generated player has an archetype valid for their position and '
      'no opposite-pair traits, at most 3 traits, never Homegrown', () {
    final random = Random(2024);
    for (var i = 0; i < 200; i++) {
      final position = Position.values[i % Position.values.length];
      final player = generatePlayer(random, primaryPosition: position);

      expect(kArchetypesByPosition[position], contains(player.archetype));
      expect(player.traits.length, lessThanOrEqualTo(3));
      expect(player.traits, isNot(contains(Trait.homegrown)));
      for (final trait in player.traits) {
        final opposite = oppositeOf(trait);
        expect(opposite == null || !player.traits.contains(opposite), isTrue);
      }
    }
  });

  test('appearance stays null when portraitWeights is omitted', () {
    final player = generatePlayer(Random(1), primaryPosition: Position.center);
    expect(player.appearance, isNull);
  });

  test('appearance is generated (non-coach) when portraitWeights is given', () {
    final player = generatePlayer(
      Random(1),
      primaryPosition: Position.center,
      portraitWeights: _portraitWeights,
    );
    expect(player.appearance, isNotNull);
    expect(player.appearance!.isCoach, isFalse);
  });

  test('omitting portraitWeights consumes no extra random numbers', () {
    // Same seed, same non-portrait fields, whether or not portraitWeights
    // is passed -- proves the appearance roll is fully additive, not
    // interleaved with the rest of generation.
    final withoutWeights = generatePlayer(
      Random(55),
      primaryPosition: Position.pointGuard,
    );
    final withWeights = generatePlayer(
      Random(55),
      primaryPosition: Position.pointGuard,
      portraitWeights: _portraitWeights,
    );
    expect(withWeights.name, withoutWeights.name);
    expect(withWeights.ratings.overall, withoutWeights.ratings.overall);
    expect(withWeights.archetype, withoutWeights.archetype);
    expect(withWeights.traits, withoutWeights.traits);
  });
}
