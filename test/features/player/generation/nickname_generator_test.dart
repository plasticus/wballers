import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/generation/nickname_generator.dart';

void main() {
  test('every achievement has a non-empty nickname pool', () {
    for (final achievement in Achievement.values) {
      expect(kNicknamePools[achievement], isNotNull);
      expect(kNicknamePools[achievement], isNotEmpty);
    }
  });

  test('suggestNickname always returns a candidate from the right pool', () {
    final random = Random(7);
    for (final achievement in Achievement.values) {
      for (var i = 0; i < 20; i++) {
        expect(
          kNicknamePools[achievement],
          contains(suggestNickname(random, achievement)),
        );
      }
    }
  });

  test('suggestNickname is deterministic for a given seed', () {
    final a = suggestNickname(Random(3), Achievement.defensiveMvp);
    final b = suggestNickname(Random(3), Achievement.defensiveMvp);
    expect(a, b);
  });

  test('grantAchievement returns a matching record and a valid nickname', () {
    final result = grantAchievement(
      Random(9),
      achievement: Achievement.mostDefensiveDisruptions,
      season: 1,
    );

    expect(result.record.achievement, Achievement.mostDefensiveDisruptions);
    expect(result.record.season, 1);
    expect(
      kNicknamePools[Achievement.mostDefensiveDisruptions],
      contains(result.suggestedNickname),
    );
  });
}
