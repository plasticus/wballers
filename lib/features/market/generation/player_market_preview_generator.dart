import 'dart:math';

import '../../draft/domain/draft_prospect.dart';
import '../../draft/generation/draft_generator.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_status.dart';

/// Seed offsets for the Player Market's still-preview-only tabs -- keeps
/// each stream from correlating with any other (coach=0, roster=1,
/// league draw=2, league AI rosters=3, season schedule=4, game-day
/// advancement=5, postseason=6, training coaches=7, training
/// advancement=8, free-agent pool=12 -- see
/// `roster/generation/free_agent_pool_generator.dart`; the Free Agents
/// tab used to live here too, offset 9, before free agency became real,
/// persisted `Franchise` state instead of a screen-local preview). Both
/// re-derived fresh from `franchise.simulationSeed` every time the screen
/// builds rather than persisted -- there's nothing real behind either
/// yet (see the doc comment below), so there's nothing worth saving.
const kTradeBlockPreviewSeedOffset = 10;
const kDraftPreviewSeedOffset = 11;

/// How many prospects/picks each preview tab shows -- enough to feel like
/// a real pool without turning the screen into a second roster screen.
/// The Free Agents tab shows `Franchise.freeAgents` in full instead (real
/// state, not a preview slice of one).
const kPlayerMarketPreviewCount = 10;

/// Players flagged for trade, and this season's projected draft class --
/// for `PlayerMarketScreen`'s Trade Block and Draft tabs, **preview
/// only**: there is no trade system and no draft-day flow wired to
/// `Franchise` yet (`0B_Planned.md`'s Trade System and Draft entries).
/// Nothing generated here is tradeable or draftable -- it's flavor data
/// regenerated fresh from the franchise's own `simulationSeed` every time
/// the screen opens, not real game state. Deterministic per franchise
/// (same seed always shows the same preview), but explicitly not
/// persisted, since persisting a preview with no mechanical backing would
/// just be schema debt for a real system to later rip out. (Free Agents
/// isn't part of this doc comment anymore -- see the seed-offset comment
/// above for why.)

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

/// This season's projected draft class, top-heavy same as a real one --
/// just [generateDraftClass] sized down to preview length. The elite
/// headcount scales down proportionally for the smaller preview size --
/// see [generateDraftClass]'s own doc comment.
List<DraftProspect> generateDraftPreview(
  Random random, {
  int count = kPlayerMarketPreviewCount,
}) {
  return generateDraftClass(random, count: count);
}
