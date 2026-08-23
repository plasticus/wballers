import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/domain/scheduled_game.dart' show GameType;
import '../../season/domain/season_progress.dart' show nextGameDayTypes;
import 'franchise.dart';

/// Splits [franchise]'s roster by [RosterStatus] and checks it against the
/// active-roster and developmental-roster rules. Reserve/Inactive members
/// are excluded entirely — they're unconstrained by design.
RosterLegality evaluateFranchiseLegality(Franchise franchise) {
  final active = franchise.roster
      .where((membership) => membership.status == RosterStatus.active)
      .map((membership) => membership.player)
      .toList();
  final developmental = franchise.roster
      .where((membership) => membership.status == RosterStatus.developmental)
      .map((membership) => membership.player)
      .toList();

  return evaluateRosterLegality(active: active, developmental: developmental);
}

/// Whether [franchise]'s own roster is currently illegal *and* the very
/// next game day would move play out of the preseason -- the real gate
/// `current_franchise_provider.dart`'s `advanceGameDay` checks, replacing
/// the season-2-crash auto-waive `draft_advancer.dart`'s `finalizeDraft`
/// used to force on the GM's own team (2026-08-23, a direct GM design
/// call following a report the auto-waive itself was unwelcome: "you can
/// roll an illegal roster through preseason, then you get another
/// warning, and if your roster is illegal before game 1, it won't let
/// you play the game until you drop/trade players and make it legal").
///
/// Preseason itself is always playable regardless of legality -- an
/// over-cap roster still simulates fine there
/// (`substitution_policy.dart`'s `targetMinutesForOrderedRoster` benches
/// whoever's past the top 12 rather than crashing); this only blocks the
/// transition into anything else (the regular season, the Continental
/// Cup, the postseason, All-Star weekend) while the roster is still
/// illegal. `false` once the season is fully played out
/// ([nextGameDayTypes] empty) -- nothing left to block.
bool blockedByIllegalActiveRoster(Franchise franchise) {
  final nextTypes = nextGameDayTypes(franchise.seasonProgress);
  if (nextTypes.isEmpty) return false;
  if (nextTypes.every((type) => type == GameType.preseason)) return false;
  return !evaluateFranchiseLegality(franchise).isLegal;
}
