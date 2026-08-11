import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/season_progress.dart';
import 'coach_generator.dart';

/// Offset for the once-per-season coach free-agency resolution -- a
/// separate `Random` instance entirely (not just a different offset added
/// to an existing one), so this season's firing/hiring rolls can never
/// shift `kAiTeamTrainingSeedOffset`/`kSeasonEndAgingSeedOffset`'s own
/// draws for the same season (`training_advancer.dart`).
const kCoachFreeAgencySeedOffset = 16;

/// How many of the league's worst-record AI teams get evaluated for a
/// coaching change each season -- "roughly the bottom 5" per the GM's own
/// answer (`SeasonAwardsAnswers.md` #5). Ranked among the 19 AI teams
/// only -- the GM's own club is never a candidate, see this file's own
/// doc comment on why.
const kCoachFiringCandidateCount = 5;

/// How many seasons a newly hired coach is protected from being fired --
/// "a coach who was just hired gets a 2-season grace period... so a new
/// hire isn't judged on one bad year" (`SeasonAwardsAnswers.md` #5).
const kCoachGracePeriodSeasons = 2;

/// The result of one season's coach free-agency resolution.
class CoachFreeAgencyAdvance {
  const CoachFreeAgencyAdvance({
    required this.league,
    required this.firedTeamAbbreviations,
  });

  final League league;

  /// Which AI teams actually got a new coach this call -- empty most
  /// seasons, since the grace period protects most of the bottom 5 most
  /// of the time. Nothing reads this yet (no report screen exists for
  /// it), but it's here for the same reason every other advance result in
  /// this codebase carries a "what actually changed" summary rather than
  /// just the new state.
  final Set<String> firedTeamAbbreviations;
}

/// Resolves one season's worth of AI-team coaching changes
/// (`SeasonAwardsAnswers.md` #5's off-season coaching sim, the other half
/// of Coach of the Year -- every AI team needed a real coach first, see
/// `league_generator.dart`'s `kAiCoachSeedOffset`): the bottom
/// [kCoachFiringCandidateCount] AI teams by regular-season record are
/// each evaluated, and whichever of those are past their
/// [kCoachGracePeriodSeasons] grace period get fired and immediately
/// replaced with a freshly generated coach -- an atomic fire-and-rehire,
/// not a separate "vacancy" state, since nothing (no GM interaction)
/// would ever observe a gap between the two for an AI team.
///
/// Runs from the same "one lump, right when the postseason finishes"
/// hook `resolveSeasonEndAging`/`resolveAiTeamSeasonTraining` already use
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`),
/// so -- unlike anything gated on the not-yet-built "Begin Season 2" flow
/// (`0D_Season_2_Roadmap.md`) -- this is real, reachable gameplay today.
/// In practice nothing fires yet on a fresh save: every AI coach starts
/// at [AiTeamRoster.coachHiredSeason] 0, so the very first postseason
/// evaluation (still `Franchise.season` 0, since nothing increments it
/// yet) always finds every coach still inside their grace period. The
/// system only starts doing real work once a save has lived past season 1
/// -- not reachable through the app yet either, same honest caveat
/// `season_transition_advancer.dart`'s own doc comment gives.
///
/// The GM's own club is never a candidate -- this is specifically the
/// "AI teams hiring replacements" system TODO.md's item asked for; firing
/// the GM's own hire without their say would be a very different (and
/// unwanted) feature. Deterministic for a given [random] stream.
CoachFreeAgencyAdvance resolveCoachFreeAgency(
  Random random,
  Franchise franchise,
) {
  final aiAbbreviations = {
    for (final aiTeam in franchise.league.aiTeams) aiTeam.team.abbreviation,
  };
  final standings = currentStandings(
    franchise.seasonProgress,
    allLeagueTeams(franchise),
  );
  final aiStandingsWorstFirst =
      standings
          .where((entry) => aiAbbreviations.contains(entry.teamAbbreviation))
          .toList()
        ..sort((a, b) => a.winPercentage.compareTo(b.winPercentage));
  final candidateAbbreviations = aiStandingsWorstFirst
      .take(kCoachFiringCandidateCount)
      .map((entry) => entry.teamAbbreviation)
      .toSet();

  final firedTeamAbbreviations = <String>{};
  final newAiTeams = <AiTeamRoster>[];
  for (final aiTeam in franchise.league.aiTeams) {
    final isCandidate = candidateAbbreviations.contains(
      aiTeam.team.abbreviation,
    );
    final pastGracePeriod =
        franchise.season - aiTeam.coachHiredSeason >= kCoachGracePeriodSeasons;
    if (isCandidate && pastGracePeriod) {
      firedTeamAbbreviations.add(aiTeam.team.abbreviation);
      newAiTeams.add(
        aiTeam.copyWithCoach(
          newCoach: generateCoach(random),
          hiredSeason: franchise.season,
        ),
      );
    } else {
      newAiTeams.add(aiTeam);
    }
  }

  return CoachFreeAgencyAdvance(
    league: League(aiTeams: newAiTeams),
    firedTeamAbbreviations: firedTeamAbbreviations,
  );
}
