import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/target_minutes.dart';

void main() {
  test('the top 12 ranks sum to a full 200-minute game', () {
    final total = kTargetMinutesByRank.fold<int>(0, (sum, m) => sum + m);
    expect(total, 200);
  });

  test('matches the documented rank tiers', () {
    expect(targetMinutesForRank(1), 30);
    expect(targetMinutesForRank(3), 30);
    expect(targetMinutesForRank(4), 26);
    expect(targetMinutesForRank(5), 26);
    expect(targetMinutesForRank(6), 14);
    expect(targetMinutesForRank(7), 14);
    expect(targetMinutesForRank(8), 8);
    expect(targetMinutesForRank(9), 8);
    expect(targetMinutesForRank(10), 6);
    expect(targetMinutesForRank(11), 4);
    expect(targetMinutesForRank(12), 4);
  });

  test('ranks past 12 and below 1 are zero', () {
    expect(targetMinutesForRank(13), 0);
    expect(targetMinutesForRank(14), 0);
    expect(targetMinutesForRank(0), 0);
    expect(targetMinutesForRank(-1), 0);
  });
}
