import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../player/domain/player.dart';
import '../domain/roster_legality.dart';
import '../domain/roster_status.dart';
import '../domain/star_tier.dart';

/// The result of one season's AI roster-legality enforcement.
class RosterLegalityAdvance {
  const RosterLegalityAdvance({
    required this.franchise,
    required this.waivedPlayerIds,
  });

  final Franchise franchise;

  /// Every player id waived off an AI roster this call -- empty most
  /// seasons, same "usually nothing happens" shape
  /// `coach_free_agency_advancer.dart`'s `firedTeamAbbreviations` already
  /// has. Nothing surfaces this to the GM yet (no mail item exists for
  /// it); it's here for the same reason every other advance result in
  /// this codebase carries a "what actually changed" summary.
  final Set<String> waivedPlayerIds;
}

/// Trims [active] down to a legal star-tier composition, waiving the
/// lowest-overall excess player(s) first -- [kMaxFourStarPlayers] fixed
/// before [kMaxThreeStarAndUpPlayers], since a waived four-star player
/// also counts against the combined cap, and fixing the narrower cap
/// first means the wider one only ever needs to trim real three-star
/// excess afterward. Appends every id cut to [waivedIds] (a caller-owned
/// accumulator, not a return value, so a per-team loop can reuse the same
/// set across every team it processes) and returns the surviving roster.
List<Player> _legalActiveRoster(List<Player> active, Set<String> waivedIds) {
  var roster = [...active];

  final fourStars =
      roster.where((p) => StarTier.of(p) == StarTier.fourStar).toList()
        ..sort((a, b) => a.ratings.overall.compareTo(b.ratings.overall));
  while (fourStars.length > kMaxFourStarPlayers) {
    final cut = fourStars.removeAt(0);
    roster.remove(cut);
    waivedIds.add(cut.id);
  }

  final threeStarAndUp =
      roster
          .where(
            (p) =>
                StarTier.of(p) == StarTier.fourStar ||
                StarTier.of(p) == StarTier.threeStar,
          )
          .toList()
        ..sort((a, b) => a.ratings.overall.compareTo(b.ratings.overall));
  while (threeStarAndUp.length > kMaxThreeStarAndUpPlayers) {
    final cut = threeStarAndUp.removeAt(0);
    roster.remove(cut);
    waivedIds.add(cut.id);
  }

  return roster;
}

/// Enforces `star_system.md`'s star-tier caps on every AI team's active
/// roster -- the real gate `0D_Season_2_Roadmap.md`'s Aging & roster
/// churn stage asked for ("Rosters must be legal before free agency and
/// the draft," today advisory-only: `RosterLegality` exposes counts for a
/// screen to warn with, nothing actually enforces them). Waives the
/// lowest-overall excess player(s) straight into [Franchise.freeAgents]
/// (a direct GM call, 2026-08-11: "into `Franchise.freeAgents`, signable
/// by the GM" -- the only real free-agent pool that exists today, and it
/// gives the cut real in-game value instead of just vanishing).
///
/// Deliberately AI-only -- the GM's own roster stays advisory-only for
/// now, same asymmetry every other season-end system this session
/// established (training, aging, coach free agency): auto-waiving the
/// GM's own player without any say would be a much bigger, unwanted
/// feature, and `star_system.md`'s own text describes a real choice
/// ("trading... offloading... or letting core players walk") that a GM
/// needs an actual decision point for -- the fuller flow (Assistant GM
/// mail warning, a grace period, AI teams offering trades first) is
/// designed but not built, per that file's own Off-Season Reconciliation
/// note.
///
/// Only [RosterStatus.active] players are ever counted or waived --
/// developmental/reserve players are outside `RosterLegality`'s scope
/// entirely (`roster_legality.dart`'s own doc comment), and stay
/// untouched here too. No randomness: which player(s) get cut is a pure
/// function of current overall ratings, so this is meant to be called
/// once per season, right alongside every other season-end resolution.
RosterLegalityAdvance enforceAiRosterLegality(Franchise franchise) {
  final waivedIds = <String>{};
  final waivedPlayers = <Player>[];
  final newAiTeams = <AiTeamRoster>[];

  for (final aiTeam in franchise.league.aiTeams) {
    final activeMemberships = [
      for (final m in aiTeam.roster)
        if (m.status == RosterStatus.active) m,
    ];
    final otherMemberships = [
      for (final m in aiTeam.roster)
        if (m.status != RosterStatus.active) m,
    ];
    final activePlayers = [for (final m in activeMemberships) m.player];

    final beforeCount = waivedIds.length;
    final legalActive = _legalActiveRoster(activePlayers, waivedIds);
    if (waivedIds.length == beforeCount) {
      newAiTeams.add(aiTeam);
      continue;
    }

    final legalIds = {for (final p in legalActive) p.id};
    waivedPlayers.addAll(activePlayers.where((p) => !legalIds.contains(p.id)));
    final newActiveMemberships = activeMemberships
        .where((m) => legalIds.contains(m.player.id))
        .toList();
    newAiTeams.add(
      aiTeam.copyWithRoster([...newActiveMemberships, ...otherMemberships]),
    );
  }

  final withLeague = franchise.copyWithLeague(League(aiTeams: newAiTeams));
  return RosterLegalityAdvance(
    franchise: waivedPlayers.isEmpty
        ? withLeague
        : withLeague.copyWithFreeAgents([
            ...franchise.freeAgents,
            ...waivedPlayers,
          ]),
    waivedPlayerIds: waivedIds,
  );
}
