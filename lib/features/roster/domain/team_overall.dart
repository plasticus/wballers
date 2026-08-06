import 'roster_membership.dart';
import 'roster_status.dart';

/// A team's overall rating: the unweighted mean of the active roster's
/// individual [PlayerRatings.overall] values, rounded to the nearest
/// whole number -- "how good is this team" at a glance, per the GM's own
/// framing (`0B_Planned.md`'s team-overall-rebalance entry). Active-roster
/// players only, matching the scope the star-tier legality caps use
/// (`roster_legality.dart`) -- developmental and reserve/inactive players
/// aren't part of a team's on-court identity. Returns `0` for an empty
/// active roster rather than dividing by zero.
int teamOverall(List<RosterMembership> roster) {
  final active = roster.where((m) => m.status == RosterStatus.active);
  if (active.isEmpty) return 0;
  var count = 0;
  var sum = 0;
  for (final membership in active) {
    sum += membership.player.ratings.overall;
    count++;
  }
  return (sum / count).round();
}
