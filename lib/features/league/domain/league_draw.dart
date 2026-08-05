import 'dart:math';

import 'initial_league.dart';
import 'team.dart';

/// Offset applied to a franchise's `simulationSeed` before drawing its
/// league, so the draw's random stream doesn't correlate with the coach's
/// (offset 0) or starting roster's (offset 1) -- see
/// `expansion_franchise_factory.dart`.
const kLeagueDrawSeedOffset = 2;

/// Draws one playthrough's 20-team league (10 per conference) from the
/// 40-team design pool (`kLeagueTeamPool`) -- each conference has 20
/// candidates, so which teams actually exist varies game to game.
/// Deterministic: the same [random] stream always draws the same 20 teams.
List<Team> drawLeagueTeams(Random random) {
  final atlantic =
      kLeagueTeamPool
          .where((team) => team.conference == Conference.atlantic)
          .toList()
        ..shuffle(random);
  final pacific =
      kLeagueTeamPool
          .where((team) => team.conference == Conference.pacific)
          .toList()
        ..shuffle(random);
  return [...atlantic.take(10), ...pacific.take(10)];
}
