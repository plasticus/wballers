import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/achievement.dart';
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

/// One [Achievement] actually won this season, plus who won it and which
/// team they play for -- [SeasonRecapScreen]'s real "Season Awards"
/// ceremony section reads this to show what just happened.
class SeasonAwardWinner {
  const SeasonAwardWinner({
    required this.achievement,
    required this.player,
    required this.teamAbbreviation,
  });

  final Achievement achievement;
  final Player player;

  /// `null` only in the unlikely case a winner ended up a free agent by
  /// the time this is read -- a roster-legality trim or a coach firing
  /// can't cause that, but nothing structurally prevents it either, so
  /// this stays nullable rather than assuming it can't happen.
  final String? teamAbbreviation;
}

/// Every award actually won this season, derived fresh from every
/// player's own [Player.achievements] rather than any separately-tracked
/// "last season's winners" list -- [Franchise.season] is the filter
/// (matches [PlayerAchievementRecord.season]), same "always re-derive,
/// nothing cached" posture [currentStandings]/[computeLeagueLeaders]
/// already use. [Achievement.allStarMvp] shows up here too, since it's
/// granted mid-season with that same season number -- the roadmap's own
/// framing for a real ceremony ("champion, awards, nicknames earned...
/// in one batch moment") never distinguished mid-season from
/// end-of-season awards.
///
/// Searches every player in the league regardless of where they ended up
/// -- the GM's own roster, every AI team's, and [Franchise.freeAgents]
/// -- so a winner who got waived in the very same season-end pipeline
/// call that granted their award still shows up, just with a `null`
/// [SeasonAwardWinner.teamAbbreviation].
///
/// Ordered by [Achievement]'s own declaration order (League MVP first,
/// Rookie of the Year last) -- a fixed, sensible-enough presentation
/// order without needing a second, hand-maintained ranking to keep in
/// sync with the enum.
List<SeasonAwardWinner> seasonAwardWinners(Franchise franchise) {
  final winners = <SeasonAwardWinner>[];

  void scan(List<Player> players, String? teamAbbreviation) {
    for (final player in players) {
      for (final record in player.achievements) {
        if (record.season != franchise.season) continue;
        winners.add(
          SeasonAwardWinner(
            achievement: record.achievement,
            player: player,
            teamAbbreviation: teamAbbreviation,
          ),
        );
      }
    }
  }

  scan([
    for (final membership in franchise.roster) membership.player,
  ], franchise.team.abbreviation);
  for (final aiTeam in franchise.league.aiTeams) {
    scan([
      for (final membership in aiTeam.roster) membership.player,
    ], aiTeam.team.abbreviation);
  }
  scan(franchise.freeAgents, null);

  winners.sort(
    (a, b) => Achievement.values
        .indexOf(a.achievement)
        .compareTo(Achievement.values.indexOf(b.achievement)),
  );
  return winners;
}
