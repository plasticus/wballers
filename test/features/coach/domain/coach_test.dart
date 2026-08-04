import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';

void main() {
  test('stores the coach\'s name and stats', () {
    const coach = Coach(name: 'Jordan Ellis', stats: CoachStats.neutral);

    expect(coach.name, 'Jordan Ellis');
    expect(coach.stats.overall, 50);
  });
}
