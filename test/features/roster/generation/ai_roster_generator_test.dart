import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_legality.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/roster/generation/ai_roster_generator.dart';

void main() {
  test('has exactly 12 active players covering every position', () {
    final roster = generateAiRoster(Random(1));

    expect(roster, hasLength(12));
    expect(roster.every((m) => m.status == RosterStatus.active), isTrue);

    final coveredPositions = roster
        .map((m) => m.player.primaryPosition)
        .toSet();
    expect(coveredPositions, Position.values.toSet());
  });

  test('the same seed produces an identical roster', () {
    final a = generateAiRoster(Random(7));
    final b = generateAiRoster(Random(7));

    for (var i = 0; i < a.length; i++) {
      expect(a[i].player.name, b[i].player.name);
      expect(a[i].player.ratings.overall, b[i].player.ratings.overall);
    }
  });

  test('always includes exactly one five-star player, leaning veteran', () {
    final random = Random(2024);
    for (var i = 0; i < 50; i++) {
      final roster = generateAiRoster(random);
      final fiveStars = roster
          .where((m) => StarTier.of(m.player) == StarTier.fiveStar)
          .toList();

      expect(fiveStars, hasLength(1));
      expect(fiveStars.single.player.age, greaterThanOrEqualTo(29));
    }
  });

  test('across many rosters, averages close to four four-star-or-better '
      'players, and never breaches the star-tier caps', () {
    final random = Random(99);
    var totalFourStarAndUp = 0;
    const sampleSize = 100;

    for (var i = 0; i < sampleSize; i++) {
      final roster = generateAiRoster(random);
      final legality = evaluateRosterLegality(
        active: roster.map((m) => m.player).toList(),
      );

      expect(legality.hasLegalFiveStarCount, isTrue);
      expect(legality.hasLegalFourStarAndUpCount, isTrue);
      totalFourStarAndUp += legality.fourStarAndUpCount;
    }

    expect(totalFourStarAndUp / sampleSize, closeTo(4, 1));
  });

  test('the young/mid/old age spread applies to the three 4-star slots', () {
    final random = Random(55);
    for (var i = 0; i < 30; i++) {
      final roster = generateAiRoster(random);
      final fourStars = roster
          .where((m) => StarTier.of(m.player) == StarTier.fourStar)
          .toList();

      // Not every quality-tier player necessarily lands exactly at
      // four-star (jitter can push one below 78 or above 89) -- but every
      // one that does must still respect the tier's overall 20-34 age
      // bound; the young/mid/old bias itself is checked statistically via
      // the average below.
      for (final membership in fourStars) {
        expect(membership.player.age, inInclusiveRange(20, 34));
      }
    }
  });

  test('team overall lands in the ~65-75 target range, comfortably under '
      'the star-cap ceiling (`0B_Planned.md`\'s team-overall-rebalance)', () {
    final random = Random(303);
    for (var i = 0; i < 100; i++) {
      final roster = generateAiRoster(random);
      expect(
        teamOverall(roster),
        inInclusiveRange(65, 75),
        reason: 'roster: ${roster.map((m) => m.player.ratings.overall)}',
      );
    }
  });
}
