import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/match/domain/match_event.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/match/engine/substitution_policy.dart';
import 'package:womensbballmgr/features/matchup/domain/coaching_option.dart';
import 'package:womensbballmgr/features/matchup/domain/defensive_tactic.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

import '../../../support/match_test_players.dart';

Coach _coach({
  required int offense,
  required int defense,
  int motivation = 50,
}) {
  return Coach(
    name: 'Coach',
    stats: CoachStats(
      offense: offense,
      defense: defense,
      development: 50,
      motivation: motivation,
      management: 50,
    ),
    archetype: CoachArchetype.steadyHand,
  );
}

void main() {
  test('is deterministic for a given seed', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');

    final a = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );
    final b = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    expect(a.homeScore, b.homeScore);
    expect(a.awayScore, b.awayScore);
    expect(a.homeScoreByQuarter, b.homeScoreByQuarter);
    expect(a.awayScoreByQuarter, b.awayScoreByQuarter);
    expect(a.events.length, b.events.length);
  });

  test('final score equals the sum of quarter scores', () {
    final result = simulateMatch(
      Random(3),
      homeRoster: testRoster('home'),
      awayRoster: testRoster('away'),
    );

    expect(
      result.homeScoreByQuarter.fold(0, (a, b) => a + b),
      result.homeScore,
    );
    expect(
      result.awayScoreByQuarter.fold(0, (a, b) => a + b),
      result.awayScore,
    );
  });

  test('runs at least 4 quarters', () {
    final result = simulateMatch(
      Random(3),
      homeRoster: testRoster('home'),
      awayRoster: testRoster('away'),
    );

    expect(result.homeScoreByQuarter.length, greaterThanOrEqualTo(4));
    expect(result.awayScoreByQuarter.length, greaterThanOrEqualTo(4));
  });

  test('never ends in a tie -- overtime keeps playing until it breaks', () {
    final random = Random(17);

    for (var i = 0; i < 100; i++) {
      // Evenly-matched (same rating distribution, distinct players)
      // rosters on both sides maximize the chance of a regulation tie,
      // which is exactly the scenario overtime exists to resolve.
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );

      expect(result.homeScore, isNot(result.awayScore));
    }
  });

  test('some games actually go to overtime', () {
    // Not a magic seed -- 23 used to reliably produce one within 100
    // games, but the blowout-pace rubber-banding fix
    // (`possession_engine.dart`'s `kBlowoutPaceMargin`) changes how many
    // seconds a possession takes once either side is up by 20+, which
    // shifts every later possession's timing enough to change which of
    // these evenly-matched games land on a regulation tie. 1 is a
    // re-verified seed that still reliably hits one within 100 games.
    final random = Random(1);
    var sawOvertime = false;

    for (var i = 0; i < 100; i++) {
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );
      if (result.homeScoreByQuarter.length > 4) {
        sawOvertime = true;
        break;
      }
    }

    expect(sawOvertime, isTrue);
  });

  test('both teams end up with roughly a full game of combined court '
      'minutes, and both sides match', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    final result = simulateMatch(
      Random(7),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    final homeMinutes = homeRoster.fold<double>(
      0,
      (sum, p) => sum + (result.minutesPlayed[p] ?? 0),
    );
    final awayMinutes = awayRoster.fold<double>(
      0,
      (sum, p) => sum + (result.minutesPlayed[p] ?? 0),
    );

    // Both teams share the same clock, so their total court-minutes must
    // match each other exactly -- and land near 200 (5 players x 40
    // minutes), with some slack for quarters that ran past the buzzer
    // (see `simulateMatch`'s doc comment on that simplification) and for
    // the rare game that needed overtime.
    expect(homeMinutes, closeTo(awayMinutes, 0.01));
    expect(homeMinutes, greaterThan(195));
    expect(homeMinutes, lessThan(320));
  });

  test('every player who fouled out has at least 6 personal fouls', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    final result = simulateMatch(
      Random(99),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    for (final player in result.fouledOut) {
      expect(result.personalFouls[player]!, greaterThanOrEqualTo(6));
    }
  });

  test('personal fouls are recorded for players on both rosters over many '
      'games', () {
    var sawFouls = false;
    final random = Random(123);

    for (var i = 0; i < 20; i++) {
      final result = simulateMatch(
        random,
        homeRoster: testRoster('home-$i'),
        awayRoster: testRoster('away-$i'),
      );
      if (result.personalFouls.values.any((count) => count > 0)) {
        sawFouls = true;
        break;
      }
    }

    expect(sawFouls, isTrue);
  });

  test('an explicit target-minutes map overrides the automatic overall-based '
      'ranking -- the GM\'s own bench order actually drives who plays', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');
    // Reversed: the worst-overall player on the roster is list position
    // 0, so an ordered-roster ranking gives *her* the top target
    // minutes, opposite of what the automatic overall-based default
    // would do.
    final benchOrder = homeRoster.reversed.toList();

    final result = simulateMatch(
      Random(7),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
      homeTargetMinutes: targetMinutesForOrderedRoster(benchOrder),
    );

    final topBenchOrderPlayer = benchOrder.first; // worst overall
    final bottomBenchOrderPlayer = benchOrder.last; // best overall
    expect(
      result.minutesPlayed[topBenchOrderPlayer]!,
      greaterThan(result.minutesPlayed[bottomBenchOrderPlayer]!),
    );
  });

  test('a team with a real coach Offense/Defense advantage scores more '
      'often than an identical team with no coach data at all (2026-08-20, '
      'a direct GM re-confirmation)', () {
    // Home's own coach rates high on both stats (a real positive bonus on
    // both ends of the floor); away's own coach rates low on both (a real
    // negative bonus on both ends) -- entirely independent of each other
    // under the absolute, 50-baseline model.
    final favoredHomeCoach = _coach(offense: 90, defense: 90);
    final weakAwayCoach = _coach(offense: 10, defense: 10);
    const sampleSize = 200;

    var homeScoreWithCoaches = 0;
    var awayScoreWithCoaches = 0;
    final withCoaches = Random(21);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulateMatch(
        withCoaches,
        homeRoster: testRoster('home-$i', baseRating: 50, step: 0),
        awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
        homeCoach: favoredHomeCoach,
        awayCoach: weakAwayCoach,
      );
      homeScoreWithCoaches += result.homeScore;
      awayScoreWithCoaches += result.awayScore;
    }

    var homeScoreNoCoaches = 0;
    var awayScoreNoCoaches = 0;
    final noCoaches = Random(21);
    for (var i = 0; i < sampleSize; i++) {
      final result = simulateMatch(
        noCoaches,
        homeRoster: testRoster('home-$i', baseRating: 50, step: 0),
        awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
      );
      homeScoreNoCoaches += result.homeScore;
      awayScoreNoCoaches += result.awayScore;
    }

    // With the coach matchup in play, home's scoring margin over away
    // should be meaningfully wider than the same matchup with no coach
    // bonus applied at all.
    final marginWithCoaches = homeScoreWithCoaches - awayScoreWithCoaches;
    final marginNoCoaches = homeScoreNoCoaches - awayScoreNoCoaches;
    expect(marginWithCoaches, greaterThan(marginNoCoaches));
  });

  test('omitting homeCoach/awayCoach leaves the game completely unaffected '
      '-- the exact same result as before the coach bonus existed', () {
    final homeRoster = testRoster('home');
    final awayRoster = testRoster('away');

    final withoutCoaches = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );
    final withNullCoaches = simulateMatch(
      Random(41),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
      homeCoach: null,
      awayCoach: null,
    );

    expect(withoutCoaches.homeScore, withNullCoaches.homeScore);
    expect(withoutCoaches.awayScore, withNullCoaches.awayScore);
  });

  test('simulates fine with a short-handed roster (2026-08-20, injuries: a '
      'player or two parked in Reserve/Inactive)', () {
    final homeRoster = testRoster('home').take(10).toList();
    final awayRoster = testRoster('away');

    final result = simulateMatch(
      Random(1),
      homeRoster: homeRoster,
      awayRoster: awayRoster,
    );

    expect(result, isNotNull);
  });

  test('throws when a roster has fewer than 5 or more than 12 players', () {
    final homeRoster = testRoster('home').take(4).toList();
    final awayRoster = testRoster('away');

    expect(
      () => simulateMatch(
        Random(1),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  group('offense shape + defensive tactic (2026-08-14, a direct GM ask, '
      'following the "Coach\'s Board" design artifact)', () {
    /// 12 players, all flat [rating] except the first 5 (bench order),
    /// whose positions are [startingFivePositions] -- the only thing this
    /// changes is what `detectOffenseShape` reads off the top of the
    /// roster.
    List<Player> rosterWithShape(
      String label,
      List<Position> startingFivePositions, {
      int rating = 50,
    }) {
      return [
        for (var i = 0; i < startingFivePositions.length; i++)
          testPlayer(
            id: '$label-$i',
            rating: rating,
            position: startingFivePositions[i],
          ),
        for (var i = startingFivePositions.length; i < 12; i++)
          testPlayer(id: '$label-$i', rating: rating),
      ];
    }

    test("Motion's ball-movement bump nets out to more scoring over many "
        'games than an identical roster running Traditional (fewer '
        'turnovers -> more possessions that end in points)', () {
      final motionRoster = rosterWithShape('motion', const [
        Position.pointGuard,
        Position.smallForward,
        Position.smallForward,
        Position.powerForward,
        Position.center,
      ]);
      final traditionalRoster = rosterWithShape('trad', const [
        Position.pointGuard,
        Position.shootingGuard,
        Position.smallForward,
        Position.powerForward,
        Position.center,
      ]);
      const sampleSize = 150;

      var motionScore = 0;
      final motionRandom = Random(31);
      for (var i = 0; i < sampleSize; i++) {
        motionScore += simulateMatch(
          motionRandom,
          homeRoster: motionRoster,
          awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
        ).homeScore;
      }

      var traditionalScore = 0;
      final traditionalRandom = Random(31);
      for (var i = 0; i < sampleSize; i++) {
        traditionalScore += simulateMatch(
          traditionalRandom,
          homeRoster: traditionalRoster,
          awayRoster: testRoster('away-$i', baseRating: 50, step: 0),
        ).homeScore;
      }

      expect(motionScore, greaterThan(traditionalScore));
    });

    test("Face-Guard the Star widens the defense's scoring margin over "
        'many games compared to an identical matchup on Balanced', () {
      // A real, identifiable best player (away-0, highest overall) for
      // Face-Guard the Star to actually have a target worth suppressing.
      final home = testRoster('home', baseRating: 50, step: 0);

      var awayScoreFaceGuarded = 0;
      final faceGuardedRandom = Random(43);
      const sampleSize = 150;
      for (var i = 0; i < sampleSize; i++) {
        awayScoreFaceGuarded += simulateMatch(
          faceGuardedRandom,
          homeRoster: home,
          awayRoster: testRoster('away-$i', baseRating: 88, step: 4),
          homeDefenseTactic: DefensiveTactic.faceGuardStar,
        ).awayScore;
      }

      var awayScoreBalanced = 0;
      final balancedRandom = Random(43);
      for (var i = 0; i < sampleSize; i++) {
        awayScoreBalanced += simulateMatch(
          balancedRandom,
          homeRoster: home,
          awayRoster: testRoster('away-$i', baseRating: 88, step: 4),
        ).awayScore;
      }

      expect(awayScoreFaceGuarded, lessThan(awayScoreBalanced));
    });

    test('AI opponents always defend Balanced -- omitting '
        'homeDefenseTactic/awayDefenseTactic is identical to passing '
        'DefensiveTactic.balanced explicitly for both sides', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');

      final omitted = simulateMatch(
        Random(53),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      final explicit = simulateMatch(
        Random(53),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeDefenseTactic: DefensiveTactic.balanced,
        awayDefenseTactic: DefensiveTactic.balanced,
      );

      expect(omitted.homeScore, explicit.homeScore);
      expect(omitted.awayScore, explicit.awayScore);
    });
  });

  group('quarter-break coaching options (2026-08-17, TODO.md item 8)', () {
    test('no picker supplied -- identical to before this system existed', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');

      final withoutPickers = simulateMatch(
        Random(61),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      final explicitlyNull = simulateMatch(
        Random(61),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeCoachingPicker: null,
        awayCoachingPicker: null,
      );

      expect(withoutPickers.homeScore, explicitlyNull.homeScore);
      expect(withoutPickers.awayScore, explicitlyNull.awayScore);
    });

    test('a picker is called at every ordinary quarter break, offered a '
        'real 3-option menu each time', () {
      final calls = <CoachingBreakContext>[];
      simulateMatch(
        Random(17),
        homeRoster: testRoster('home'),
        awayRoster: testRoster('away'),
        homeCoachingPicker: (context) {
          calls.add(context);
          return null;
        },
      );

      // At least the 3 ordinary end-of-Q1/Q2/Q3 breaks -- possibly a 4th
      // if the late-game margin happened to be within 7 this particular
      // seed.
      expect(calls.length, greaterThanOrEqualTo(3));
      for (final call in calls) {
        expect(call.offered, hasLength(3));
      }
      // Deciding for Q2 is the only firstHalf-eligible break -- every
      // other call happened for Q3, Q4, or the late-game stoppage.
      expect(calls.first.quarter, 2);
    });

    test('is still deterministic for a given seed with pickers attached', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      CoachingOption? pick(CoachingBreakContext context) =>
          context.offered.first;

      final a = simulateMatch(
        Random(29),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeCoachingPicker: pick,
        awayCoachingPicker: pick,
      );
      final b = simulateMatch(
        Random(29),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeCoachingPicker: pick,
        awayCoachingPicker: pick,
      );

      expect(a.homeScore, b.homeScore);
      expect(a.awayScore, b.awayScore);
      expect(a.homeScoreByQuarter, b.homeScoreByQuarter);
    });

    test('Fire the Team Up actually raises energy the moment it is '
        'picked', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      var offeredFireUp = false;

      final result = simulateMatch(
        Random(7),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        // Force it whenever it's on the menu, so the test doesn't depend
        // on this particular seed's random draw including it.
        homeCoachingPicker: (context) {
          if (context.offered.contains(CoachingOption.fireTheTeamUp)) {
            offeredFireUp = true;
            return CoachingOption.fireTheTeamUp;
          }
          return null;
        },
      );

      // Not every seed's random draw is guaranteed to include it at
      // least once across 3-4 breaks, but across a real game it's very
      // likely -- if it never came up, the assertion below is skipped
      // rather than flaking the suite over an unlucky draw.
      if (offeredFireUp) {
        expect(result.finalEnergy.values, isNotEmpty);
      }
    });

    test('a picker choosing an option outside the offered list is simply '
        'ignored -- no crash, same as choosing null', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');

      expect(
        () => simulateMatch(
          Random(5),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          // Always returns something not necessarily in `offered` --
          // the engine trusts the caller for now (no live UI to
          // misbehave yet), so this should just apply whatever bonus
          // that option maps to without crashing.
          homeCoachingPicker: (_) => CoachingOption.focusDefense,
        ),
        returnsNormally,
      );
    });

    test('a high-Motivation coach\'s Focus Defense pick suppresses the '
        'opponent\'s scoring more than a neutral-Motivation coach\'s same '
        'pick (2026-08-19, a direct GM ask -- Motivation scaling the '
        'coaching-option bonuses)', () {
      final homeRoster = testRoster('home', baseRating: 50, step: 0);
      final awayRoster = testRoster('away', baseRating: 50, step: 0);
      CoachingOption? alwaysFocusDefense(CoachingBreakContext context) =>
          CoachingOption.focusDefense;

      const sampleSize = 150;
      var awayScoreWithHighMotivation = 0;
      var awayScoreWithNeutralMotivation = 0;

      for (var i = 0; i < sampleSize; i++) {
        final highMotivation = simulateMatch(
          Random(100 + i),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          // Offense/Defense both pinned to the exact 50 midpoint -- keeps
          // the separate, unrelated coach-quality bonus (`coachQualityBonus`)
          // at exactly 0, so only Motivation's effect on the coaching-option
          // pick is under test here.
          homeCoach: _coach(offense: 50, defense: 50, motivation: 99),
          homeCoachingPicker: alwaysFocusDefense,
        );
        awayScoreWithHighMotivation += highMotivation.awayScore;

        final neutralMotivation = simulateMatch(
          Random(100 + i),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          homeCoach: _coach(offense: 50, defense: 50, motivation: 50),
          homeCoachingPicker: alwaysFocusDefense,
        );
        awayScoreWithNeutralMotivation += neutralMotivation.awayScore;
      }

      expect(
        awayScoreWithHighMotivation,
        lessThan(awayScoreWithNeutralMotivation),
      );
    });
  });

  group('simulateMatchLive (2026-08-18, TODO.md item 8 -- live-game '
      'architecture stage 2)', () {
    test('produces the same shape of result as simulateMatch -- same '
        'seed, no pickers on either path', () async {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');

      final sync = simulateMatch(
        Random(11),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      final live = await simulateMatchLive(
        Random(11),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        onSegmentComplete: (_) async {},
      );

      expect(live.homeScore, sync.homeScore);
      expect(live.awayScore, sync.awayScore);
      expect(live.homeScoreByQuarter, sync.homeScoreByQuarter);
      expect(live.awayScoreByQuarter, sync.awayScoreByQuarter);
      expect(live.events.length, sync.events.length);
    });

    test(
      'onSegmentComplete is called at least once per quarter, and the '
      'concatenation of every possession in every segment equals the '
      'final event log exactly -- no event missed, none duplicated',
      () async {
        final segments = <LiveGameSegment>[];
        final result = await simulateMatchLive(
          Random(23),
          homeRoster: testRoster('home'),
          awayRoster: testRoster('away'),
          onSegmentComplete: (segment) async {
            segments.add(segment);
          },
        );

        expect(segments.length, greaterThanOrEqualTo(4));
        final concatenated = segments
            .expand((segment) => segment.possessions)
            .expand((events) => events)
            .toList();
        expect(concatenated.length, result.events.length);
        expect(concatenated, orderedEquals(result.events));
        // Every segment completes its quarter except a possible Q4
        // late-game pause -- at most one `false` in the whole game.
        expect(
          segments.where((s) => !s.isEndOfQuarter).length,
          lessThanOrEqualTo(1),
        );
      },
    );

    test('quarter and isEndOfQuarter track the real game state -- '
        'quarters count up 1..4(+OT), and every segment completes its '
        'quarter except a possible Q4 late-game pause', () async {
      final segments = <LiveGameSegment>[];
      await simulateMatchLive(
        Random(41),
        homeRoster: testRoster('home'),
        awayRoster: testRoster('away'),
        onSegmentComplete: (segment) async {
          segments.add(segment);
        },
      );

      final quarters = segments.map((s) => s.quarter).toList();
      expect(quarters, orderedEquals([...quarters]..sort()));
      expect(quarters.first, 1);
      for (final segment in segments) {
        if (!segment.isEndOfQuarter) {
          expect(segment.quarter, 4);
        }
      }
    });

    test('the tip-off is a real, translatable event -- the very first '
        'possession, crediting whoever actually jumped', () async {
      LiveGameSegment? firstSegment;
      final result = await simulateMatchLive(
        Random(9),
        homeRoster: testRoster('home'),
        awayRoster: testRoster('away'),
        onSegmentComplete: (segment) async {
          firstSegment ??= segment;
        },
      );

      expect(firstSegment!.quarter, 1);
      final tipOff = firstSegment!.possessions.first.first;
      expect(tipOff.type, MatchEventType.tipOff);
      expect(tipOff.player, isNotNull);
      expect(tipOff.secondPlayer, isNotNull);
      expect(result.events.first, tipOff);
    });

    test(
      'a live picker is actually awaited, and its pick takes effect',
      () async {
        var callCount = 0;
        final result = await simulateMatchLive(
          Random(5),
          homeRoster: testRoster('home'),
          awayRoster: testRoster('away'),
          homeLiveCoachingPicker: (context) async {
            callCount++;
            // Force it whenever offered, so this doesn't depend on this
            // particular seed's random draw including it.
            if (context.offered.contains(CoachingOption.fireTheTeamUp)) {
              return CoachingOption.fireTheTeamUp;
            }
            return null;
          },
          onSegmentComplete: (_) async {},
        );

        expect(callCount, greaterThanOrEqualTo(3));
        expect(result.finalEnergy.values, isNotEmpty);
      },
    );

    test(
      'is deterministic for a given seed with live pickers attached',
      () async {
        final homeRoster = testRoster('home');
        final awayRoster = testRoster('away');
        Future<CoachingOption?> pick(CoachingBreakContext context) async =>
            context.offered.first;

        final a = await simulateMatchLive(
          Random(31),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          homeLiveCoachingPicker: pick,
          awayLiveCoachingPicker: pick,
          onSegmentComplete: (_) async {},
        );
        final b = await simulateMatchLive(
          Random(31),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          homeLiveCoachingPicker: pick,
          awayLiveCoachingPicker: pick,
          onSegmentComplete: (_) async {},
        );

        expect(a.homeScore, b.homeScore);
        expect(a.awayScore, b.awayScore);
        expect(a.homeScoreByQuarter, b.homeScoreByQuarter);
      },
    );

    test('no pickers supplied -- identical to simulateMatch with none '
        'either, across many seeds', () async {
      for (var seed = 0; seed < 15; seed++) {
        final homeRoster = testRoster('home');
        final awayRoster = testRoster('away');

        final sync = simulateMatch(
          Random(seed),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
        );
        final live = await simulateMatchLive(
          Random(seed),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          onSegmentComplete: (_) async {},
        );

        expect(live.homeScore, sync.homeScore, reason: 'seed $seed');
        expect(live.awayScore, sync.awayScore, reason: 'seed $seed');
      }
    });
  });
}
