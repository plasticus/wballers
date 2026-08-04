import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_legality.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';
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

  test('has exactly 12 active players', () {
    final roster = generateStartingRoster(1);

    expect(roster, hasLength(12));
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
    final roster = generateStartingRoster(1);

    final legality = evaluateRosterLegality(
      active: roster.map((m) => m.player).toList(),
    );

    expect(legality.isLegal, isTrue);
  });

  test('every player is below the four-star threshold -- a weak roster', () {
    // Check across many seeds, not just one, since this should be a
    // structural guarantee of the generation parameters, not a fluke.
    for (var seed = 0; seed < 50; seed++) {
      final roster = generateStartingRoster(seed);

      for (final membership in roster) {
        expect(
          StarTier.of(membership.player),
          StarTier.belowFourStar,
          reason:
              'seed $seed produced ${membership.player.name} at '
              '${membership.player.ratings.overall} overall',
        );
      }
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
