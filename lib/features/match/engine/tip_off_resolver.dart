import 'dart:math';

import '../../player/domain/player.dart';
import 'contest_resolver.dart';

/// How much each inch of height counts toward a jumper's tip-off score,
/// relative to the 1-99 scale everything else on [Player.ratings] lives
/// on -- deliberately large so height dominates the check the way a real
/// jump ball does, with strength and interior skill as secondary factors
/// rather than co-equal ones. An initial guess, not yet empirically tuned
/// (same caveat as every other freshly-added simulation constant here).
const _heightWeight = 8;

int _jumpScore(Player player) {
  final skill =
      (player.ratings.interiorOffense + player.ratings.interiorDefense) ~/ 2;
  return player.heightInches * _heightWeight + player.ratings.strength + skill;
}

/// Resolves a jump ball between [teamAJumper] and [teamBJumper] via the
/// shared [resolveContest] curve, fed a height-dominated score per player
/// (`_jumpScore`) rather than a raw rating. Returns `true` if
/// [teamAJumper] wins the tip.
bool resolveTipOff(Random random, Player teamAJumper, Player teamBJumper) {
  return resolveContest(
    random,
    attackerRating: _jumpScore(teamAJumper),
    defenderRating: _jumpScore(teamBJumper),
    steepness: 0.06,
  );
}
