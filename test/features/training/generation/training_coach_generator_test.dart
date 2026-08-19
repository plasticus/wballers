import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/generation/name_pools_by_country.dart';
import 'package:womensbballmgr/features/training/generation/training_coach_generator.dart';

void main() {
  test('generates exactly 3 named training coaches', () {
    final coaches = generateTrainingCoaches(Random(1));
    expect(coaches, hasLength(3));
    for (final coach in coaches) {
      expect(coach.name, isNotEmpty);
    }
  });

  test('the same seed produces identical coaches', () {
    final a = generateTrainingCoaches(Random(4));
    final b = generateTrainingCoaches(Random(4));

    expect(a.map((c) => c.name), b.map((c) => c.name));
  });

  test('draws from the same given/surname pools players use, not a '
      'separate coach-only pool (2026-08-19, a direct GM catch: "I '
      'didn\'t know they had a different pool than players?! That\'s '
      'dumb. They should pull from the same pool")', () {
    final random = Random(23);
    for (var i = 0; i < 20; i++) {
      for (final coach in generateTrainingCoaches(random)) {
        final parts = coach.name.split(' ');
        final firstName = parts.first;
        final lastName = parts.skip(1).join(' ');
        expect(kAllGivenNames, contains(firstName), reason: coach.name);
        expect(kAllSurnames, contains(lastName), reason: coach.name);
      }
    }
  });
}
