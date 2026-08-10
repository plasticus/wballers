import 'dart:math';

import '../../player/domain/player.dart';
import '../domain/roster_membership.dart';

/// Valid jersey numbers, 0-99 (real basketball's usual range) --
/// 100 candidates, always at least enough for a 12-player roster.
const _minJerseyNumber = 0;
const _maxJerseyNumber = 99;

/// Numbers that never come out of auto-generation, league-wide (TODO.md
/// item 9, full GM spec) -- no in-game explanation needed, still freely
/// hand-assignable when a GM edits a player directly; only generation
/// avoids them. "00" isn't a distinct value from "0" in this codebase's
/// plain 0-99 [Player.jerseyNumber], so banning 0 covers it.
const _bannedAutoGenNumbers = {0, 69, 88};

enum _PositionGroup { guard, forward, center }

_PositionGroup _groupFor(Position position) => switch (position) {
  Position.pointGuard || Position.shootingGuard => _PositionGroup.guard,
  Position.smallForward || Position.powerForward => _PositionGroup.forward,
  Position.center => _PositionGroup.center,
};

/// Position-typical ranges, GM spec: Guards mostly 0-5 and low teens,
/// Forwards mostly 20s/30s, Centers mostly high-teens and 30s/40s. Guard's
/// range already excludes 0 (see [_bannedAutoGenNumbers]) -- the only one
/// of the three ranges that would otherwise have overlapped a banned
/// number.
final Map<_PositionGroup, List<int>> _typicalNumbers = {
  _PositionGroup.guard: [1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15],
  _PositionGroup.forward: [for (var n = 20; n <= 39; n++) n],
  _PositionGroup.center: [16, 17, 18, 19, for (var n = 30; n <= 49; n++) n],
};

/// A secondary "common outlier" pool that shows up somewhat more than
/// pure chance would suggest, any position (GM spec, exact list).
const _commonOutlierNumbers = [
  44,
  55,
  66,
  77,
  99,
  91,
  41,
  42,
  40,
  50,
  60,
  70,
  80,
  90,
];

/// {typical, outlier} weights per position group -- the remainder falls
/// to "anything else" ([_allValidNumbers]). GM's own starting split,
/// explicitly open to tuning: Guards/Forwards 85/10/5, Centers 70/15/15
/// (the loosest of the three, per the GM's own framing -- Centers are
/// "the position most likely to land outside the common ranges").
final Map<_PositionGroup, (double typical, double outlier)> _categorySplit = {
  _PositionGroup.guard: (0.85, 0.10),
  _PositionGroup.forward: (0.85, 0.10),
  _PositionGroup.center: (0.70, 0.15),
};

List<int> _allValidNumbers() => [
  for (var n = _minJerseyNumber; n <= _maxJerseyNumber; n++)
    if (!_bannedAutoGenNumbers.contains(n)) n,
];

/// Rolls one jersey number for [position]: which of the 3 pools above to
/// draw from (per [_categorySplit]), then a specific untaken number
/// within it. Falls back to any untaken valid number if the rolled
/// pool's already fully claimed by [taken] -- never actually reachable at
/// a 12-player roster (even the smallest pool, the 14-number outlier
/// list, comfortably covers a full active roster on its own), but a
/// structural guarantee beats an unhandled empty-list crash if a future
/// caller ever assigns a much bigger group at once.
int _rollJerseyNumber(Random random, Position position, Set<int> taken) {
  final group = _groupFor(position);
  final (typicalWeight, outlierWeight) = _categorySplit[group]!;
  final roll = random.nextDouble();
  final pool = roll < typicalWeight
      ? _typicalNumbers[group]!
      : roll < typicalWeight + outlierWeight
      ? _commonOutlierNumbers
      : _allValidNumbers();

  var available = pool.where((n) => !taken.contains(n)).toList();
  if (available.isEmpty) {
    available = _allValidNumbers().where((n) => !taken.contains(n)).toList();
  }
  return available[random.nextInt(available.length)];
}

/// Assigns every player in [roster] a unique jersey number, following
/// real positional trends rather than flat-random (TODO.md item 9).
/// Deterministic for a given [random] stream. Returns a new list --
/// [roster] itself isn't mutated, same pattern as `distributeTraits`.
List<RosterMembership> assignJerseyNumbers(
  Random random,
  List<RosterMembership> roster,
) {
  final taken = <int>{};
  final result = <RosterMembership>[];
  for (final membership in roster) {
    final number = _rollJerseyNumber(
      random,
      membership.player.primaryPosition,
      taken,
    );
    taken.add(number);
    result.add(
      RosterMembership(
        player: membership.player.copyWithJerseyNumber(number),
        status: membership.status,
      ),
    );
  }
  return result;
}

/// Assigns [player] a jersey number that doesn't collide with anyone
/// already in [existingRoster] -- for adding a single new player (a
/// free-agent signing, `current_franchise_provider.dart`'s
/// `signFreeAgent`) without reshuffling the numbers every other player on
/// the roster already has, unlike [assignJerseyNumbers]'s whole-roster
/// pass. Follows the same positional-trend weighting. Deterministic for a
/// given [random] stream.
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
  final number = _rollJerseyNumber(random, player.primaryPosition, taken);
  return player.copyWithJerseyNumber(number);
}
