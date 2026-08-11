import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';

import 'roster_test_helpers.dart';

void main() {
  test('89 overall is three-star, not four-star', () {
    expect(StarTier.of(playerWithOverall(89)), StarTier.threeStar);
  });

  test('90 overall is four-star', () {
    expect(StarTier.of(playerWithOverall(90)), StarTier.fourStar);
  });

  test('99 overall is four-star', () {
    expect(StarTier.of(playerWithOverall(99)), StarTier.fourStar);
  });

  test('79 overall is two-star, not three-star', () {
    expect(StarTier.of(playerWithOverall(79)), StarTier.twoStar);
  });

  test('80 overall is three-star', () {
    expect(StarTier.of(playerWithOverall(80)), StarTier.threeStar);
  });

  test('69 overall is one-star, not two-star', () {
    expect(StarTier.of(playerWithOverall(69)), StarTier.oneStar);
  });

  test('70 overall is two-star', () {
    expect(StarTier.of(playerWithOverall(70)), StarTier.twoStar);
  });

  test('59 overall is no stars, not one-star', () {
    expect(StarTier.of(playerWithOverall(59)), StarTier.noStars);
  });

  test('60 overall is one-star', () {
    expect(StarTier.of(playerWithOverall(60)), StarTier.oneStar);
  });

  test('1 overall is no stars', () {
    expect(StarTier.of(playerWithOverall(1)), StarTier.noStars);
  });
}
