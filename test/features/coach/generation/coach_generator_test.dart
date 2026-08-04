import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';
import 'package:womensbballmgr/features/coach/generation/coach_generator.dart';
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
}
