import '../../player/domain/player.dart';
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
  return teamOverallForPlayers([for (final m in active) m.player]);
}

/// Same mean-of-overalls formula as [teamOverall], for callers that
/// already have a plain active-roster [Player] list in hand rather than
/// [RosterMembership]s -- `franchise_rosters.dart`'s `rostersByAbbreviation`
/// (already filtered to active players) is the main one, used anywhere a
/// game-preview or result screen wants to show both teams' strength.
int teamOverallForPlayers(List<Player> players) {
  if (players.isEmpty) return 0;
  final sum = players.fold<int>(0, (total, p) => total + p.ratings.overall);
  return (sum / players.length).round();
}
