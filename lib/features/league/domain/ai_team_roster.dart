import '../../coach/domain/coach.dart';
import '../../roster/domain/roster_membership.dart';
import 'team.dart';

/// One AI-controlled team's identity, generated roster, and generated
/// head coach. The GM's own club isn't one of these -- see
/// `Franchise.team`/`Franchise.roster`/`Franchise.coach`.
class AiTeamRoster {
  const AiTeamRoster({
    required this.team,
    required this.roster,
    required this.coach,
    this.coachHiredSeason = 0,
  });

  final Team team;
  final List<RosterMembership> roster;
  final Coach coach;

  /// The [Franchise.season] this team's current [coach] was hired --
  /// defaults to 0 (every team's original coach, generated at league
  /// creation, "hired" the same moment the franchise itself was).
  /// [coach_free_agency_advancer.dart]'s grace-period check reads this:
  /// a coach isn't eligible to be fired until
  /// `Franchise.season - coachHiredSeason` clears
  /// `kCoachGracePeriodSeasons`.
  final int coachHiredSeason;

  /// A copy with [newRoster] replacing [roster] -- every other field
  /// (including [coach]/[coachHiredSeason]) carried over untouched. What
  /// every "rebuild this team's roster after training/an achievement"
  /// call site uses, so none of them need to remember to thread the coach
  /// through by hand.
  AiTeamRoster copyWithRoster(List<RosterMembership> newRoster) {
    return AiTeamRoster(
      team: team,
      roster: newRoster,
      coach: coach,
      coachHiredSeason: coachHiredSeason,
    );
  }

  /// A copy with [newCoach] replacing [coach] and [coachHiredSeason] reset
  /// to [hiredSeason] -- what firing and immediately replacing a coach
  /// (`coach_free_agency_advancer.dart`) uses.
  AiTeamRoster copyWithCoach({
    required Coach newCoach,
    required int hiredSeason,
  }) {
    return AiTeamRoster(
      team: team,
      roster: roster,
      coach: newCoach,
      coachHiredSeason: hiredSeason,
    );
  }
}
