import '../../franchise/domain/franchise.dart';
import '../../league/domain/league.dart';
import '../../roster/domain/roster_membership.dart';

/// Advances every player in [franchise]'s league one season older -- the
/// GM's own roster and all 19 AI rosters alike, every `RosterStatus`
/// included (unlike training/decline, aging isn't gated by playing time
/// or roster slot -- a reserve/inactive player still turns a year older).
/// `0D_Season_2_Roadmap.md`'s Aging & roster churn stage (2026-08-11):
/// confirmed by search that nothing anywhere incremented `Player.age`/
/// `yearsOfService` before this, so "Rookie" never stopped being true for
/// anyone. Pure mutation, no `Random` stream --
/// [Player.copyWithSeasonAdvanced]'s increment is deterministic by
/// construction.
///
/// Meant to be called once per season, alongside every other season-end
/// resolution (`training_advancer.dart`'s `resolveSeasonEndAging`/
/// `resolveAiTeamSeasonTraining`, `coach_free_agency_advancer.dart`'s
/// `resolveCoachFreeAgency`) -- and, critically, called *after* all of
/// them: those all compute their result against the age a player played
/// the season *at*, and incrementing first would silently shift every one
/// of those computations onto the wrong age band a year early.
Franchise advancePlayerTenure(Franchise franchise) {
  final newRoster = [
    for (final membership in franchise.roster)
      RosterMembership(
        player: membership.player.copyWithSeasonAdvanced(),
        status: membership.status,
      ),
  ];
  final newAiTeams = [
    for (final aiTeam in franchise.league.aiTeams)
      aiTeam.copyWithRoster([
        for (final membership in aiTeam.roster)
          RosterMembership(
            player: membership.player.copyWithSeasonAdvanced(),
            status: membership.status,
          ),
      ]),
  ];
  return franchise
      .copyWithRoster(newRoster)
      .copyWithLeague(League(aiTeams: newAiTeams));
}
