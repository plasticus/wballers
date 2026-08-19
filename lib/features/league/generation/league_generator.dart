import 'dart:math';

import '../../coach/domain/coach_lifecycle.dart';
import '../../coach/generation/coach_generator.dart';
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

/// Offset for every AI team's own generated head coach -- kept off the
/// [kLeagueRosterSeedOffset] stream (a separate `Random` instance
/// entirely, not just a different offset added to the same one) so
/// adding this generator couldn't shift a single roster-generation draw
/// for any existing save. See `0A_Completed.md`'s coach-free-agency entry
/// for why every AI team needed a real coach in the first place
/// (`SeasonAwardsAnswers.md` answer 5 -- Coach of the Year was blocked on
/// it).
const kAiCoachSeedOffset = 15;

/// Generates this playthrough's [League]: the same 20-team draw
/// `drawLeagueTeams` produces for [simulationSeed], minus
/// [replacedTeamAbbreviation] (the GM's club takes that slot instead --
/// see `Franchise.team`), with a freshly generated roster and head coach
/// for each of the other 19. Deterministic for a given [simulationSeed].
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
  final coachRandom = Random(simulationSeed + kAiCoachSeedOffset);
  final aiTeams = [
    for (final team in aiTeamIdentities)
      AiTeamRoster(
        team: team,
        roster: generateAiRoster(random, portraitWeights: portraitWeights),
        coach: generateCoach(
          coachRandom,
          minAge: kCoachInitialLeagueMinAge,
          maxAge: kCoachInitialLeagueMaxAge,
          portraitWeights: portraitWeights,
        ),
      ),
  ];

  return League(aiTeams: aiTeams);
}
