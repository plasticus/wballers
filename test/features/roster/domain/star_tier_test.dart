import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';

import 'roster_test_helpers.dart';

void main() {
  test('89 overall is four-star, not five-star', () {
    expect(StarTier.of(playerWithOverall(89)), StarTier.fourStar);
  });

  test('90 overall is five-star', () {
    expect(StarTier.of(playerWithOverall(90)), StarTier.fiveStar);
  });

  test('99 overall is five-star', () {
    expect(StarTier.of(playerWithOverall(99)), StarTier.fiveStar);
  });

  test('77 overall is below four-star', () {
    expect(StarTier.of(playerWithOverall(77)), StarTier.belowFourStar);
  });

  test('78 overall is four-star', () {
    expect(StarTier.of(playerWithOverall(78)), StarTier.fourStar);
  });

  test('1 overall is below four-star', () {
    expect(StarTier.of(playerWithOverall(1)), StarTier.belowFourStar);
  });
}
