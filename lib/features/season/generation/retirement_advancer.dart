import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../coach/domain/coach.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../player/domain/player.dart';
import '../../player/domain/retirement_reason.dart';
import '../../roster/domain/roster_membership.dart';
import 'postseason_generator.dart' show seasonChampion;

/// Skill-check floor/ceiling for [attemptRetirementPersuasion] -- keeps
/// the outcome from ever being fully guaranteed or fully hopeless
/// regardless of how strong/weak the coach's Motivation is. First-pass
/// numbers, easy to retune once real playthroughs say otherwise.
const kMinPersuasionChance = 0.1;
const kMaxPersuasionChance = 0.9;

/// Whether [coach] successfully talks a retirement-eligible player into
/// playing one more year -- the GM's own stated mechanic (2026-08-11:
/// "the coach can attempt to convince them to play for one more year, a
/// coach skill check"). Reads [coach]'s Motivation specifically: not a
/// perfect thematic fit for "keep a veteran playing," but the closest of
/// the 5 `CoachStats` to it -- `coach_stats.dart`'s own doc comment
/// already ties Motivation to "team morale... and close-game resilience,"
/// the same "keep everyone engaged" thread, while every other stat maps
/// to something further away (Offense/Defense to tactics, Development to
/// growth, Management to trades/drafts).
bool attemptRetirementPersuasion(Random random, Coach coach) {
  final chance = (coach.stats.motivation / kMaxRating).clamp(
    kMinPersuasionChance,
    kMaxPersuasionChance,
  );
  return random.nextDouble() < chance;
}

/// Seed offset for [resolveAiTeamRetirements]'s [Random] stream -- next
/// free number after `training_advancer.dart`'s
/// `kAiTeamSeasonEndAgingSeedOffset` (17).
const kAiTeamRetirementSeedOffset = 18;

/// Age at which a player "hits [it and] want[s] to retire" -- a direct GM
/// rule (2026-08-11), declarative, not a chance roll, same footing as
/// [kRetirementDeclineFromPeak] below. First-pass number, easy to retune.
const kMandatoryRetirementAge = 38;

/// A drop this large from a player's own recorded peak
/// ([Player.effectivePeakOverall]) means they retire outright -- a
/// direct GM rule (2026-08-11), no roll.
const kRetirementDeclineFromPeak = 10;

/// The age a player has to be, on top of their team winning the
/// championship, to even be considered for [kChampionshipRetirementChance]'s
/// roll below.
const kChampionshipConsiderationAge = 34;

/// Chance a [kChampionshipConsiderationAge]-or-older player on the
/// championship team retires -- the GM's own wording was "they'll
/// *consider* retirement," softer than the other two triggers'
/// declarative "they retire," so this is the one trigger that rolls
/// rather than applying outright. First-pass number, easy to retune once
/// real playthroughs say otherwise -- same posture as every other tuning
/// constant in `training_advancer.dart`.
const kChampionshipRetirementChance = 0.4;

/// Whether [player] has *tripped* one of the 3 implemented triggers, and
/// which -- deliberately no roll here, even for
/// [RetirementReason.wonChampionshipLate], which normally needs
/// [kChampionshipRetirementChance]'s chance to actually fire
/// ([evaluateRetirement]'s job). This is the eligibility half only, what
/// the GM's own roster uses (`current_franchise_provider.dart`'s
/// `simulatePostseasonAndPersist`, feeding `Franchise.pendingRetirements`)
/// -- the GM's stated rule gives their own players a real decision (the
/// coach's persuasion skill check), not an automatic roll, so "eligible"
/// itself has to be deterministic; the randomness lives in the persuasion
/// attempt instead (`current_franchise_provider.dart`'s
/// `resolvePendingRetirement`), not here.
RetirementReason? evaluateRetirementEligibility(
  Player player, {
  required bool wonChampionship,
}) {
  if (player.age >= kMandatoryRetirementAge) {
    return RetirementReason.hitMandatoryAge;
  }
  if (player.effectivePeakOverall - player.ratings.overall >=
      kRetirementDeclineFromPeak) {
    return RetirementReason.declinedFromPeak;
  }
  if (player.age >= kChampionshipConsiderationAge && wonChampionship) {
    return RetirementReason.wonChampionshipLate;
  }
  return null;
}

