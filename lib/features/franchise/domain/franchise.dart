import '../../coach/domain/coach.dart';
import '../../league/domain/team.dart';
import '../../roster/domain/roster_membership.dart';

/// The player's save-game: one club, its coach, and its roster. This is
/// the save-game root — `franchise_json.dart` is what actually goes
/// through `SaveEnvelope`/`SaveRepository`.
///
/// [team] is the club's own identity (name/colors/city), chosen at
/// onboarding — not a reference into `kInitialLeagueTeams`. Which of the
/// 20 original teams this franchise notionally "replaced" in the league is
/// bookkeeping that belongs to a future `League` concept (Phase 2's
/// season/schedule work), not to Franchise itself.
///
/// Roster legality isn't enforced here — see `evaluateFranchiseLegality`.
class Franchise {
  const Franchise({
    required this.id,
    required this.team,
    required this.coach,
    required this.roster,
    required this.simulationSeed,
  });

  /// Stable identifier for this save, independent of [team]'s name (which
  /// the coach could rebrand later).
  final String id;

  final Team team;
  final Coach coach;
  final List<RosterMembership> roster;

  /// Seeds every deterministic random source this franchise's simulation
  /// uses — same seed plus same saved state must reproduce the same
  /// results.
  final int simulationSeed;
}
