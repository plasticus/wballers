import 'dart:math';

import '../../player/domain/player.dart';
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

/// Assigns [player] a jersey number that doesn't collide with anyone
/// already in [existingRoster] -- for adding a single new player (a
/// free-agent signing, `current_franchise_provider.dart`'s
/// `signFreeAgent`) without reshuffling the numbers every other player on
/// the roster already has, unlike [assignJerseyNumbers]'s whole-roster
/// pass. Deterministic for a given [random] stream.
Player assignJerseyNumberAvoiding(
  Random random,
  Player player,
  List<RosterMembership> existingRoster,
) {
  final taken = {
    for (final membership in existingRoster)
      if (membership.player.jerseyNumber != null)
        membership.player.jerseyNumber!,
  };
  final available = [
    for (var n = _minJerseyNumber; n <= _maxJerseyNumber; n++)
      if (!taken.contains(n)) n,
  ]..shuffle(random);
  return player.copyWithJerseyNumber(available.first);
}