/// Whether [player] retires this season outright, and why -- checked
/// against the age/ratings [player] finished the season *at* (post-
/// training/decline, pre-tenure-advance), same ordering every other
/// season-end check in this pipeline uses. Layers
/// [kChampionshipRetirementChance]'s roll on top of
/// [evaluateRetirementEligibility]'s trigger check -- only
/// [RetirementReason.wonChampionshipLate] actually consumes [random], so
/// a caller evaluating hundreds of players a season only spends a draw
/// on the ones old enough and successful enough for the roll to matter.
/// What every AI team uses (no GM to offer a persuasion choice to); the
/// GM's own roster uses [evaluateRetirementEligibility] instead, un-rolled,
/// since the roll doesn't apply there -- the coach's persuasion attempt
/// is the equivalent chance for that trigger, not this one.
///
/// Deliberately doesn't cover every trigger the GM described
/// (2026-08-11): a free agent unsigned for a full season retiring needs
/// real "how long have they been sitting" tracking that doesn't exist
/// yet (`Franchise.freeAgents` has no tenure concept -- that's
/// `0D_Season_2_Roadmap.md`'s *next* stage, Player Pool Refresh's, job),
/// so it's left out here rather than half-built on top of missing data.
RetirementReason? evaluateRetirement(
  Random random,
  Player player, {
  required bool wonChampionship,
}) {
  final reason = evaluateRetirementEligibility(
    player,
    wonChampionship: wonChampionship,
  );
  if (reason == RetirementReason.wonChampionshipLate) {
    return random.nextDouble() < kChampionshipRetirementChance ? reason : null;
  }
  return reason;
}

/// The result of one season's AI-team retirement resolution.
class AiTeamRetirementAdvance {
  const AiTeamRetirementAdvance({
    required this.league,
    required this.retiredPlayerIds,
  });

  final League league;

  /// Every player id who retired this call -- empty most seasons. Unlike
  /// a roster-legality waive (`roster_legality_advancer.dart`), a retired
  /// player is removed from the league entirely, not added to
  /// [Franchise.freeAgents] -- retired means retired, not available to
  /// sign.
  final Set<String> retiredPlayerIds;
}

