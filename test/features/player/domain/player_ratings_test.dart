import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

const _base = (
  speed: 50,
  agility: 50,
  strength: 50,
  stamina: 50,
  ballControl: 50,
  passing: 50,
  interiorOffense: 50,
  perimeterOffense: 50,
  perimeterDefense: 50,
  interiorDefense: 50,
  disruption: 50,
  blocking: 50,
  potential: 50,
);

PlayerRatings _ratingsWith({
  int? strength,
  int? interiorOffense,
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
    interiorOffense: interiorOffense ?? _base.interiorOffense,
    perimeterOffense: _base.perimeterOffense,
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

  test('overall reflects a change to any stored rating', () {
    final baseline = _ratingsWith();
    final strongInside = _ratingsWith(strength: 99, interiorDefense: 99);

    expect(strongInside.overall, greaterThan(baseline.overall));
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
