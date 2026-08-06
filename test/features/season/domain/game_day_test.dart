import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';

void main() {
  test('label gives a real display string for every value', () {
    expect(GameDay.sunday.label, 'Sunday');
    expect(GameDay.tuesday.label, 'Tuesday');
    expect(GameDay.thursday.label, 'Thursday');
  });

  test('declaration order is chronological within a week', () {
    expect(GameDay.sunday.index, lessThan(GameDay.tuesday.index));
    expect(GameDay.tuesday.index, lessThan(GameDay.thursday.index));
  });
}
