import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_legality.dart';

import 'roster_test_helpers.dart';

List<Player> _roster({
  int fourStar = 0,
  int threeStar = 0,
  int belowThreeStar = 0,
}) {
  return [
    for (var i = 0; i < fourStar; i++) playerWithOverall(95),
    for (var i = 0; i < threeStar; i++) playerWithOverall(85),
    for (var i = 0; i < belowThreeStar; i++) playerWithOverall(50),
  ];
}

void main() {
  test('an all below-three-star 12-player roster is legal', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 12),
    );

    expect(legality.isLegal, isTrue);
  });

  test(
    'zero four-star players still allows the full six three-star players',
    () {
      final legality = evaluateRosterLegality(
        active: _roster(threeStar: 6, belowThreeStar: 6),
      );

      expect(legality.isLegal, isTrue);
      expect(legality.fourStarCount, 0);
      expect(legality.threeStarAndUpCount, 6);
    },
  );

  test('two four-star plus four three-star (six elite total) is legal', () {
    final legality = evaluateRosterLegality(
      active: _roster(fourStar: 2, threeStar: 4, belowThreeStar: 6),
    );

    expect(legality.isLegal, isTrue);
    expect(legality.fourStarCount, 2);
    expect(legality.threeStarAndUpCount, 6);
  });

  test('three four-star players is illegal even though total is 12', () {
    final legality = evaluateRosterLegality(
      active: _roster(fourStar: 3, threeStar: 3, belowThreeStar: 6),
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalFourStarCount, isFalse);
  });

  test('seven three-star-and-up players is illegal', () {
    final legality = evaluateRosterLegality(
      active: _roster(fourStar: 1, threeStar: 6, belowThreeStar: 5),
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalThreeStarAndUpCount, isFalse);
    expect(legality.threeStarAndUpCount, 7);
  });

  test('a roster with fewer than 12 players is legal -- no enforced floor', () {
    final legality = evaluateRosterLegality(active: _roster(belowThreeStar: 8));

    expect(legality.isLegal, isTrue);
    expect(legality.hasLegalActiveRosterSize, isTrue);
  });

  test('a roster with more than 12 players is illegal', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 13),
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalActiveRosterSize, isFalse);
  });

  test('an empty developmental list is legal by default', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 12),
    );

    expect(legality.hasLegalDevelopmentalRosterSize, isTrue);
    expect(legality.hasOnlyEligibleDevelopmentalPlayers, isTrue);
  });

  test('two eligible developmental players is legal', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 12),
      developmental: [
        playerWithOverall(50, yearsOfService: 0),
        playerWithOverall(50, yearsOfService: 3),
      ],
    );

    expect(legality.isLegal, isTrue);
    expect(legality.developmentalRosterSize, 2);
  });

  test('three developmental players is illegal', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 12),
      developmental: [
        playerWithOverall(50, yearsOfService: 0),
        playerWithOverall(50, yearsOfService: 0),
        playerWithOverall(50, yearsOfService: 0),
      ],
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalDevelopmentalRosterSize, isFalse);
  });

  test('a developmental player with too much service time is illegal', () {
    final legality = evaluateRosterLegality(
      active: _roster(belowThreeStar: 12),
      developmental: [playerWithOverall(50, yearsOfService: 4)],
    );

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleDevelopmentalPlayers, isFalse);
    expect(legality.ineligibleDevelopmentalCount, 1);
  });

  group('violationMessages (2026-08-20, a direct GM ask: "I think we need '
      'to build in more notifications of roster legality")', () {
    test('empty when the roster is legal', () {
      final legality = evaluateRosterLegality(
        active: _roster(belowThreeStar: 12),
      );

      expect(legality.violationMessages, isEmpty);
    });

    test('one message per distinct violation, all surfaced at once', () {
      final legality = evaluateRosterLegality(
        active: _roster(fourStar: 3, threeStar: 5, belowThreeStar: 6),
        developmental: [playerWithOverall(50, yearsOfService: 4)],
      );

      // 3 four-star (over the 2 cap), 8 three-star-and-up (over the 6
      // cap), 14 active total (over the 12 cap), plus 1 ineligible
      // developmental player -- 4 distinct violations at once.
      expect(legality.violationMessages, hasLength(4));
      expect(
        legality.violationMessages.any((m) => m.contains('active roster')),
        isTrue,
      );
      expect(
        legality.violationMessages.any((m) => m.contains('four-star')),
        isTrue,
      );
      expect(
        legality.violationMessages.any(
          (m) => m.contains('three-star-or-better'),
        ),
        isTrue,
      );
      expect(
        legality.violationMessages.any(
          (m) => m.contains('developmental player'),
        ),
        isTrue,
      );
    });
  });
}
