import 'dart:math';

import '../../portrait/domain/portrait_weights.dart';
import '../../roster/generation/ai_roster_generator.dart';
import '../domain/ai_team_roster.dart';
import '../domain/league.dart';
import '../domain/league_draw.dart';

/// Offset applied to a franchise's `simulationSeed` before generating AI
/// rosters, so this random stream doesn't correlate with the coach's
/// (offset 0), starting roster's (offset 1), or league draw's (offset 2)
/// -- see `expansion_franchise_factory.dart` and `league_draw.dart`.
const kLeagueRosterSeedOffset = 3;

/// Generates this playthrough's [League]: the same 20-team draw
/// `drawLeagueTeams` produces for [simulationSeed], minus
/// [replacedTeamAbbreviation] (the GM's club takes that slot instead --
/// see `Franchise.team`), with a freshly generated roster for each of the
/// other 19. Deterministic for a given [simulationSeed].
League generateLeague({
  required int simulationSeed,
  required String replacedTeamAbbreviation,
  PortraitWeights? portraitWeights,
}) {
  final drawnTeams = drawLeagueTeams(
    Random(simulationSeed + kLeagueDrawSeedOffset),
  );
  final aiTeamIdentities = drawnTeams.where(
    (team) => team.abbreviation != replacedTeamAbbreviation,
  );

  final random = Random(simulationSeed + kLeagueRosterSeedOffset);
  final aiTeams = [
    for (final team in aiTeamIdentities)
      AiTeamRoster(
        team: team,
        roster: generateAiRoster(random, portraitWeights: portraitWeights),
      ),
  ];

  return League(aiTeams: aiTeams);
}
