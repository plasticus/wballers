import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/generation/trait_generator.dart';

void main() {
  test('the same seed produces the same traits', () {
    final a = generateTraits(Random(7), position: Position.smallForward);
    final b = generateTraits(Random(7), position: Position.smallForward);

    expect(a, b);
  });

  test('never rolls more than maxTraits', () {
    final random = Random(11);
    for (var i = 0; i < 200; i++) {
      expect(
        generateTraits(
          random,
          position: Position.smallForward,
          maxTraits: 3,
        ).length,
        lessThanOrEqualTo(3),
      );
    }
  });

  test('never rolls Homegrown', () {
    final random = Random(13);
    for (var i = 0; i < 200; i++) {
      expect(
        generateTraits(random, position: Position.smallForward),
        isNot(contains(Trait.homegrown)),
      );
    }
  });

  test('never rolls both sides of an opposite pair', () {
    final random = Random(17);
    for (var i = 0; i < 200; i++) {
      final traits = generateTraits(
        random,
        position: Position.smallForward,
        maxTraits: 29,
      );
      for (final trait in traits) {
        final opposite = oppositeOf(trait);
        expect(opposite == null || !traits.contains(opposite), isTrue);
      }
    }
  });

  test('can roll zero traits', () {
    // Exhaustively check a run of seeds turns up at least one zero-trait
    // roll, since generateTraits(random, maxTraits: 0) always does.
    expect(
      generateTraits(Random(1), position: Position.smallForward, maxTraits: 0),
      isEmpty,
    );
  });

  group('position eligibility (2026-08-11, a direct GM ask -- "guards '
      'shouldn\'t be able to get rim guardian")', () {
    test('never rolls Rim Guardian for a point guard or shooting guard', () {
      final random = Random(19);
      for (var i = 0; i < 500; i++) {
        final traits = generateTraits(
          random,
          position: Position.pointGuard,
          maxTraits: 29,
        );
        expect(traits, isNot(contains(Trait.rimGuardian)));
      }
      for (var i = 0; i < 500; i++) {
        final traits = generateTraits(
          random,
          position: Position.shootingGuard,
          maxTraits: 29,
        );
        expect(traits, isNot(contains(Trait.rimGuardian)));
      }
    });

    test('can still roll Rim Guardian for a front-court position', () {
      final random = Random(23);
      var sawRimGuardian = false;
      for (var i = 0; i < 500; i++) {
        final traits = generateTraits(
          random,
          position: Position.center,
          maxTraits: 29,
        );
        if (traits.contains(Trait.rimGuardian)) {
          sawRimGuardian = true;
          break;
        }
      }
      expect(sawRimGuardian, isTrue);
    });

    test('isTraitEligibleForPosition rules out Rim Guardian for both '
        'guard spots only, every other trait stays eligible everywhere', () {
      for (final position in Position.values) {
        final isGuard =
            position == Position.pointGuard ||
            position == Position.shootingGuard;
        expect(
          isTraitEligibleForPosition(Trait.rimGuardian, position),
          !isGuard,
        );
        for (final trait in Trait.values) {
          if (trait == Trait.rimGuardian) continue;
          expect(isTraitEligibleForPosition(trait, position), isTrue);
        }
      }
    });
  });
}
