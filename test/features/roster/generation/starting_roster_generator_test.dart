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

  test('never puts 2 players with the same surname on the same team '
      '(2026-08-11, TODO.md: no duplicate surnames on a single team)', () {
    for (var seed = 1; seed <= 50; seed++) {
      final roster = generateStartingRoster(seed);
      final surnames = roster.map((m) => m.player.lastName).toList();
      expect(
        surnames.toSet(),
        hasLength(surnames.length),
        reason: 'seed $seed produced a duplicate surname: $surnames',
      );
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
    'includes a narrative core: an aging three-star-or-better vet and a '
    'boom-or-bust prospect with a wide gap between overall and potential',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final roster = generateStartingRoster(seed);
        final players = roster.map((m) => m.player).toList();

        final vetCandidates = players.where(
          (p) =>
              p.age >= 30 &&
              const {
                StarTier.fourStar,
                StarTier.threeStar,
              }.contains(StarTier.of(p)),
        );
        expect(
          vetCandidates,
          isNotEmpty,
          reason: 'seed $seed: no aging three-star-or-better vet found',
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

  test('the franchise vet\'s potential is pinned to exactly her own '
      'overall -- no wiggle room, a direct GM ask (2026-08-14): "I don\'t '
      'want anyone to think she should be trained more"', () {
    for (var seed = 0; seed < 100; seed++) {
      final vet = generateStartingRoster(seed)[0].player;
      expect(vet.ratings.potential, vet.ratings.overall, reason: 'seed $seed');
    }
  });

  test('the young-solid slot\'s potential spans a real 10-point window, '
      'not a tight one (2026-08-14, a GM preference: "I think I prefer '
      'the 10 point spread for her")', () {
    final gaps = <int>[];
    for (var seed = 0; seed < 200; seed++) {
      final youngSolid = generateStartingRoster(seed)[2].player;
      gaps.add(youngSolid.ratings.potential - youngSolid.ratings.overall);
    }
    // The jittered target itself spans a 10-point window (85 +/- 5) --
    // actual gaps vary further since overall has its own independent
    // roll, but they should spread meaningfully wider than the old +/-2
    // version ever could.
    expect(gaps.toSet().length, greaterThan(5), reason: '$gaps');
  });

  test('no generic filler\'s potential gap comes close to the real '
      'narrative-tier prospects\' -- capped regardless of age (2026-08-14, '
      'a direct GM report: 3 of 7 fillers read as "worth training" '
      'alongside the real 3, "too much choice for a head coach... just '
      'learning the game")', () {
    // 22 is a comfortable margin above the real observed ceiling (18,
    // sampled across 3000 seeds x 7 fillers -- the cap floors potential
    // at whatever overall rolls, `max(overall, jitter(66, 6))`, so a rare
    // low-overall/high-jitter tail can still clear 15) -- still nowhere
    // near the rookie's 28+ or a typical young-solid's 10-14.
    for (var seed = 0; seed < 200; seed++) {
      final roster = generateStartingRoster(seed);
      for (final membership in roster.skip(4)) {
        final gap =
            membership.player.ratings.potential -
            membership.player.ratings.overall;
        expect(
          gap,
          lessThanOrEqualTo(22),
          reason:
              'seed $seed: ${membership.player.name} (age '
              '${membership.player.age}) gapped $gap, close to '
              'narrative-tier territory',
        );
      }
    }
  });

  test('the default bench order\'s own top 5 (indices 0-4) is always a '
      'real, legal standard starting five -- one player at each of the 5 '
      'positions, out of the box, before the GM ever touches Bench Order '
      '(2026-08-14, a real GM report: "I have 2x PFs in the starting 5... '
      'if either had been a Center, I would have been okay")', () {
    for (var seed = 0; seed < 200; seed++) {
      final roster = generateStartingRoster(seed);
      final startingFivePositions = roster
          .take(5)
          .map((m) => m.player.primaryPosition)
          .toSet();
      expect(
        startingFivePositions,
        Position.values.toSet(),
        reason: 'seed $seed',
      );
    }
  });

  test('the 4 narrative slots (2026-08-14 revision) always land on 4 '
      'distinct standard positions', () {
    for (var seed = 0; seed < 100; seed++) {
      final roster = generateStartingRoster(seed);
      final narrativePositions = roster
          .take(4)
          .map((m) => m.player.primaryPosition)
          .toSet();
      expect(narrativePositions, hasLength(4), reason: 'seed $seed');
    }
  });

  test('missingStartingPosition names the one standard position none of '
      'the 4 narrative players occupies -- the Day-0 free agent\'s target '
      '(2026-08-14, a direct GM ask)', () {
    for (var seed = 0; seed < 100; seed++) {
      final roster = generateStartingRoster(seed);
      final missing = missingStartingPosition(roster);

      expect(
        roster.take(4).map((m) => m.player.primaryPosition),
        isNot(contains(missing)),
        reason: 'seed $seed',
      );
      // Together with the 4 narrative positions, every standard position
      // is accounted for exactly once.
      final covered = {
        ...roster.take(4).map((m) => m.player.primaryPosition),
        missing,
      };
      expect(covered, Position.values.toSet(), reason: 'seed $seed');
    }
  });

  test('the 4th narrative slot is a second vet already at her ceiling -- '
      'age 26, ~80 OVR, and not really worth training (a direct GM ask, '
      '2026-08-14)', () {
    for (var seed = 0; seed < 100; seed++) {
      final roster = generateStartingRoster(seed);
      final primeVet = roster[3].player;

      expect(primeVet.age, 26, reason: 'seed $seed');
      expect(primeVet.ratings.overall, inInclusiveRange(75, 85));
      // "Not worth training" -- the gap to potential should stay small,
      // nothing like the boom-or-bust prospect's wide-open one.
      expect(
        primeVet.ratings.potential - primeVet.ratings.overall,
        lessThanOrEqualTo(8),
        reason: 'seed $seed',
      );
    }
  });

  test('the boom-or-bust prospect starts in the mid-60s with a 95+ '
      'ceiling (2026-08-14 revision -- lower floor, higher ceiling than '
      'the original)', () {
    for (var seed = 0; seed < 100; seed++) {
      final prospect = generateStartingRoster(seed)[1].player;

      expect(prospect.age, 21, reason: 'seed $seed');
      expect(prospect.ratings.overall, inInclusiveRange(58, 70));
      expect(prospect.ratings.potential, greaterThanOrEqualTo(93));
    }
  });

  test('different seeds produce meaningfully different rosters', () {
    final a = generateStartingRoster(10);
    final b = generateStartingRoster(20);

    final aNames = a.map((m) => m.player.name).toSet();
    final bNames = b.map((m) => m.player.name).toSet();

    expect(aNames, isNot(equals(bNames)));
  });
}
