import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_status.dart';

/// Seed offset for the Player Market's one still-preview-only tab (keeps
/// its stream from correlating with any other -- coach=0, roster=1,
/// league draw=2, league AI rosters=3, season schedule=4, game-day
/// advancement=5, postseason=6, training coaches=7, training
/// advancement=8, free-agent pool=12, see
/// `roster/generation/free_agent_pool_generator.dart`). Re-derived fresh
/// from `franchise.simulationSeed` every time the screen builds rather
/// than persisted -- there's nothing real behind it yet (see the doc
/// comment below), so there's nothing worth saving. The Draft tab isn't
/// part of this file anymore -- it shows `Franchise.upcomingDraftClass`
/// directly now, real persisted state, not a preview (2026-08-21).
const kTradeBlockPreviewSeedOffset = 10;

/// How many picks the Trade Block preview tab shows -- enough to feel
/// like a real pool without turning the screen into a second roster
/// screen.
const kPlayerMarketPreviewCount = 10;

/// Players flagged for trade -- for `PlayerMarketScreen`'s Trade Block
/// tab, **preview only**: there is no trade-block system wired to
/// `Franchise` yet (`0B_Planned.md`'s Trade System entry). Nothing
/// generated here is tradeable -- it's flavor data regenerated fresh from
/// the franchise's own `simulationSeed` every time the screen opens, not
/// real game state. Deterministic per franchise (same seed always shows
/// the same preview), but explicitly not persisted, since persisting a
/// preview with no mechanical backing would just be schema debt for a
/// real system to later rip out.

/// One active player from each of up to [count] distinct AI teams,
/// randomly picked -- flavor "rumored available" players, not a real
/// trade-block system (no valuation, no GM-side flagging, nothing
/// tradeable). Draws only from rosters `franchise.league` already
/// generated, so unlike [generateFreeAgentPreview] this needs no new
/// player generation at all, just a selection.
List<({Player player, Team team})> pickTradeBlockPreview(
  Franchise franchise,
  Random random, {
  int count = kPlayerMarketPreviewCount,
}) {
  final shuffledTeams = [...franchise.league.aiTeams]..shuffle(random);
  final picks = <({Player player, Team team})>[];
  for (final aiTeam in shuffledTeams) {
    if (picks.length >= count) break;
    final active = [
      for (final membership in aiTeam.roster)
        if (membership.status == RosterStatus.active) membership.player,
    ];
    if (active.isEmpty) continue;
    picks.add((
      player: active[random.nextInt(active.length)],
      team: aiTeam.team,
    ));
  }
  return picks;
}
