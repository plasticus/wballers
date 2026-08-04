import '../../player/domain/player.dart';
import 'roster_membership.dart';
import 'roster_status.dart';

/// One player id per position. A player fills a slot if it's their
/// [Player.primaryPosition] or one of their [Player.secondaryPositions] --
/// a combo guard can start at either PG or SG.
class StartingLineup {
  const StartingLineup({required this.startersByPosition});

  /// A reasonable default, not necessarily optimal: the best-`overall`
  /// eligible player at each position, in `Position.values` order, each
  /// player excluded from consideration once assigned so the same player
  /// can't fill two slots. The GM can (and should) adjust from here.
  factory StartingLineup.bestAvailable(List<RosterMembership> roster) {
    final active = roster
        .where((membership) => membership.status == RosterStatus.active)
        .toList();
    final startersByPosition = <Position, String>{};
    final assignedPlayerIds = <String>{};

    for (final position in Position.values) {
      final eligible = active.where(
        (membership) =>
            !assignedPlayerIds.contains(membership.player.id) &&
            isEligible(membership.player, position),
      );
      if (eligible.isEmpty) continue;

      final best = eligible.reduce(
        (a, b) => a.player.ratings.overall >= b.player.ratings.overall ? a : b,
      );
      startersByPosition[position] = best.player.id;
      assignedPlayerIds.add(best.player.id);
    }

    return StartingLineup(startersByPosition: startersByPosition);
  }

  final Map<Position, String> startersByPosition;

  static bool isEligible(Player player, Position position) {
    return player.primaryPosition == position ||
        player.secondaryPositions.contains(position);
  }
}
