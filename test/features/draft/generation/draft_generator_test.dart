import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/college.dart';
import 'package:womensbballmgr/features/draft/generation/draft_generator.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';

List<StandingsEntry> _standings(int teamCount) {
  return [
    for (var i = 0; i < teamCount; i++)
      StandingsEntry(
        teamAbbreviation: 'T$i',
        wins: teamCount - i,
        losses: i,
        pointsFor: 0,
        pointsAgainst: 0,
      ),
  ];
}

void main() {
  group('generateDraftClass', () {
    test('produces exactly the requested count', () {
      final draftClass = generateDraftClass(Random(1), count: 40);

      expect(draftClass.length, 40);
    });

    test('is deterministic for a given seed', () {
      final a = generateDraftClass(Random(7), count: 20);
      final b = generateDraftClass(Random(7), count: 20);

      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].player.name, b[i].player.name);
        expect(a[i].college.abbreviation, b[i].college.abbreviation);
      }
    });

    test('every prospect has 0 years of professional service and a young '
        'age', () {
      final draftClass = generateDraftClass(Random(3), count: 40);

      for (final prospect in draftClass) {
        expect(prospect.player.yearsOfService, 0);
        expect(prospect.player.age, inInclusiveRange(20, 23));
      }
    });

    test('every prospect is assigned a real college', () {
      final draftClass = generateDraftClass(Random(5), count: 40);
      final validAbbreviations = kColleges.map((c) => c.abbreviation).toSet();

      for (final prospect in draftClass) {
        expect(validAbbreviations, contains(prospect.college.abbreviation));
      }
    });

    test('traits stay rare -- most prospects have 0, very few have 2+', () {
      final draftClass = generateDraftClass(Random(9), count: 500);

      final noTraits = draftClass.where((p) => p.player.traits.isEmpty).length;
      final twoOrMoreTraits = draftClass
          .where((p) => p.player.traits.length >= 2)
          .length;

      expect(noTraits / draftClass.length, greaterThan(0.4));
      expect(twoOrMoreTraits / draftClass.length, lessThan(0.2));
      for (final prospect in draftClass) {
        expect(prospect.player.traits, isNot(contains(Trait.homegrown)));
      }
    });

    test('the top of the class is meaningfully better than the bottom, on '
        'average', () {
      final draftClass = generateDraftClass(Random(11), count: 70);
      final topAverage =
          draftClass
              .take(2)
              .map((p) => p.player.ratings.overall)
              .reduce((a, b) => a + b) /
          2;
      final bottomAverage =
          draftClass
              .skip(60)
              .map((p) => p.player.ratings.overall)
              .fold(0, (a, b) => a + b) /
          10;

      expect(topAverage, greaterThan(bottomAverage));
    });
  });

  group('generateDraftOrder', () {
    test('returns one slot per team', () {
      final order = generateDraftOrder(Random(1), _standings(20));

      expect(order.length, 20);
      expect(order.toSet().length, 20);
    });

    test('the worst-record playoff team picks before the best-record '
        'playoff team', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      // Standings are best-to-worst by construction (T0 best, T19 worst),
      // so the playoff field is T0-T7 (best 8) and the lottery field is
      // T8-T19. Among playoff teams, T7 (worst playoff seed) should pick
      // before T0 (best playoff seed).
      expect(order.indexOf('T7'), lessThan(order.indexOf('T0')));
    });

    test('non-playoff teams always pick before playoff teams', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final lastLotteryPick = order
          .take(12)
          .map((abbr) => int.parse(abbr.substring(1)))
          .toList();
      final firstPlayoffPick = order
          .skip(12)
          .map((abbr) => int.parse(abbr.substring(1)))
          .toList();

      expect(lastLotteryPick.every((n) => n >= 8), isTrue);
      expect(firstPlayoffPick.every((n) => n < 8), isTrue);
    });

    test('is deterministic for a given seed', () {
      final a = generateDraftOrder(Random(4), _standings(20));
      final b = generateDraftOrder(Random(4), _standings(20));

      expect(a, b);
    });

    test('a worse record earns better lottery odds on average', () {
      const trials = 300;
      var worstTeamFirstPickCount = 0;
      final random = Random(2);

      for (var i = 0; i < trials; i++) {
        final order = generateDraftOrder(random, _standings(20));
        if (order.first == 'T19') worstTeamFirstPickCount++;
      }

      // With a 12-team lottery weighted 12:11:...:1, the worst team (T19,
      // weight 12) should win the first pick meaningfully more often than
      // a flat 1/12 (~8.3%) chance would predict.
      expect(worstTeamFirstPickCount / trials, greaterThan(0.13));
    });

    test('throws when there are not more teams than the playoff field', () {
      expect(
        () => generateDraftOrder(Random(1), _standings(8)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('simulateDraft', () {
    test('produces draftOrder.length * rounds picks, with sequential '
        'overall pick numbers', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final draftClass = generateDraftClass(Random(1), count: 70);

      final picks = simulateDraft(
        Random(1),
        draftOrder: order,
        draftClass: draftClass,
      );

      expect(picks.length, order.length * kDraftRounds);
      for (var i = 0; i < picks.length; i++) {
        expect(picks[i].pickNumber, i + 1);
      }
    });

    test('round numbers advance correctly and each round replays the same '
        'team order', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final draftClass = generateDraftClass(Random(1), count: 70);

      final picks = simulateDraft(
        Random(1),
        draftOrder: order,
        draftClass: draftClass,
      );

      for (var round = 1; round <= kDraftRounds; round++) {
        final roundPicks = picks.where((p) => p.round == round).toList();
        expect(roundPicks.length, order.length);
        expect(roundPicks.map((p) => p.teamAbbreviation).toList(), order);
      }
    });

    test('no prospect is drafted twice', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final draftClass = generateDraftClass(Random(1), count: 70);

      final picks = simulateDraft(
        Random(1),
        draftOrder: order,
        draftClass: draftClass,
      );

      // Identity-based uniqueness (not by name) -- two independently
      // generated prospects could coincidentally share a name.
      final draftedProspects = picks.map((p) => p.prospect).toSet();
      expect(draftedProspects.length, picks.length);
    });

    test('the first pick is the best-rated prospect in the class', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final draftClass = generateDraftClass(Random(1), count: 70);
      final best = draftClass.reduce(
        (a, b) =>
            (a.player.ratings.overall + a.player.ratings.potential ~/ 2) >=
                (b.player.ratings.overall + b.player.ratings.potential ~/ 2)
            ? a
            : b,
      );

      final picks = simulateDraft(
        Random(1),
        draftOrder: order,
        draftClass: draftClass,
      );

      expect(picks.first.prospect.player.name, best.player.name);
    });

    test('throws when the draft class is too small', () {
      final order = generateDraftOrder(Random(1), _standings(20));
      final tinyClass = generateDraftClass(Random(1), count: 10);

      expect(
        () =>
            simulateDraft(Random(1), draftOrder: order, draftClass: tinyClass),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
