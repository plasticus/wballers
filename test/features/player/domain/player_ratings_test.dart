import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

const _base = (
  inside: 50,
  outside: 50,
  playmaking: 50,
  ballHandling: 50,
  defense: 50,
  rebounding: 50,
  athleticism: 50,
  stamina: 50,
  discipline: 50,
  potential: 50,
);

PlayerRatings _ratingsWith({int? inside, int? potential}) {
  return PlayerRatings(
    inside: inside ?? _base.inside,
    outside: _base.outside,
    playmaking: _base.playmaking,
    ballHandling: _base.ballHandling,
    defense: _base.defense,
    rebounding: _base.rebounding,
    athleticism: _base.athleticism,
    stamina: _base.stamina,
    discipline: _base.discipline,
    potential: potential ?? _base.potential,
  );
}

void main() {
  test('overall averages the nine current-ability ratings', () {
    final ratings = _ratingsWith();

    expect(ratings.overall, 50);
  });

  test('overall excludes potential entirely', () {
    final lowPotential = _ratingsWith(potential: 1);
    final highPotential = _ratingsWith(potential: 99);

    expect(lowPotential.overall, highPotential.overall);
  });

  test('overall reflects a change to a current-ability rating', () {
    final ratings = _ratingsWith(inside: 99);

    expect(ratings.overall, greaterThan(50));
  });

  test('rejects a rating of 0', () {
    expect(() => _ratingsWith(inside: 0), throwsA(isA<AssertionError>()));
  });

  test('rejects a rating of 100', () {
    expect(() => _ratingsWith(inside: 100), throwsA(isA<AssertionError>()));
  });

  test('accepts the 1-99 bounds', () {
    expect(() => _ratingsWith(inside: 1), returnsNormally);
    expect(() => _ratingsWith(inside: 99), returnsNormally);
  });
}