/// Resolves retirement for every AI team's roster -- `0D_Season_2_Roadmap.md`'s
/// Aging & roster churn stage (2026-08-11): "No concept exists at all --
/// nothing removes a player from the league for any reason." Every
/// [RosterStatus] is checked, not just active -- retirement is about a
/// career, not playing time, same "aging isn't gated by minutes" posture
/// `season_tenure_advancer.dart`'s own doc comment gives.
///
/// Deliberately AI-only, same asymmetry every other season-end system
/// this session established: the GM's own roster isn't touched here at
/// all. The GM's stated rule includes a real decision point for their
/// own players specifically -- "the coach can attempt to convince them to
/// play for one more year (a skill check)" -- so their roster instead
/// feeds `Franchise.pendingRetirements`
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`),
/// which a real Mail item surfaces for the GM to actually decide
/// (`resolvePendingRetirement`, [attemptRetirementPersuasion]).
AiTeamRetirementAdvance resolveAiTeamRetirements(
  Random random,
  Franchise franchise,
) {
  final championAbbreviation = seasonChampion(
    franchise.seasonProgress.playedGames,
  );
  final retiredIds = <String>{};
  final newAiTeams = <AiTeamRoster>[];

  for (final aiTeam in franchise.league.aiTeams) {
    final wonChampionship = aiTeam.team.abbreviation == championAbbreviation;
    final newRoster = <RosterMembership>[];
    for (final membership in aiTeam.roster) {
      final reason = evaluateRetirement(
        random,
        membership.player,
        wonChampionship: wonChampionship,
      );
      if (reason != null) {
        retiredIds.add(membership.player.id);
        continue;
      }
      newRoster.add(membership);
    }
    newAiTeams.add(aiTeam.copyWithRoster(newRoster));
  }

  return AiTeamRetirementAdvance(
    league: League(aiTeams: newAiTeams),
    retiredPlayerIds: retiredIds,
  );
}

/// Forces [Franchise.narrativeVeteranPlayerId] into retirement at the end
/// of the franchise's very first season (`franchise.season == 0`),
/// wherever she currently is -- a direct GM call (2026-08-19), triggered
/// by noticing the seat-1 Analyst swap (`match_preview_screen.dart`) had
/// no real trigger of its own: "if the new player trades away their star
/// player right away... whatever team she's on at the end of season 1,
/// she retires, and takes over the analyst position." A scripted,
/// one-time narrative beat, not the age/decline-based
/// [evaluateRetirementEligibility] triggers every other player uses --
/// she starts at 33-34 (`expansion_franchise_factory.dart`), well under
/// [kMandatoryRetirementAge], so nothing else would ever retire her this
/// early.
///
/// A no-op once [Franchise.narrativeVeteranRetired] is already true (this
/// only ever fires once), or if it isn't actually the end of season 0
/// yet, or if [Franchise.narrativeVeteranPlayerId] is empty (a hand-built
/// test fixture with no real veteran -- `Franchise.narrativeVeteranPlayerId`'s
/// own doc comment). Otherwise removes her from wherever she's found --
/// the GM's own roster, whichever AI team a trade sent her to, or (rare)
/// [Franchise.freeAgents] if she was dropped along the way -- the same
/// "retired means retired, not available to sign" posture
/// [resolveAiTeamRetirements] already established, and sets
/// [Franchise.narrativeVeteranRetired] so `match_preview_screen.dart`'s
/// seat 1 swap has a real, trade-proof signal to key off instead of the
/// old "not found on the GM's own roster" proxy (which broke the instant
/// she was traded away, retired or not).
Franchise resolveNarrativeVeteranRetirement(Franchise franchise) {
  if (franchise.narrativeVeteranRetired) return franchise;
  if (franchise.season != 0) return franchise;
  final veteranId = franchise.narrativeVeteranPlayerId;
  if (veteranId.isEmpty) return franchise;

  if (franchise.roster.any((m) => m.player.id == veteranId)) {
    return franchise
        .copyWithRoster([
          for (final m in franchise.roster)
            if (m.player.id != veteranId) m,
        ])
        .copyWithNarrativeVeteranRetired(true);
  }

  for (final aiTeam in franchise.league.aiTeams) {
    if (!aiTeam.roster.any((m) => m.player.id == veteranId)) continue;
    final newAiTeams = [
      for (final team in franchise.league.aiTeams)
        if (team.team.abbreviation == aiTeam.team.abbreviation)
          team.copyWithRoster([
            for (final m in team.roster)
              if (m.player.id != veteranId) m,
          ])
        else
          team,
    ];
    return franchise
        .copyWithLeague(League(aiTeams: newAiTeams))
        .copyWithNarrativeVeteranRetired(true);
  }

  if (franchise.freeAgents.any((p) => p.id == veteranId)) {
    return franchise
        .copyWithFreeAgents([
          for (final p in franchise.freeAgents)
            if (p.id != veteranId) p,
        ])
        .copyWithNarrativeVeteranRetired(true);
  }

  // Not found anywhere at all (an edge case some other flow would have
  // to produce) -- still mark her retired so the Analyst seat stops
  // waiting on a roster presence that will never resolve.
  return franchise.copyWithNarrativeVeteranRetired(true);
}
