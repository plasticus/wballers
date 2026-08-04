import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';

void main() {
  test('every achievement has a non-empty label', () {
    for (final achievement in Achievement.values) {
      expect(achievement.label, isNotEmpty);
    }
  });

  test('rejects a negative season', () {
    expect(
      () => PlayerAchievementRecord(
        achievement: Achievement.leagueMvp,
        season: -1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('stores the achievement and season', () {
    const record = PlayerAchievementRecord(
      achievement: Achievement.scoringLeader,
      season: 2,
    );

    expect(record.achievement, Achievement.scoringLeader);
    expect(record.season, 2);
  });
}
