import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

const _base = (
  speed: 50,
  agility: 50,
  strength: 50,
  stamina: 50,
  ballControl: 50,
  passing: 50,
  insideScoring: 50,
  outsideScoring: 50,
  perimeterDefense: 50,
  interiorDefense: 50,
  disruption: 50,
  blocking: 50,
  potential: 50,
);

PlayerRatings _ratingsWith({
  int? strength,
  int? insideScoring,
  int? interiorDefense,
  int? potential,
}) {
  return PlayerRatings(
    speed: _base.speed,
    agility: _base.agility,
    strength: strength ?? _base.strength,
    stamina: _base.stamina,
    ballControl: _base.ballControl,
    passing: _base.passing,
    insideScoring: insideScoring ?? _base.insideScoring,
    outsideScoring: _base.outsideScoring,
    perimeterDefense: _base.perimeterDefense,
    interiorDefense: interiorDefense ?? _base.interiorDefense,
    disruption: _base.disruption,
    blocking: _base.blocking,
    potential: potential ?? _base.potential,
  );
}

void main() {
  test('overall averages the twelve stored ratings', () {
    expect(_ratingsWith().overall, 50);
  });

  test('overall excludes potential entirely', () {
    final lowPotential = _ratingsWith(potential: 1);
    final highPotential = _ratingsWith(potential: 99);

    expect(lowPotential.overall, highPotential.overall);
  });

  test('reboundingRating combines strength with the higher of inside scoring '
      'or interior defense', () {
    final scoringBig = _ratingsWith(
      strength: 80,
      insideScoring: 90,
      interiorDefense: 40,
    );
    // (80 + max(90, 40)) / 2 = 85
    expect(scoringBig.reboundingRating, 85);

    final defensiveBig = _ratingsWith(
      strength: 80,
      insideScoring: 40,
      interiorDefense: 90,
    );
    // (80 + max(40, 90)) / 2 = 85
    expect(defensiveBig.reboundingRating, 85);
  });

  test('reboundingRating is excluded from overall', () {
    // A huge rebounding rating (via strength + interiorDefense) shouldn't
    // move overall on its own if the other ten stats stay put.
    final baseline = _ratingsWith();
    final strongRebounder = _ratingsWith(strength: 99, interiorDefense: 99);

    expect(
      strongRebounder.overall,
      greaterThan(baseline.overall),
      reason: 'strength and interiorDefense are themselves in the average',
    );
    expect(strongRebounder.reboundingRating, 99);
  });

  test('rejects a rating of 0', () {
    expect(() => _ratingsWith(strength: 0), throwsA(isA<AssertionError>()));
  });

  test('rejects a rating of 100', () {
    expect(() => _ratingsWith(strength: 100), throwsA(isA<AssertionError>()));
  });

  test('accepts the 1-99 bounds', () {
    expect(() => _ratingsWith(strength: 1), returnsNormally);
    expect(() => _ratingsWith(strength: 99), returnsNormally);
  });
}
