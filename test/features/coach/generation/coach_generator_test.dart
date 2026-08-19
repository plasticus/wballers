import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_lifecycle.dart';
import 'package:womensbballmgr/features/coach/generation/coach_generator.dart';
import 'package:womensbballmgr/features/player/generation/name_pools_by_country.dart';
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

Coach _coach(
  Random random, {
  int minAge = 44,
  int maxAge = 65,
  CoachArchetype? archetype,
}) {
  return generateCoach(
    random,
    minAge: minAge,
    maxAge: maxAge,
    archetype: archetype,
  );
}

void main() {
  test('the same seed produces an identical coach', () {
    final a = _coach(Random(9));
    final b = _coach(Random(9));

    expect(a.name, b.name);
    expect(a.age, b.age);
    expect(a.stats.offense, b.stats.offense);
    expect(a.stats.management, b.stats.management);
    expect(a.archetype, b.archetype);
  });

  test('different seeds usually produce different coaches', () {
    final a = _coach(Random(1));
    final b = _coach(Random(2));

    expect(a.name != b.name || a.stats.overall != b.stats.overall, isTrue);
  });

  test('age always falls within the given minAge-maxAge band', () {
    final random = Random(7);
    for (var i = 0; i < 100; i++) {
      final coach = _coach(random, minAge: 44, maxAge: 46);
      expect(coach.age, inInclusiveRange(44, 46));
    }
  });

  test('every stat lands within kCoachMinStat-kCoachMaxStat, at every age '
      'from entry to retirement', () {
    final random = Random(3);
    for (var age = kCoachEntryAge; age <= kCoachRetirementAge; age++) {
      for (var i = 0; i < 20; i++) {
        final coach = _coach(random, minAge: age, maxAge: age);
        for (final value in [
          coach.stats.offense,
          coach.stats.defense,
          coach.stats.development,
          coach.stats.motivation,
          coach.stats.management,
        ]) {
          expect(
            value,
            greaterThanOrEqualTo(kCoachMinStat),
            reason: 'age $age',
          );
          expect(value, lessThanOrEqualTo(kCoachMaxStat), reason: 'age $age');
        }
      }
    }
  });

  test('skillTotal always exactly matches coachSkillTotalForAge(age) -- the '
      'distribution algorithm hits the target total exactly, not just '
      'approximately', () {
    final random = Random(5);
    for (var age = kCoachEntryAge; age <= kCoachRetirementAge; age++) {
      for (var i = 0; i < 10; i++) {
        final coach = _coach(random, minAge: age, maxAge: age);
        expect(
          coach.stats.skillTotal,
          coachSkillTotalForAge(age),
          reason: 'age $age',
        );
      }
    }
  });

  test('repeated generation at a fixed age still produces real variance '
      'in how the total is distributed across stats', () {
    final random = Random(3);
    final firstOffense = _coach(random, minAge: 60, maxAge: 60).stats.offense;
    var sawVariance = false;
    for (var i = 0; i < 20; i++) {
      final coach = _coach(random, minAge: 60, maxAge: 60);
      if (coach.stats.offense != firstOffense) {
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
      final coach = _coach(
        random,
        archetype: i.isEven
            ? CoachArchetype.offensiveInnovator
            : CoachArchetype.defensiveMastermind,
      );
      if (coach.archetype == CoachArchetype.offensiveInnovator) {
        innovatorTotal += coach.stats.offense;
        innovatorCount++;
      } else {
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
      final coach = _coach(
        random,
        archetype: i.isEven
            ? CoachArchetype.talentDeveloper
            : CoachArchetype.programBuilder,
      );
      if (coach.archetype == CoachArchetype.talentDeveloper) {
        developerTotal += coach.stats.development;
        developerCount++;
      } else {
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
    expect(_coach(Random(9)).appearance, isNull);
  });

  test(
    'appearance is generated with isCoach true when portraitWeights is given',
    () {
      final coach = generateCoach(
        Random(9),
        minAge: 44,
        maxAge: 65,
        portraitWeights: _portraitWeights,
      );
      expect(coach.appearance, isNotNull);
      expect(coach.appearance!.isCoach, isTrue);
    },
  );

  test('shoulders stay null when portraitManifest is omitted', () {
    final coach = generateCoach(
      Random(9),
      minAge: 44,
      maxAge: 65,
      portraitWeights: _portraitWeights,
    );
    expect(coach.appearance!.shoulders, isNull);
  });

  test(
    'gets shoulders when both portraitWeights and portraitManifest are given',
    () {
      final coach = generateCoach(
        Random(9),
        minAge: 44,
        maxAge: 65,
        portraitWeights: _portraitWeights,
        portraitManifest: _portraitManifest,
      );
      expect(coach.appearance!.shoulders, isNotNull);
    },
  );

  test('draws from the same given/surname pools players use, not a '
      'separate coach-only pool (2026-08-19, a direct GM catch: "I didn\'t '
      'know they had a different pool than players?! That\'s dumb. They '
      'should pull from the same pool")', () {
    final random = Random(17);
    for (var i = 0; i < 50; i++) {
      final coach = _coach(random);
      final parts = coach.name.split(' ');
      final firstName = parts.first;
      final lastName = parts.skip(1).join(' ');
      expect(kAllGivenNames, contains(firstName), reason: coach.name);
      expect(kAllSurnames, contains(lastName), reason: coach.name);
    }
  });

  test('an explicit archetype overrides the random roll', () {
    final random = Random(21);
    for (var i = 0; i < 30; i++) {
      final coach = _coach(random, archetype: CoachArchetype.steadyHand);
      expect(coach.archetype, CoachArchetype.steadyHand);
    }
  });

  group('generateCoachCandidates', () {
    test('returns the requested count, each with a distinct archetype', () {
      final candidates = generateCoachCandidates(
        Random(1),
        minAge: 44,
        maxAge: 46,
      );
      expect(candidates, hasLength(3));
      expect(candidates.map((c) => c.archetype).toSet(), hasLength(3));
    });

    test('the same seed produces identical candidates', () {
      final a = generateCoachCandidates(Random(42), minAge: 44, maxAge: 46);
      final b = generateCoachCandidates(Random(42), minAge: 44, maxAge: 46);

      expect(a.map((c) => c.archetype), b.map((c) => c.archetype));
      expect(a.map((c) => c.name), b.map((c) => c.name));
      expect(a.map((c) => c.stats.overall), b.map((c) => c.stats.overall));
    });

    test('honors a smaller requested count', () {
      final candidates = generateCoachCandidates(
        Random(5),
        count: 2,
        minAge: 44,
        maxAge: 46,
      );
      expect(candidates, hasLength(2));
      expect(candidates.map((c) => c.archetype).toSet(), hasLength(2));
    });

    test('a count larger than the number of real archetypes still returns '
        'exactly that many candidates, cycling archetypes rather than '
        'running out (2026-08-19, needed for AvailableHeadCoachesScreen\'s '
        '10-candidate pool -- only 8 archetypes exist)', () {
      final candidates = generateCoachCandidates(
        Random(9),
        count: 10,
        minAge: 44,
        maxAge: 46,
      );
      expect(candidates, hasLength(10));
    });

    test('every candidate\'s age falls within the given band', () {
      final candidates = generateCoachCandidates(
        Random(9),
        count: 10,
        minAge: 44,
        maxAge: 46,
      );
      for (final candidate in candidates) {
        expect(candidate.age, inInclusiveRange(44, 46));
      }
    });
  });

  group('growCoach', () {
    test('ages by exactly 1 and grows every stat by 1, unless a stat is '
        'already at the ceiling', () {
      final coach = _coach(Random(1), minAge: 50, maxAge: 50);
      final grown = growCoach(coach);

      int expectedGrowth(int stat) => stat >= kCoachMaxStat ? stat : stat + 1;

      expect(grown.age, coach.age + 1);
      expect(grown.stats.offense, expectedGrowth(coach.stats.offense));
      expect(grown.stats.defense, expectedGrowth(coach.stats.defense));
      expect(grown.stats.development, expectedGrowth(coach.stats.development));
      expect(grown.stats.motivation, expectedGrowth(coach.stats.motivation));
      expect(grown.stats.management, expectedGrowth(coach.stats.management));
    });

    test('never grows a stat past kCoachMaxStat', () {
      final coach = _coach(Random(1), minAge: 50, maxAge: 50);
      var grown = coach;
      // Grow well past retirement -- every stat should pile up against
      // the ceiling, never exceed it.
      for (var i = 0; i < 40; i++) {
        grown = growCoach(grown);
      }
      for (final value in [
        grown.stats.offense,
        grown.stats.defense,
        grown.stats.development,
        grown.stats.motivation,
        grown.stats.management,
      ]) {
        expect(value, lessThanOrEqualTo(kCoachMaxStat));
      }
    });

    test('name, archetype, and appearance are untouched by growth', () {
      final coach = generateCoach(
        Random(1),
        minAge: 50,
        maxAge: 50,
        portraitWeights: _portraitWeights,
      );
      final grown = growCoach(coach);

      expect(grown.name, coach.name);
      expect(grown.archetype, coach.archetype);
      expect(grown.appearance, coach.appearance);
    });
  });
}
