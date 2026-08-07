import 'dart:math';

import '../../draft/domain/draft_prospect.dart';
import '../../draft/generation/draft_generator.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../player/generation/trait_generator.dart';
import '../../roster/domain/roster_status.dart';

/// Seed offsets for the Player Market's 3 preview tabs -- keeps each
/// stream from correlating with any other (coach=0, roster=1, league
/// draw=2, league AI rosters=3, season schedule=4, game-day advancement=5,
/// postseason=6, training coaches=7, training advancement=8), same
/// pattern as those. Re-derived fresh from `franchise.simulationSeed`
/// every time the screen builds rather than persisted -- there's nothing
/// real behind any of this yet (see the doc comment below), so there's
/// nothing worth saving.
const kFreeAgentPreviewSeedOffset = 9;
const kTradeBlockPreviewSeedOffset = 10;
const kDraftPreviewSeedOffset = 11;

/// How many players/prospects each preview tab shows -- enough to feel
/// like a real pool without turning the screen into a second roster
/// screen.
const kPlayerMarketPreviewCount = 10;

/// Free agents, players flagged for trade, and this season's projected
/// draft class -- for `PlayerMarketScreen`, a **preview only**: there is
/// no free-agent pool, no trade system, and no draft-day flow wired to
/// `Franchise` yet (`0B_Planned.md`'s Trade System and Draft entries).
/// Nothing generated here is signable, tradeable, or draftable -- it's
/// flavor data regenerated fresh from the franchise's own
/// `simulationSeed` every time the screen opens, not real game state.
/// Deterministic per franchise (same seed always shows the same
/// preview), but explicitly not persisted, since persisting a preview
/// with no mechanical backing would just be schema debt for a real
/// system to later rip out.
///
/// Generates a below-roster-quality pool -- these are players nobody
/// picked up, so a quality center noticeably under `ai_roster_generator.dart`'s
/// own role-player baseline (65) is the point, not a bug.
List<Player> generateFreeAgentPreview(
  Random random, {
  int count = kPlayerMarketPreviewCount,
}) {
  return [for (var i = 0; i < count; i++) _generateFreeAgent(random)];
}

Player _generateFreeAgent(Random random) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: 48,
    qualitySpread: 14,
  );
  final traits = generateTraits(random);
  return traits.isEmpty ? player : player.copyWithTraits(traits);
}

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
/// just [generateDraftClass] sized down to preview length, no change to
/// the actual talent-tier shape ([kDefaultDraftClassSize]'s own elite/
/// solid/fringe split scales with class size).
List<DraftProspect> generateDraftPreview(
  Random random, {
  int count = kPlayerMarketPreviewCount,
}) {
  return generateDraftClass(random, count: count);
}
