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

  test('skillPoints is the raw sum overall rounds from -- 50 across all '
      '12 fields sums to exactly 600', () {
    expect(_ratingsWith().skillPoints, 600);
  });

  test('skillPoints excludes potential, same as overall', () {
    final lowPotential = _ratingsWith(potential: 1);
    final highPotential = _ratingsWith(potential: 99);
    expect(lowPotential.skillPoints, highPotential.skillPoints);
  });

  test(
    '2 players can share the same overall while having different '
    'skillPoints -- the whole reason this getter exists (trade_value.dart)',
    () {
      // Deliberately construct 2 distinct totals that round to the same
      // overall: 594 and 605 both round to 50 (594/12=49.5, 605/12=50.4).
      final a = PlayerRatings(
        speed: 49,
        agility: 49,
        strength: 49,
        stamina: 49,
        ballControl: 49,
        passing: 50,
        interiorOffense: 50,
        perimeterOffense: 50,
        perimeterDefense: 50,
        interiorDefense: 50,
        disruption: 50,
        blocking: 49,
        potential: 50,
      );
      final b = PlayerRatings(
        speed: 51,
        agility: 51,
        strength: 51,
        stamina: 51,
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
      expect(a.overall, 50);
      expect(b.overall, 50);
      expect(a.skillPoints, isNot(b.skillPoints));
    },
  );

  test('rejects a rating of 100', () {
    expect(() => _ratingsWith(strength: 100), throwsA(isA<AssertionError>()));
  });

  test('accepts the 1-99 bounds', () {
    expect(() => _ratingsWith(strength: 1), returnsNormally);
    expect(() => _ratingsWith(strength: 99), returnsNormally);
  });

  test('physicalOverall averages only the four physical ratings', () {
    final baseline = _ratingsWith();
    final strongInside = _ratingsWith(strength: 99, interiorDefense: 99);

    // strength is physical, interiorDefense is not -- only strength should
    // move physicalOverall.
    expect(strongInside.physicalOverall, greaterThan(baseline.physicalOverall));
    expect(strongInside.physicalOverall, lessThan(99));
  });

  test('offenseOverall averages only the four offensive ratings', () {
    final baseline = _ratingsWith();
    final strongOffense = _ratingsWith(interiorOffense: 99);

    expect(strongOffense.offenseOverall, greaterThan(baseline.offenseOverall));
    expect(strongOffense.defenseOverall, baseline.defenseOverall);
  });

  test(
    'defenseOverall averages only the four defensive/playmaking ratings',
    () {
      final baseline = _ratingsWith();
      final strongDefense = _ratingsWith(interiorDefense: 99);

      expect(
        strongDefense.defenseOverall,
        greaterThan(baseline.defenseOverall),
      );
      expect(strongDefense.offenseOverall, baseline.offenseOverall);
    },
  );
}
