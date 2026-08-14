import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/matchup/domain/offense_shape.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

Player _player(String id, Position position, {int overall = 70}) {
  return Player(
    id: id,
    name: 'Player $id',
    age: 25,
    yearsOfService: 3,
    hometown: 'Testville',
    primaryPosition: position,
    handedness: Handedness.right,
    biography: '',
    heightInches: 70,
    archetype: kArchetypesByPosition[position]!.first,
    ratings: PlayerRatings(
      speed: overall,
      agility: overall,
      strength: overall,
      stamina: overall,
      ballControl: overall,
      passing: overall,
      interiorOffense: overall,
      perimeterOffense: overall,
      perimeterDefense: overall,
      interiorDefense: overall,
      disruption: overall,
      blocking: overall,
      potential: overall,
    ),
  );
}

void main() {
  group('detectOffenseShape', () {
    test('2 guards, 1 wing, 2 bigs is traditional', () {
      final five = [
        _player('a', Position.pointGuard),
        _player('b', Position.shootingGuard),
        _player('c', Position.smallForward),
        _player('d', Position.powerForward),
        _player('e', Position.center),
      ];
      expect(detectOffenseShape(five), OffenseShape.traditional);
    });

    test('0 or 1 bigs is pace & space', () {
      final noBigs = [
        _player('a', Position.pointGuard),
        _player('b', Position.shootingGuard),
        _player('c', Position.shootingGuard),
        _player('d', Position.smallForward),
        _player('e', Position.smallForward),
      ];
      expect(detectOffenseShape(noBigs), OffenseShape.paceAndSpace);

      final oneBig = [
        _player('a', Position.pointGuard),
        _player('b', Position.shootingGuard),
        _player('c', Position.smallForward),
        _player('d', Position.smallForward),
        _player('e', Position.powerForward),
      ];
      expect(detectOffenseShape(oneBig), OffenseShape.paceAndSpace);
    });

    test('3 or more bigs is post-up, regardless of the other 2 spots', () {
      final threeBigs = [
        _player('a', Position.pointGuard),
        _player('b', Position.smallForward),
        _player('c', Position.powerForward),
        _player('d', Position.powerForward),
        _player('e', Position.center),
      ];
      expect(detectOffenseShape(threeBigs), OffenseShape.postUp);

      final fiveBigs = [
        _player('a', Position.center),
        _player('b', Position.center),
        _player('c', Position.powerForward),
        _player('d', Position.powerForward),
        _player('e', Position.powerForward),
      ];
      expect(detectOffenseShape(fiveBigs), OffenseShape.postUp);
    });

    test('anything else -- no dominant group -- is motion', () {
      // 1 guard, 2 wings, 2 bigs: 2 bigs keeps it out of both
      // pace-&-space and post-up, but it isn't the exact 2-1-2 split
      // either.
      final mixed = [
        _player('a', Position.pointGuard),
        _player('b', Position.smallForward),
        _player('c', Position.smallForward),
        _player('d', Position.powerForward),
        _player('e', Position.center),
      ];
      expect(detectOffenseShape(mixed), OffenseShape.motion);

      // 3 guards, 0 wings, 2 bigs -- also 2 bigs, also not the exact
      // traditional split.
      final guardHeavy = [
        _player('a', Position.pointGuard),
        _player('b', Position.pointGuard),
        _player('c', Position.shootingGuard),
        _player('d', Position.powerForward),
        _player('e', Position.center),
      ];
      expect(detectOffenseShape(guardHeavy), OffenseShape.motion);
    });

    test('a short list still resolves gracefully rather than crashing', () {
      expect(detectOffenseShape(const []), OffenseShape.paceAndSpace);
      expect(
        detectOffenseShape([_player('a', Position.center)]),
        OffenseShape.paceAndSpace,
      );
    });
  });

  group('offenseBonusFor', () {
    test('traditional is the zero-everywhere baseline', () {
      final bonus = offenseBonusFor(OffenseShape.traditional);
      expect(bonus.interior, 0.0);
      expect(bonus.perimeter, 0.0);
      expect(bonus.passing, 0.0);
    });

    test('pace & space trades interior for perimeter (and a little '
        'passing)', () {
      final bonus = offenseBonusFor(OffenseShape.paceAndSpace);
      expect(bonus.interior, lessThan(0));
      expect(bonus.perimeter, greaterThan(0));
      expect(bonus.passing, greaterThan(0));
    });

    test('post-up is the mirror image of pace & space', () {
      final bonus = offenseBonusFor(OffenseShape.postUp);
      expect(bonus.interior, greaterThan(0));
      expect(bonus.perimeter, lessThan(0));
      expect(bonus.passing, 0.0);
    });

    test('motion keeps scoring neutral but rewards ball movement a '
        'little', () {
      final bonus = offenseBonusFor(OffenseShape.motion);
      expect(bonus.interior, 0.0);
      expect(bonus.perimeter, 0.0);
      expect(bonus.passing, greaterThan(0));
    });

    test('every bonus stays comfortably under the coach-bonus scale '
        '(+/-5%)', () {
      for (final shape in OffenseShape.values) {
        final bonus = offenseBonusFor(shape);
        for (final value in [bonus.interior, bonus.perimeter, bonus.passing]) {
          expect(value.abs(), lessThan(0.05));
        }
      }
    });
  });

  group('startingFiveByMinutes', () {
    test('picks the 5 highest-valued entries, regardless of map '
        'insertion order', () {
      final players = [
        for (var i = 0; i < 8; i++) _player('p$i', Position.center),
      ];
      final minutes = {
        players[0]: 4,
        players[1]: 30,
        players[2]: 8,
        players[3]: 30,
        players[4]: 6,
        players[5]: 30,
        players[6]: 26,
        players[7]: 26,
      };

      final five = startingFiveByMinutes(minutes);

      expect(five, hasLength(5));
      expect(five.toSet(), {
        players[1],
        players[3],
        players[5],
        players[6],
        players[7],
      });
    });

    test('an empty map resolves to an empty list', () {
      expect(startingFiveByMinutes(const {}), isEmpty);
    });
  });

  group('startingFiveFor', () {
    final players = [
      for (var i = 0; i < 8; i++)
        _player('p$i', Position.center, overall: 60 + i),
    ];

    test('bench-ordered: just the first 5 in list order, ignoring '
        'overall', () {
      final five = startingFiveFor(players, isBenchOrdered: true);
      expect(five, players.take(5).toList());
    });

    test('not bench-ordered: the 5 highest by overall, best first', () {
      final five = startingFiveFor(players, isBenchOrdered: false);
      expect(five.map((p) => p.id), ['p7', 'p6', 'p5', 'p4', 'p3']);
    });

    test('a short list still resolves gracefully', () {
      final short = players.take(2).toList();
      expect(startingFiveFor(short, isBenchOrdered: true), short);
      expect(startingFiveFor(short, isBenchOrdered: false), hasLength(2));
    });
  });
}
