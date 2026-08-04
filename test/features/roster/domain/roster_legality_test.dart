import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_legality.dart';

import 'roster_test_helpers.dart';

List<Player> _roster({
  int fiveStar = 0,
  int fourStar = 0,
  int belowFourStar = 0,
}) {
  return [
    for (var i = 0; i < fiveStar; i++) playerWithOverall(95),
    for (var i = 0; i < fourStar; i++) playerWithOverall(80),
    for (var i = 0; i < belowFourStar; i++) playerWithOverall(50),
  ];
}

void main() {
  test('an all below-four-star 12-player roster is legal', () {
    final legality = evaluateRosterLegality(_roster(belowFourStar: 12));

    expect(legality.isLegal, isTrue);
  });

  test(
    'zero five-star players still allows the full six four-star players',
    () {
      final legality = evaluateRosterLegality(
        _roster(fourStar: 6, belowFourStar: 6),
      );

      expect(legality.isLegal, isTrue);
      expect(legality.fiveStarCount, 0);
      expect(legality.fourStarAndUpCount, 6);
    },
  );

  test('two five-star plus four four-star (six elite total) is legal', () {
    final legality = evaluateRosterLegality(
      _roster(fiveStar: 2, fourStar: 4, belowFourStar: 6),
    );

    expect(legality.isLegal, isTrue);
    expect(legality.fiveStarCount, 2);
    expect(legality.fourStarAndUpCount, 6);
  });

  test('three five-star players is illegal even though total is 12', () {
    final legality = evaluateRosterLegality(
      _roster(fiveStar: 3, fourStar: 3, belowFourStar: 6),
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalFiveStarCount, isFalse);
  });

  test('seven four-star-and-up players is illegal', () {
    final legality = evaluateRosterLegality(
      _roster(fiveStar: 1, fourStar: 6, belowFourStar: 5),
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalFourStarAndUpCount, isFalse);
    expect(legality.fourStarAndUpCount, 7);
  });

  test('a roster with fewer than 12 players is illegal', () {
    final legality = evaluateRosterLegality(_roster(belowFourStar: 11));

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalRosterSize, isFalse);
  });

  test('a roster with more than 12 players is illegal', () {
    final legality = evaluateRosterLegality(_roster(belowFourStar: 13));

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalRosterSize, isFalse);
  });
}
