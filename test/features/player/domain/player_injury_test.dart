import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player_injury.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';

void main() {
  group('InjurySeverityRules', () {
    test('ratingPenalty/baseDurationGames match 0B_Planned.md\'s table', () {
      expect(InjurySeverity.minor.ratingPenalty, -0.10);
      expect(InjurySeverity.minor.baseDurationGames, 2);
      expect(InjurySeverity.moderate.ratingPenalty, -0.25);
      expect(InjurySeverity.moderate.baseDurationGames, 4);
      expect(InjurySeverity.major.ratingPenalty, -0.50);
      expect(InjurySeverity.major.baseDurationGames, 6);
    });

    test('oneTierMilder steps down, and is null past minor', () {
      expect(InjurySeverity.major.oneTierMilder, InjurySeverity.moderate);
      expect(InjurySeverity.moderate.oneTierMilder, InjurySeverity.minor);
      expect(InjurySeverity.minor.oneTierMilder, isNull);
    });
  });

  group('PlayerInjury.recoverAfterGame', () {
    test('the exact 0B_Planned.md worked example: a major injury, benched '
        'twice, then played out at minor', () {
      // "a player suffers a C-level [major] injury in Game 0... The GM
      // benches them for Game 1 -> drops to B [moderate] (25%, 4 games).
      // Benches again for Game 2 -> drops to A [minor] (10%, 2 games). GM
      // decides to play them starting Game 3 -- they play Games 3 and 4 at
      // a 10% stat penalty, and are back to 100% for Game 5."
      var injury = PlayerInjury.fresh(InjurySeverity.major);
      expect(injury.severity, InjurySeverity.major);
      expect(injury.gamesRemainingAtSeverity, 6);

      // Game 1: benched.
      injury = injury.recoverAfterGame(playedRealMinutes: false)!;
      expect(injury.severity, InjurySeverity.moderate);
      expect(injury.gamesRemainingAtSeverity, 4);

      // Game 2: benched again.
      injury = injury.recoverAfterGame(playedRealMinutes: false)!;
      expect(injury.severity, InjurySeverity.minor);
      expect(injury.gamesRemainingAtSeverity, 2);

      // Game 3: plays through it.
      injury = injury.recoverAfterGame(playedRealMinutes: true)!;
      expect(injury.severity, InjurySeverity.minor);
      expect(injury.gamesRemainingAtSeverity, 1);

      // Game 4: plays through it again -- fully healed by Game 5.
      final healed = injury.recoverAfterGame(playedRealMinutes: true);
      expect(healed, isNull);
    });

    test('a benched game always drops a full tier regardless of games '
        'remaining at the current tier', () {
      final freshMajor = PlayerInjury.fresh(InjurySeverity.major);
      expect(freshMajor.gamesRemainingAtSeverity, 6);

      final afterOneBench = freshMajor.recoverAfterGame(
        playedRealMinutes: false,
      )!;

      // Not just "6 - 1 = 5 games remaining at major" -- a full drop to
      // moderate's own fresh duration.
      expect(afterOneBench.severity, InjurySeverity.moderate);
      expect(afterOneBench.gamesRemainingAtSeverity, 4);
    });

    test('a minor injury fully heals the moment it is benched once', () {
      final minor = PlayerInjury.fresh(InjurySeverity.minor);

      final result = minor.recoverAfterGame(playedRealMinutes: false);

      expect(result, isNull);
    });
  });

  group('injuryBonusFor', () {
    test('0 for an uninjured (null) player', () {
      expect(injuryBonusFor(null), 0.0);
    });

    test('matches the tier\'s own ratingPenalty for an injured player', () {
      final injury = PlayerInjury.fresh(InjurySeverity.moderate);
      expect(injuryBonusFor(injury), -0.25);
    });
  });

  group('injuryChanceFor', () {
    test('base chance for a neutral player in the regular season', () {
      expect(
        injuryChanceFor(traits: const {}, isPostseason: false),
        kBaseInjuryChancePerPlayerGame,
      );
    });

    test('halved in the postseason', () {
      expect(
        injuryChanceFor(traits: const {}, isPostseason: true),
        kBaseInjuryChancePerPlayerGame / 2,
      );
    });

    test('Injury Prone multiplies the base chance up', () {
      expect(
        injuryChanceFor(traits: {Trait.injuryProne}, isPostseason: false),
        kBaseInjuryChancePerPlayerGame * kInjuryProneChanceMultiplier,
      );
    });

    test('Iron Man multiplies the base chance down', () {
      expect(
        injuryChanceFor(traits: {Trait.ironMan}, isPostseason: false),
        kBaseInjuryChancePerPlayerGame * kIronManInjuryChanceMultiplier,
      );
    });
  });

  group('rollInjurySeverity', () {
    test('equal odds across all 3 tiers for a neutral player, over many '
        'trials', () {
      final counts = {for (final s in InjurySeverity.values) s: 0};
      final random = Random(1);
      const trials = 3000;
      for (var i = 0; i < trials; i++) {
        final severity = rollInjurySeverity(random, const {});
        counts[severity] = counts[severity]! + 1;
      }
      // Loose band -- a real coin-flip-style distribution, not an exact
      // count.
      for (final count in counts.values) {
        expect(count, greaterThan(trials * 0.2));
      }
    });

    test('Injury Prone skews toward major', () {
      final random = Random(1);
      var majorCount = 0;
      const trials = 2000;
      for (var i = 0; i < trials; i++) {
        if (rollInjurySeverity(random, {Trait.injuryProne}) ==
            InjurySeverity.major) {
          majorCount++;
        }
      }
      // 3/6 weight -- should land well above the neutral 1/3.
      expect(majorCount, greaterThan(trials * 0.4));
    });

    test('Iron Man skews toward minor', () {
      final random = Random(1);
      var minorCount = 0;
      const trials = 2000;
      for (var i = 0; i < trials; i++) {
        if (rollInjurySeverity(random, {Trait.ironMan}) ==
            InjurySeverity.minor) {
          minorCount++;
        }
      }
      // 3/5 weight -- should land well above the neutral 1/3.
      expect(minorCount, greaterThan(trials * 0.5));
    });
  });
}
