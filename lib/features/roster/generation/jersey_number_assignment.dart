import 'dart:math';

import '../domain/roster_membership.dart';

/// Valid jersey numbers, 0-99 (real basketball's usual range) --
/// 100 candidates, always at least enough for a 12-player roster.
const _minJerseyNumber = 0;
const _maxJerseyNumber = 99;

/// Assigns every player in [roster] a unique jersey number, 0-99.
/// Deterministic for a given [random] stream. Returns a new list --
/// [roster] itself isn't mutated, same pattern as `distributeTraits`.
List<RosterMembership> assignJerseyNumbers(
  Random random,
  List<RosterMembership> roster,
) {
  final available = List<int>.generate(
    _maxJerseyNumber - _minJerseyNumber + 1,
    (i) => _minJerseyNumber + i,
  )..shuffle(random);

  return [
    for (var i = 0; i < roster.length; i++)
      RosterMembership(
        player: roster[i].player.copyWithJerseyNumber(available[i]),
        status: roster[i].status,
      ),
  ];
}
