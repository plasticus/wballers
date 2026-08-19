import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/generation/nickname_generator.dart';

void main() {
  test('every achievement has a pool of exactly 25 nicknames, no '
      'duplicates within a pool', () {
    for (final achievement in Achievement.values) {
      final pool = kNicknamePools[achievement];
      expect(pool, isNotNull);
      expect(pool, hasLength(25));
      expect(pool!.toSet(), hasLength(25));
    }
  });

  test('suggestNickname always returns a candidate from the right pool', () {
    for (final achievement in Achievement.values) {
      for (var occurrenceIndex = 0; occurrenceIndex < 30; occurrenceIndex++) {
        expect(
          kNicknamePools[achievement],
          contains(
            suggestNickname(
              achievement,
              playerId: 'player-1',
              occurrenceIndex: occurrenceIndex,
            ),
          ),
        );
      }
    }
  });

  test('is deterministic for the same player/achievement/occurrence', () {
    final a = suggestNickname(
      Achievement.defensiveMvp,
      playerId: 'player-3',
      occurrenceIndex: 2,
    );
    final b = suggestNickname(
      Achievement.defensiveMvp,
      playerId: 'player-3',
      occurrenceIndex: 2,
    );
    expect(a, b);
  });

  test('cycles through all 25 candidates once before repeating any, for a '
      'single player/achievement pair', () {
    final seen = <String>[];
    for (var occurrenceIndex = 0; occurrenceIndex < 25; occurrenceIndex++) {
      seen.add(
        suggestNickname(
          Achievement.leagueMvp,
          playerId: 'dynasty-player',
          occurrenceIndex: occurrenceIndex,
        ),
      );
    }
    // All 25 distinct -- no repeat within one full lap of the pool (a
    // direct GM ask: "enough nicknames that a player could play 25
    // seasons before seeing repeats").
    expect(seen.toSet(), hasLength(25));

    // The 26th win (occurrence index 25) wraps back to the same order's
    // start, rather than raising or returning something new.
    final wrapped = suggestNickname(
      Achievement.leagueMvp,
      playerId: 'dynasty-player',
      occurrenceIndex: 25,
    );
    expect(wrapped, seen.first);
  });

  test('different players get different draw orders for the same '
      'achievement -- not everyone chasing the same league MVP sees the '
      'same nickname first', () {
    final first = suggestNickname(
      Achievement.leagueMvp,
      playerId: 'player-a',
      occurrenceIndex: 0,
    );
    final second = suggestNickname(
      Achievement.leagueMvp,
      playerId: 'player-b',
      occurrenceIndex: 0,
    );
    // Not a hard guarantee for any 2 arbitrary ids (a shuffle can
    // legitimately coincide), but exercises that the seed genuinely
    // depends on playerId, not just achievement -- see the follow-up
    // assertion for the real guarantee.
    expect(kNicknamePools[Achievement.leagueMvp], contains(first));
    expect(kNicknamePools[Achievement.leagueMvp], contains(second));

    // The real guarantee: across a batch of distinct ids, the pool isn't
    // silently collapsing to one fixed order regardless of playerId.
    final firstPicks = {
      for (var i = 0; i < 10; i++)
        suggestNickname(
          Achievement.leagueMvp,
          playerId: 'player-$i',
          occurrenceIndex: 0,
        ),
    };
    expect(firstPicks.length, greaterThan(1));
  });

  test('grantAchievement returns a matching record and a valid nickname', () {
    final result = grantAchievement(
      achievement: Achievement.defensiveMvp,
      season: 1,
      playerId: 'player-9',
      occurrenceIndex: 0,
    );

    expect(result.record.achievement, Achievement.defensiveMvp);
    expect(result.record.season, 1);
    expect(
      kNicknamePools[Achievement.defensiveMvp],
      contains(result.suggestedNickname),
    );
  });
}
