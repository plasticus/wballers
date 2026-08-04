import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';
import 'package:womensbballmgr/features/roster/persistence/starting_lineup_json.dart';

void main() {
  test(
    'startingLineupToJson/startingLineupFromJson round-trips every slot',
    () {
      final original = const StartingLineup(
        startersByPosition: {
          Position.pointGuard: 'p1',
          Position.shootingGuard: 'p2',
          Position.smallForward: 'p3',
          Position.powerForward: 'p4',
          Position.center: 'p5',
        },
      );

      final restored = startingLineupFromJson(startingLineupToJson(original));

      expect(restored.startersByPosition, original.startersByPosition);
    },
  );

  test('round-trips a partially-filled lineup', () {
    final original = const StartingLineup(
      startersByPosition: {Position.pointGuard: 'p1'},
    );

    final restored = startingLineupFromJson(startingLineupToJson(original));

    expect(restored.startersByPosition, {Position.pointGuard: 'p1'});
  });
}
