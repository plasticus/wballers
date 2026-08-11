import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';

/// Builds the `rostersByAbbreviation` map `advanceToNextGameDay` needs:
/// [franchise]'s own active roster plus every AI team's active roster,
/// keyed by `Team.abbreviation`. Only active-roster players are included
/// -- developmental/reserve players don't suit up (`roster_status.dart`),
/// same expectation `simulateMatch` has everywhere else it's called.
Map<String, List<Player>> rostersByAbbreviation(Franchise franchise) {
  return {
    franchise.team.abbreviation: _activePlayers(franchise.roster),
    for (final aiTeam in franchise.league.aiTeams)
      aiTeam.team.abbreviation: _activePlayers(aiTeam.roster),
  };
}

/// Every team in this playthrough's league -- [franchise]'s own club plus
/// all 19 AI teams. What `currentStandings`/`postseasonSeeds` need for
/// conference-aware tiebreaking and seeding.
List<Team> allLeagueTeams(Franchise franchise) {
  return [
    franchise.team,
    for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
  ];
}

/// Every active player's id mapped to the 3-letter abbreviation of the
/// team they actually play for -- built off the same [rostersByAbbreviation]
/// map, just inverted. What a report screen showing players from more than
/// one team at once (the All-Star Game and Skills Competition reports,
/// 2026-08-11 -- "in all the all-star reports, it needs to mention their
/// team after their name") needs to label who plays for whom, since a bare
/// name alone doesn't say it once players are mixed across teams.
Map<String, String> teamAbbreviationByPlayerId(Franchise franchise) {
  return {
    for (final entry in rostersByAbbreviation(franchise).entries)
      for (final player in entry.value) player.id: entry.key,
  };
}

/// [franchise]'s own [Franchise.team] if [abbreviation] matches it,
/// otherwise whichever of [Franchise.league]'s 19 AI teams matches --
/// every abbreviation a [ScheduledGame] can reference is one or the
/// other. Throws (via [Iterable.firstWhere]) on an abbreviation from
/// outside this playthrough's league, which shouldn't happen.
Team teamByAbbreviation(Franchise franchise, String abbreviation) {
  if (franchise.team.abbreviation == abbreviation) return franchise.team;
  return franchise.league.aiTeams
      .firstWhere((aiTeam) => aiTeam.team.abbreviation == abbreviation)
      .team;
}

List<Player> _activePlayers(List<RosterMembership> roster) {
  return [
    for (final membership in roster)
      if (membership.status == RosterStatus.active) membership.player,
  ];
}
