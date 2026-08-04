import '../../coach/domain/coach.dart';
import '../../league/domain/initial_league.dart';
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
/// a reference into `kInitialLeagueTeams`. Which of the 20 original teams
/// this franchise replaced is captured separately, in
/// [replacedTeamAbbreviation] -- picked at onboarding, defaulting to a
/// random team in the chosen conference but GM-overridable. Actually
/// removing that team from the league (so only 19 AI teams remain) is
/// still a future `League` concept (Phase 2's season/schedule work); this
/// field is just the record of the GM's choice.
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
  }) : assert(
         _replacedTeamIsInSameConference(team, replacedTeamAbbreviation),
         'replacedTeamAbbreviation must be one of the 20 original teams, '
         'in the same conference as team',
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

  /// The `kInitialLeagueTeams` abbreviation this franchise replaced.
  /// Bookkeeping only for now -- see the class doc comment.
  final String replacedTeamAbbreviation;

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
    );
  }
}

bool _replacedTeamIsInSameConference(
  Team team,
  String replacedTeamAbbreviation,
) {
  return kInitialLeagueTeams.any(
    (t) =>
        t.abbreviation == replacedTeamAbbreviation &&
        t.conference == team.conference,
  );
}
