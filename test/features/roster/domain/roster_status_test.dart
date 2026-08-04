import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

import 'roster_test_helpers.dart';

void main() {
  test('a rookie with 0 years of service is developmental-eligible', () {
    expect(
      isDevelopmentalEligible(playerWithOverall(50, yearsOfService: 0)),
      isTrue,
    );
  });

  test('a player with exactly 3 years of service is still eligible', () {
    expect(
      isDevelopmentalEligible(playerWithOverall(50, yearsOfService: 3)),
      isTrue,
    );
  });

  test('a player with 4 years of service is not eligible', () {
    expect(
      isDevelopmentalEligible(playerWithOverall(50, yearsOfService: 4)),
      isFalse,
    );
  });

  test('an international rookie debuting at 28 is still eligible by service, '
      'not age', () {
    final lateRookie = playerWithOverall(
      50,
      name: 'Late Rookie',
      age: 28,
      yearsOfService: 0,
    );

    expect(isDevelopmentalEligible(lateRookie), isTrue);
  });
}
