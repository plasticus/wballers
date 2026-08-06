import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/generation/coach_generator.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_manifest.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';

final _portraitManifest = PortraitManifest(
  hair: const ['hair_afro.png'],
  eyes: const ['eyes_1center.png'],
  eyebrows: const ['eyebrow_1.png'],
  nose: const ['nose_1.png'],
  mouth: const ['mouth_1.png'],
  facial: const ['facial_goat.png'],
  accessories: const ['goggles_1.png'],
  shoulders: const ['shoulder_black.png', 'shoulder_grey.png'],
  hats: const ['hat_fedora.png'],
  glasses: const ['glasses_round.png'],
);

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
  facial: const {'facial_goat': 1},
  accessories: const {'none': 1},
);

void main() {
  test('the same seed produces an identical coach', () {
    final a = generateCoach(Random(9));
    final b = generateCoach(Random(9));

    expect(a.name, b.name);
    expect(a.stats.offense, b.stats.offense);
    expect(a.stats.management, b.stats.management);
    expect(a.archetype, b.archetype);
  });

  test('different seeds usually produce different coaches', () {
    final a = generateCoach(Random(1));
    final b = generateCoach(Random(2));

    expect(a.name != b.name || a.stats.overall != b.stats.overall, isTrue);
  });

  test('every stat stays within the 1-99 scale', () {
    final random = Random(7);
    for (var i = 0; i < 100; i++) {
      final coach = generateCoach(random, qualityCenter: 90, qualitySpread: 30);
      for (final value in [
        coach.stats.offense,
        coach.stats.defense,
        coach.stats.development,
        coach.stats.motivation,
        coach.stats.management,
      ]) {
        expect(value, greaterThanOrEqualTo(kMinRating));
        expect(value, lessThanOrEqualTo(kMaxRating));
      }
    }
  });

  test('is not always CoachStats.neutral -- stats actually vary', () {
    final random = Random(3);
    var sawVariance = false;
    for (var i = 0; i < 20; i++) {
      final coach = generateCoach(random);
      if (coach.stats.offense != 50) {
        sawVariance = true;
        break;
      }
    }
    expect(sawVariance, isTrue);
  });

  test('an Offensive Innovator ends up with higher offense than a '
      'Defensive Mastermind, on average', () {
    const sampleSize = 1000;
    final random = Random(11);

    var innovatorTotal = 0;
    var innovatorCount = 0;
    var mastermindTotal = 0;
    var mastermindCount = 0;
    for (var i = 0; i < sampleSize; i++) {
      final coach = generateCoach(random);
      if (coach.archetype == CoachArchetype.offensiveInnovator) {
        innovatorTotal += coach.stats.offense;
        innovatorCount++;
      } else if (coach.archetype == CoachArchetype.defensiveMastermind) {
        mastermindTotal += coach.stats.offense;
        mastermindCount++;
      }
    }

    expect(innovatorCount, greaterThan(0));
    expect(mastermindCount, greaterThan(0));
    expect(
      innovatorTotal / innovatorCount,
      greaterThan(mastermindTotal / mastermindCount),
    );
  });

  test('a Talent Developer ends up with higher development than a '
      'Program Builder, on average', () {
    const sampleSize = 1000;
    final random = Random(13);

    var developerTotal = 0;
    var developerCount = 0;
    var builderTotal = 0;
    var builderCount = 0;
    for (var i = 0; i < sampleSize; i++) {
      final coach = generateCoach(random);
      if (coach.archetype == CoachArchetype.talentDeveloper) {
        developerTotal += coach.stats.development;
        developerCount++;
      } else if (coach.archetype == CoachArchetype.programBuilder) {
        builderTotal += coach.stats.development;
        builderCount++;
      }
    }

    expect(developerCount, greaterThan(0));
    expect(builderCount, greaterThan(0));
    expect(
      developerTotal / developerCount,
      greaterThan(builderTotal / builderCount),
    );
  });

  test('appearance stays null when portraitWeights is omitted', () {
    expect(generateCoach(Random(9)).appearance, isNull);
  });

  test(
    'appearance is generated with isCoach true when portraitWeights is given',
    () {
      final coach = generateCoach(Random(9), portraitWeights: _portraitWeights);
      expect(coach.appearance, isNotNull);
      expect(coach.appearance!.isCoach, isTrue);
    },
  );

  test('shoulders stay null when portraitManifest is omitted', () {
    final coach = generateCoach(Random(9), portraitWeights: _portraitWeights);
    expect(coach.appearance!.shoulders, isNull);
  });

  test(
    'gets shoulders when both portraitWeights and portraitManifest are given',
    () {
      final coach = generateCoach(
        Random(9),
        portraitWeights: _portraitWeights,
        portraitManifest: _portraitManifest,
      );
      expect(coach.appearance!.shoulders, isNotNull);
    },
  );

  test('an explicit archetype overrides the random roll', () {
    final random = Random(21);
    for (var i = 0; i < 30; i++) {
      final coach = generateCoach(random, archetype: CoachArchetype.steadyHand);
      expect(coach.archetype, CoachArchetype.steadyHand);
    }
  });

  group('generateCoachCandidates', () {
    test('returns the requested count, each with a distinct archetype', () {
      final candidates = generateCoachCandidates(Random(1));
      expect(candidates, hasLength(3));
      expect(candidates.map((c) => c.archetype).toSet(), hasLength(3));
    });

    test('the same seed produces identical candidates', () {
      final a = generateCoachCandidates(Random(42));
      final b = generateCoachCandidates(Random(42));

      expect(a.map((c) => c.archetype), b.map((c) => c.archetype));
      expect(a.map((c) => c.name), b.map((c) => c.name));
      expect(a.map((c) => c.stats.overall), b.map((c) => c.stats.overall));
    });

    test('honors a smaller requested count', () {
      final candidates = generateCoachCandidates(Random(5), count: 2);
      expect(candidates, hasLength(2));
      expect(candidates.map((c) => c.archetype).toSet(), hasLength(2));
    });
  });
}
