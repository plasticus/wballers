import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/league.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';

/// Seed offset for [resolveAiOffseasonTrades]'s own `Random` stream --
/// next free number after `trade_offer_generator.dart`'s
/// `kTradeOfferSeedOffset` (22).
const kAiOffseasonTradeSeedOffset = 23;

/// How many active players at one position a roster wants, minimum --
/// "at least 2 players from every position," a direct GM ask
/// (2026-08-19). A position with fewer than this counts as a need; more
/// than this counts as surplus (a position sitting at exactly this count
/// is neither -- nothing to gain trading it away, nothing missing).
const kAiOffseasonTradeTargetPerPosition = 2;

/// The largest `PlayerRatings.skillPoints` gap an off-season AI-to-AI
/// trade is allowed to cross -- a flat number, not gated by either
/// team's own coach Management (unlike the GM-facing Trade Board's
/// `tradeSwing`): "Max gap of 36," a direct GM call (2026-08-19).
const kAiOffseasonTradeMaxGap = 36;

/// The result of one off-season's AI-to-AI trade resolution.
class AiOffseasonTradeAdvance {
  const AiOffseasonTradeAdvance({
    required this.league,
    required this.tradedTeamAbbreviations,
  });

  final League league;

  /// Every AI team that actually made a trade this call -- empty most
  /// off-seasons, same "usually nothing happens" shape every other
  /// season-end advance result in this codebase already has. Always an
  /// even count -- a trade always involves exactly 2 teams.
  final Set<String> tradedTeamAbbreviations;
}

Map<Position, int> _positionCounts(List<Player> players) {
  final counts = {for (final position in Position.values) position: 0};
  for (final player in players) {
    counts[player.primaryPosition] = counts[player.primaryPosition]! + 1;
  }
  return counts;
}

/// The first position [countsGivingUp] has real surplus at (more than
/// [kAiOffseasonTradeTargetPerPosition]) that [countsReceiving] is
/// genuinely light at (fewer than it) -- `null` if there's no such
/// position at all. Fixed [Position.values] order, so this always finds
/// the *same* one first for the same two roster shapes -- deterministic,
/// not "the best possible match."
Position? _firstComplementaryPosition({
  required Map<Position, int> countsGivingUp,
  required Map<Position, int> countsReceiving,
}) {
  for (final position in Position.values) {
    if (countsGivingUp[position]! > kAiOffseasonTradeTargetPerPosition &&
        countsReceiving[position]! < kAiOffseasonTradeTargetPerPosition) {
      return position;
    }
  }
  return null;
}

/// Resolves a light pass of off-season AI-to-AI roster trades -- a direct
/// GM ask (2026-08-19): "make a few AI trades happen in the off-season...
/// only 1:1 trades, trying to balance their rosters closer to... at
/// least 2 players from every position... none of them would make more
/// than one trade... Max gap of 36." Entirely separate from the GM-facing
/// Trade Board (`trade_offer_generator.dart`) -- no offer is ever shown
/// to anyone, these trades just happen, the same "one off-season lump"
/// posture `resolveCoachFreeAgency`/`enforceAiRosterLegality` already
/// have.
///
/// For each unordered pair of AI teams (visited in a [random]-shuffled
/// order, so which pairs get first crack at trading isn't always the
/// same 2 teams), looks for a genuinely complementary mismatch: team A
/// has real surplus at some position team B is light at, *and* team B
/// has real surplus at some (necessarily different -- a team can't be
/// both light at and surplus in the same position at once) position team
/// A is light at. Each side offers its *weakest* player at its own
/// surplus position (a team fixing a depth problem gives up its extra
/// depth piece, not its starter) -- if the resulting
/// `PlayerRatings.skillPoints` gap clears [kAiOffseasonTradeMaxGap], the
/// swap executes and both teams are done trading for the rest of this
/// pass. Only [RosterStatus.active] players are ever counted, offered,
/// or received -- developmental/reserve rosters are untouched, matching
/// every other season-end system's own active-only scope.
///
/// No attempt to find the *best* possible match, or to retry a pair with
/// a different position/player combination if the first one doesn't
/// clear the gap -- deliberately light-touch, "probably none of them
/// would make more than one trade" per the GM's own framing, not an
/// aggressive league-wide optimizer.
AiOffseasonTradeAdvance resolveAiOffseasonTrades(
  Random random,
  Franchise franchise,
) {
  final aiTeams = franchise.league.aiTeams;
  final rosterByAbbreviation = {
    for (final aiTeam in aiTeams) aiTeam.team.abbreviation: aiTeam.roster,
  };
  final activeByAbbreviation = {
    for (final aiTeam in aiTeams)
      aiTeam.team.abbreviation: [
        for (final m in aiTeam.roster)
          if (m.status == RosterStatus.active) m.player,
      ],
  };
  final countsByAbbreviation = {
    for (final entry in activeByAbbreviation.entries)
      entry.key: _positionCounts(entry.value),
  };

  final order = [for (final aiTeam in aiTeams) aiTeam.team.abbreviation]
    ..shuffle(random);
  final traded = <String>{};
  final updatedRosterByAbbreviation = <String, List<RosterMembership>>{};

  for (var i = 0; i < order.length; i++) {
    final teamA = order[i];
    if (traded.contains(teamA)) continue;

    for (var j = i + 1; j < order.length; j++) {
      final teamB = order[j];
      if (traded.contains(teamB)) continue;

      final countsA = countsByAbbreviation[teamA]!;
      final countsB = countsByAbbreviation[teamB]!;
      final giveFromA = _firstComplementaryPosition(
        countsGivingUp: countsA,
        countsReceiving: countsB,
      );
      final giveFromB = _firstComplementaryPosition(
        countsGivingUp: countsB,
        countsReceiving: countsA,
      );
      if (giveFromA == null || giveFromB == null) continue;

      final poolA =
          activeByAbbreviation[teamA]!
              .where((p) => p.primaryPosition == giveFromA)
              .toList()
            ..sort(
              (a, b) => a.ratings.skillPoints.compareTo(b.ratings.skillPoints),
            );
      final poolB =
          activeByAbbreviation[teamB]!
              .where((p) => p.primaryPosition == giveFromB)
              .toList()
            ..sort(
              (a, b) => a.ratings.skillPoints.compareTo(b.ratings.skillPoints),
            );
      if (poolA.isEmpty || poolB.isEmpty) continue;

      final playerA = poolA.first;
      final playerB = poolB.first;
      final gap = (playerA.ratings.skillPoints - playerB.ratings.skillPoints)
          .abs();
      if (gap > kAiOffseasonTradeMaxGap) continue;

      updatedRosterByAbbreviation[teamA] = [
        for (final m in rosterByAbbreviation[teamA]!)
          if (m.player.id != playerA.id) m,
        RosterMembership(player: playerB, status: RosterStatus.active),
      ];
      updatedRosterByAbbreviation[teamB] = [
        for (final m in rosterByAbbreviation[teamB]!)
          if (m.player.id != playerB.id) m,
        RosterMembership(player: playerA, status: RosterStatus.active),
      ];
      traded.add(teamA);
      traded.add(teamB);
      break;
    }
  }

  final newAiTeams = [
    for (final aiTeam in aiTeams)
      if (updatedRosterByAbbreviation[aiTeam.team.abbreviation]
          case final newRoster?)
        aiTeam.copyWithRoster(newRoster)
      else
        aiTeam,
  ];

  return AiOffseasonTradeAdvance(
    league: League(aiTeams: newAiTeams),
    tradedTeamAbbreviations: traded,
  );
}
