import '../../coach/domain/coach.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/starting_lineup.dart';

/// The player's save-game: their General Manager persona, their club, its
/// hired coach, its roster, and its starting lineup. This is the save-game
/// root — `franchise_json.dart` is what actually goes through
/// `SaveEnvelope`/`SaveRepository`.
///
/// The player is the GM, not [coach] — see the note on [Coach]. [team] is
/// the club's own identity (name/colors/city), chosen at onboarding — not
/// a reference into `kLeagueTeamPool`. [simulationSeed] also determines
/// which 20 of the pool's 40 candidate teams actually exist in this
/// playthrough's league (`drawLeagueTeams`, `league_draw.dart`). Which of
/// those 20 this franchise replaced is captured separately, in
/// [replacedTeamAbbreviation] -- picked at onboarding, defaulting to a
/// random team in the chosen conference but GM-overridable. `LeagueScreen`
/// uses it to substitute [team] in for the replaced original in the league
/// listing, so the displayed league genuinely reads as 19 AI teams + 1 GM
/// team. [league] is those 19 AI teams' real generated rosters
/// (`generateLeague`) -- a real league runtime, not just identities.
///
/// Roster legality isn't enforced here — see `evaluateFranchiseLegality`.
/// Lineup legality isn't enforced here either — see `evaluateLineupLegality`.
class Franchise {
  Franchise({
    required this.id,
    required this.gmName,
    required this.team,
    required this.coach,
    required this.roster,
    required this.startingLineup,
    required this.simulationSeed,
    required this.replacedTeamAbbreviation,
    required this.league,
  }) : assert(
         _replacedTeamIsInSameConference(team, replacedTeamAbbreviation),
         'replacedTeamAbbreviation must be one of the league team pool, '
         'in the same conference as team',
       ),
       assert(
         !league.aiTeams.any(
           (aiTeam) => aiTeam.team.abbreviation == replacedTeamAbbreviation,
         ),
         'league.aiTeams must not include the team the GM replaced',
       );

  /// Stable identifier for this save, independent of [team]'s name (which
  /// the GM could rebrand later).
  final String id;

  /// The player's own name — they're the General Manager, not [coach].
  final String gmName;

  final Team team;
  final Coach coach;
  final List<RosterMembership> roster;
  final StartingLineup startingLineup;

  /// Seeds every deterministic random source this franchise's simulation
  /// uses — same seed plus same saved state must reproduce the same
  /// results.
  final int simulationSeed;

  /// The `kLeagueTeamPool` abbreviation this franchise replaced.
  /// Bookkeeping only for now -- see the class doc comment.
  final String replacedTeamAbbreviation;

  /// The other 19 teams in this playthrough's league, with real generated
  /// rosters -- see the class doc comment and `generateLeague`.
  final League league;

  /// Returns a copy with [startingLineup] replaced -- the only field the
  /// lineup editor needs to change.
  Franchise copyWithLineup(StartingLineup newLineup) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      startingLineup: newLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
    );
  }

  /// Returns a copy with [newCoach] replacing [coach] -- the portrait
  /// editor's coach-appearance path.
  Franchise copyWithCoach(Coach newCoach) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: newCoach,
      roster: roster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
    );
  }

  /// Returns a copy with [newRoster] replacing [roster] -- the portrait
  /// editor's player-appearance path.
  Franchise copyWithRoster(List<RosterMembership> newRoster) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: newRoster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
    );
  }
}

bool _replacedTeamIsInSameConference(
  Team team,
  String replacedTeamAbbreviation,
) {
  return kLeagueTeamPool.any(
    (t) =>
        t.abbreviation == replacedTeamAbbreviation &&
        t.conference == team.conference,
  );
}
