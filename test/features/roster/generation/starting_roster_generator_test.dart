import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_legality.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/roster/generation/ai_roster_generator.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

void main() {
  test('the same seed produces an identical roster', () {
    final a = generateStartingRoster(2024);
    final b = generateStartingRoster(2024);

    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].player.name, b[i].player.name);
      expect(a[i].player.ratings.overall, b[i].player.ratings.overall);
    }
  });

  test('has exactly 11 active players -- one short on purpose, to be '
      'filled by signing a free agent', () {
    final roster = generateStartingRoster(1);

    expect(roster, hasLength(11));
    expect(roster.every((m) => m.status == RosterStatus.active), isTrue);
  });

  test('covers every position with at least two players', () {
    final roster = generateStartingRoster(1);
    final counts = <Position, int>{};
    for (final membership in roster) {
      final position = membership.player.primaryPosition;
      counts[position] = (counts[position] ?? 0) + 1;
    }

    for (final position in Position.values) {
      expect(
        counts[position] ?? 0,
        greaterThanOrEqualTo(2),
        reason: '$position should have at least two players',
      );
    }
  });

  test('is legal under the star-tier caps', () {
    // Check across many seeds, not just one, since this should be a
    // structural guarantee of the generation parameters, not a fluke.
    for (var seed = 0; seed < 100; seed++) {
      final roster = generateStartingRoster(seed);

      final legality = evaluateRosterLegality(
        active: roster.map((m) => m.player).toList(),
      );

      expect(legality.isLegal, isTrue, reason: 'seed $seed');
    }
  });

  test('team overall lands on the low end of the league range, notably '
      'below a typical AI roster (`0B_Planned.md`\'s team-overall-rebalance: '
      '"I don\'t want them winning the championship in year 1") -- around '
      '69, per `Aug9bugs.md` #11\'s retuning', () {
    for (var seed = 0; seed < 100; seed++) {
      final roster = generateStartingRoster(seed);
      expect(
        teamOverall(roster),
        inInclusiveRange(66, 73),
        reason: 'seed $seed',
      );
    }

    // Not just individually in-range -- meaningfully lower than the AI
    // league's average, on average.
    final random = Random(404);
    var startingTotal = 0;
    var aiTotal = 0;
    const sampleSize = 100;
    for (var i = 0; i < sampleSize; i++) {
      startingTotal += teamOverall(generateStartingRoster(i));
      aiTotal += teamOverall(generateAiRoster(random));
    }
    expect(startingTotal / sampleSize, lessThan(aiTotal / sampleSize));
  });

  test(
    'includes a narrative core: an aging four-star-or-better vet and a '
    'boom-or-bust prospect with a wide gap between overall and potential',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final roster = generateStartingRoster(seed);
        final players = roster.map((m) => m.player).toList();

        final vetCandidates = players.where(
          (p) => p.age >= 30 && StarTier.of(p) != StarTier.belowFourStar,
        );
        expect(
          vetCandidates,
          isNotEmpty,
          reason: 'seed $seed: no aging four-star-or-better vet found',
        );

        final prospectCandidates = players.where(
          (p) => p.age <= 23 && p.ratings.potential - p.ratings.overall >= 15,
        );
        expect(
          prospectCandidates,
          isNotEmpty,
          reason: 'seed $seed: no high-upside young prospect found',
        );
      }
    },
  );

  test('different seeds produce meaningfully different rosters', () {
    final a = generateStartingRoster(10);
    final b = generateStartingRoster(20);

    final aNames = a.map((m) => m.player.name).toSet();
    final bNames = b.map((m) => m.player.name).toSet();

    expect(aNames, isNot(equals(bNames)));
  });
}
