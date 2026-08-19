import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/draft/generation/hidden_gem.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

Player _player({int rating = 60}) {
  return Player(
    id: 'p1',
    name: 'Test Player',
    age: 22,
    yearsOfService: 0,
    hometown: 'Testville',
    primaryPosition: Position.smallForward,
    handedness: Handedness.right,
    biography: '',
    ratings: PlayerRatings(
      speed: rating,
      agility: rating,
      strength: rating,
      stamina: rating,
      ballControl: rating,
      passing: rating,
      interiorOffense: rating,
      perimeterOffense: rating,
      perimeterDefense: rating,
      interiorDefense: rating,
      disruption: rating,
      blocking: rating,
      potential: 90,
    ),
    heightInches: 70,
    archetype: kArchetypesByPosition[Position.smallForward]!.first,
  );
}

void main() {
  group('hiddenGemBonus', () {
    test('exactly 0 at and below the floor (Management 30), every round', () {
      for (final round in [1, 2, 3]) {
        expect(hiddenGemBonus(round: round, management: 30), 0);
        expect(hiddenGemBonus(round: round, management: 1), 0);
      }
    });

    test('the locked ceiling: Management 79 (the real generation max) '
        'gives exactly 12/24/36 by round', () {
      expect(hiddenGemBonus(round: 1, management: 79), 12);
      expect(hiddenGemBonus(round: 2, management: 79), 24);
      expect(hiddenGemBonus(round: 3, management: 79), 36);
    });

    test('management above the ceiling is treated the same as the '
        'ceiling itself -- never more than the max', () {
      expect(hiddenGemBonus(round: 3, management: 99), 36);
    });

    test('linear in between -- Management 65 (roughly 70% of the way '
        'from floor to ceiling) lands proportionally', () {
      // (65-30)/(79-30) = 35/49 = 0.714
      expect(hiddenGemBonus(round: 3, management: 65), 26); // 36*0.714≈25.7
    });

    test('an out-of-range round is worth nothing', () {
      expect(hiddenGemBonus(round: 4, management: 79), 0);
    });

    test('monotonically increasing with management, for every round', () {
      for (final round in [1, 2, 3]) {
        var previous = hiddenGemBonus(round: round, management: 30);
        for (var m = 31; m <= 99; m++) {
          final current = hiddenGemBonus(round: round, management: m);
          expect(current, greaterThanOrEqualTo(previous));
          previous = current;
        }
      }
    });
  });

  group('applyHiddenGemBonus', () {
    test('a bonus of 0 or less is a no-op', () {
      final player = _player();
      expect(applyHiddenGemBonus(player, 0), same(player));
      expect(applyHiddenGemBonus(player, -5), same(player));
    });

    test('raises skillPoints by exactly the bonus amount', () {
      final player = _player(rating: 60);
      final before = player.ratings.skillPoints;
      final boosted = applyHiddenGemBonus(player, 24);
      expect(boosted.ratings.skillPoints, before + 24);
    });

    test('never pushes a field above kMaxRating -- clamps and moves on '
        'instead of losing points', () {
      final player = _player(rating: 98);
      final before = player.ratings.skillPoints;
      // 12 fields at 98: only 1 point of headroom each = 12 total before
      // every field caps out. A 20-point bonus can only ever add 12.
      final boosted = applyHiddenGemBonus(player, 20);
      expect(boosted.ratings.skillPoints, before + 12);
      expect(boosted.ratings.speed, 99);
      expect(boosted.ratings.blocking, 99);
    });

    test('never touches potential', () {
      final player = _player();
      final boosted = applyHiddenGemBonus(player, 12);
      expect(boosted.ratings.potential, player.ratings.potential);
    });

    test('is fully deterministic -- same input, same output, no Random '
        'involved at all', () {
      final a = applyHiddenGemBonus(_player(), 15);
      final b = applyHiddenGemBonus(_player(), 15);
      expect(a.ratings.skillPoints, b.ratings.skillPoints);
      expect(a.ratings.speed, b.ratings.speed);
    });
  });
}
