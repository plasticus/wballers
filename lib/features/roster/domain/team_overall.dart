import '../../player/domain/player.dart';
import 'roster_membership.dart';
import 'roster_status.dart';

/// The weight the player at [rank] (1-indexed position in the active
/// roster's own list order -- the same "rank" `target_minutes.dart`'s
/// `targetMinutesForRank` already uses for actual target playing time)
/// contributes to [teamOverallForPlayers] -- a direct GM ask (2026-08-10,
/// `Aug9bugs.md` #12): "instead of an average of their entire roster,
/// maybe it needs to be weighted a bit," so a deep reserve doesn't drag a
/// team's rating down (or a lucky one inflate it) as much as someone who
/// actually plays real minutes. The GM's own proposed bands overlapped
/// (1-6 and 5-8 both claimed ranks 5-6); resolved here as four
/// non-overlapping tiers -- starters-and-first-bench-wave at full weight,
/// the next 2 spots at 80%, the rest of the 12-man active roster at 60%,
/// and (defensively, though the active-roster cap means this shouldn't
/// come up in practice) anyone past rank 12 at zero.
///
/// Exported (was private) so `matchup/domain/matchup_analysis.dart`'s
/// `teamFieldGroupRating` -- the pre-game screen's Offense/Defense/
/// Physical comparison -- can reuse the exact same weighting instead of
/// duplicating this table a second time.
double weightForRosterRank(int rank) {
  if (rank <= 6) return 1.0;
  if (rank <= 8) return 0.8;
  if (rank <= 12) return 0.6;
  return 0.0;
}

/// A team's overall rating: a rank-weighted mean of the active roster's
/// individual [PlayerRatings.overall] values ([weightForRosterRank]), rounded
/// to the nearest whole number -- "how good is this team" at a glance,
/// per the GM's own framing (`0B_Planned.md`'s team-overall-rebalance
/// entry). Active-roster players only, matching the scope the star-tier
/// legality caps use (`roster_legality.dart`) -- developmental and
/// reserve/inactive players aren't part of a team's on-court identity.
/// Returns `0` for an empty active roster rather than dividing by zero.
int teamOverall(List<RosterMembership> roster) {
  final active = roster.where((m) => m.status == RosterStatus.active);
  return teamOverallForPlayers([for (final m in active) m.player]);
}

/// Same rank-weighted-mean-of-overalls formula as [teamOverall], for
/// callers that already have a plain active-roster [Player] list in hand
/// rather than [RosterMembership]s -- `franchise_rosters.dart`'s
/// `rostersByAbbreviation` (already filtered to active players, in the
/// same roster-list order [weightForRosterRank] assumes) is the main one, used
/// anywhere a game-preview or result screen wants to show both teams'
/// strength. [players]' *list order* is what "rank" means here -- not a
/// re-sort by rating -- since that's the same order Bench Order edits and
/// `target_minutes.dart` reads target minutes from: a team's strength
/// should reflect who actually plays, not just its 6 best players
/// regardless of whether they're on the floor.
int teamOverallForPlayers(List<Player> players) {
  if (players.isEmpty) return 0;
  var weightedSum = 0.0;
  var totalWeight = 0.0;
  for (var i = 0; i < players.length; i++) {
    final weight = weightForRosterRank(i + 1);
    weightedSum += players[i].ratings.overall * weight;
    totalWeight += weight;
  }
  return totalWeight == 0 ? 0 : (weightedSum / totalWeight).round();
}
