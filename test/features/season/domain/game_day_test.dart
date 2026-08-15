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
}
