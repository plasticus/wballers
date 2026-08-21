import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';

void main() {
  test('label gives a real display string for every value', () {
    expect(GameDay.sunday.label, 'Sunday');
    expect(GameDay.tuesday.label, 'Tuesday');
    expect(GameDay.thursday.label, 'Thursday');
  });

  test('shortLabel gives a 3-letter abbreviation for every value '
      '(2026-08-15, a direct GM report -- the full label wrapped in the '
      'Full League schedule\'s date column)', () {
    expect(GameDay.sunday.shortLabel, 'Sun');
    expect(GameDay.tuesday.shortLabel, 'Tue');
    expect(GameDay.thursday.shortLabel, 'Thu');
  });

  test('declaration order is chronological within a week', () {
    expect(GameDay.sunday.index, lessThan(GameDay.tuesday.index));
    expect(GameDay.tuesday.index, lessThan(GameDay.thursday.index));
  });

  group('formatFictionalDateOffset (2026-08-21, the Dashboard\'s Draft In '
      'Progress card: "give it a calendar date, I don\'t care what")', () {
    test('a 0 offset matches formatFictionalDate exactly', () {
      expect(
        formatFictionalDateOffset(3, GameDay.thursday, 0),
        formatFictionalDate(3, GameDay.thursday),
      );
    });

    test('a negative offset lands on an earlier real date', () {
      // Week 3's Sunday is May 17 (2 full weeks after Week 1's May 3
      // anchor) -- 7 days earlier is May 10.
      expect(formatFictionalDate(3, GameDay.sunday), 'May 17');
      expect(formatFictionalDateOffset(3, GameDay.sunday, -7), 'May 10');
    });

    test('an offset can cross a month boundary', () {
      expect(formatFictionalDate(1, GameDay.sunday), 'May 3');
      expect(formatFictionalDateOffset(1, GameDay.sunday, -7), 'Apr 26');
    });
  });
}
