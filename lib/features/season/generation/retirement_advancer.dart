import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import 'postseason_generator.dart' show seasonChampion;

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

/// Which of the GM's stated retirement triggers actually fired for a
/// player -- see [evaluateRetirement].
enum RetirementReason {
  /// [kMandatoryRetirementAge] or older.
  hitMandatoryAge,

  /// Dropped [kRetirementDeclineFromPeak] or more below
  /// [Player.effectivePeakOverall].
  declinedFromPeak,

  /// [kChampionshipConsiderationAge] or older, on the championship team,
  /// and [kChampionshipRetirementChance]'s roll landed.
  wonChampionshipLate,
}

/// Whether [player] retires this season, and why -- checked against the
/// age/ratings [player] finished the season *at* (post-training/decline,
/// pre-tenure-advance), same ordering every other season-end check in
/// this pipeline uses. [random] is only ever consumed for
/// [RetirementReason.wonChampionshipLate]'s roll -- the other two
/// triggers are pure/deterministic, so a caller evaluating hundreds of
/// players a season only actually spends a random draw on the ones old
/// enough and successful enough for the roll to matter.
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
  if (player.age >= kMandatoryRetirementAge) {
    return RetirementReason.hitMandatoryAge;
  }
  if (player.effectivePeakOverall - player.ratings.overall >=
      kRetirementDeclineFromPeak) {
    return RetirementReason.declinedFromPeak;
  }
  if (player.age >= kChampionshipConsiderationAge &&
      wonChampionship &&
      random.nextDouble() < kChampionshipRetirementChance) {
    return RetirementReason.wonChampionshipLate;
  }
  return null;
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
/// play for one more year (a skill check)" -- which needs a real mail/UI
/// flow that doesn't exist yet, so auto-retiring the GM's own players
/// without offering that choice would contradict the rule as given, not
/// just simplify it.
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
