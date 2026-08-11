import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../player/domain/achievement.dart';
import '../../player/domain/player.dart';
import '../application/franchise_rosters.dart';
import '../domain/league_leaders.dart';
import 'achievement_grant.dart';

/// The result of one season's awards resolution: the updated [franchise]
/// (every winner's [Player.achievements]/[Player.nickname]/portrait
/// already reflect their award, via [applyAchievementGrant]) and
/// [winners] -- which player id actually won each [Achievement], for a
/// caller that wants to present them (a future real ceremony screen,
/// `0D_Season_2_Roadmap.md`'s Presentation stage). Only entries that
/// actually resolved a winner are present -- an award nobody qualified
/// for this season (see [resolveSeasonAwards]'s own doc comment on when
/// that happens) is simply missing from the map, not mapped to an empty
/// string.
class SeasonAwardsAdvance {
  const SeasonAwardsAdvance({required this.franchise, required this.winners});

  final Franchise franchise;
  final Map<Achievement, String> winners;
}

/// Best [scoreOf] among [leaders]' entries -- ties favor whichever player
/// id appears first in [leaders]' own iteration order (the order they
/// first appeared in a box score), the same "no fancier tiebreaker for a
/// first pass" posture [PlayerSeasonTotals.mvpScore] itself already
/// carries. `''` if [leaders] is empty.
String _bestPlayerId(
  Map<String, PlayerSeasonTotals> leaders,
  num Function(PlayerSeasonTotals) scoreOf,
) {
  var bestId = '';
  var bestScore = double.negativeInfinity;
  for (final entry in leaders.entries) {
    final score = scoreOf(entry.value).toDouble();
    if (score > bestScore) {
      bestScore = score;
      bestId = entry.key;
    }
  }
  return bestId;
}

/// [roster]'s 6th-highest-minutes player, or `null` if fewer than 6 of
/// [roster]'s players actually appear in [leaders] (i.e. played at least
/// one real game) -- "the #6 player by minutes is that team's sixth man"
/// (`SeasonAwardsAnswers.md` #3). Only players who actually played are
/// ever ranked here -- a team whose roster is 6+ deep but mostly never
/// took the floor shouldn't produce a false "sixth man" out of players
/// tied at 0 minutes. [roster] is expected to already be
/// active-roster-only ([rostersByAbbreviation]'s own scope), matching a
/// real Sixth Man candidate: someone who plays real minutes off the
/// bench, not a developmental prospect who never suited up.
Player? _sixthManCandidate(
  List<Player> roster,
  Map<String, PlayerSeasonTotals> leaders,
) {
  final playersWhoPlayed = [
    for (final player in roster)
      if (leaders.containsKey(player.id)) player,
  ]..sort((a, b) => leaders[b.id]!.minutes.compareTo(leaders[a.id]!.minutes));
  if (playersWhoPlayed.length < 6) return null;
  return playersWhoPlayed[5];
}

/// Resolves every season-end [Achievement] (everything except
/// [Achievement.allStarMvp], which resolves mid-season instead --
/// `all_star_advancer.dart`'s `resolveAllStarGame`) against [franchise]'s
/// *current* state: [League MVP][Achievement.leagueMvp]
/// ([PlayerSeasonTotals.mvpScore]), [Achievement.scoringLeader] (total
/// points), [Achievement.defensiveMvp] ([PlayerSeasonTotals.disruptionScore]
/// -- `SeasonAwardsAnswers.md` #1 folded "Most Defensive Disruptions" into
/// this one rather than keeping it separate), [Achievement.sixthManOfTheYear]
/// (the best of each team's own 6th-highest-minutes active player,
/// [_sixthManCandidate]), [Achievement.mostImprovedPlayer] (biggest
/// overall-rating gain against [Franchise.seasonStartOverallByPlayerId]),
/// and [Achievement.rookieOfTheYear] (best [PlayerSeasonTotals.mvpScore]
/// among every player with 0 years of professional service).
///
/// **Must be called before this season's roster-legality/retirement/tenure
/// passes** -- Rookie of the Year reads [Player.yearsOfService] as it
/// stood *during* the season just played (tenure hasn't incremented yet),
/// and a retiring veteran should still be able to win an award for the
/// season they actually played, not be silently skipped because they'd
/// already left the league by the time this ran.
///
/// **The Most Improved Player / Rookie of the Year overlap rule**
/// (`SeasonAwardsAnswers.md` #6): if the same player would win both, they
/// keep Rookie of the Year, and Most Improved Player rolls down to the
/// next-highest-gain player instead (skipped entirely if nobody else
/// actually improved).
///
/// Any award can end up with no winner at all, and that's expected, not
/// a bug: [Achievement.mostImprovedPlayer] needs
/// [Franchise.seasonStartOverallByPlayerId] to be non-empty (never true
/// for a franchise's very first season -- no prior `beginNextSeason` call
/// ever captured one) and at least one real positive gain;
/// [Achievement.rookieOfTheYear] needs at least one true rookie to have
/// actually played a game; [Achievement.sixthManOfTheYear] needs at
/// least one team with 6+ active players who played. Every award grant
/// runs through the shared [applyAchievementGrant] -- see that
/// function's own doc comment for the nickname/neon-hair-unlock side
/// effects each one carries.
SeasonAwardsAdvance resolveSeasonAwards(Random random, Franchise franchise) {
  final leaders = computeLeagueLeaders(franchise.seasonProgress.playedGames);
  if (leaders.isEmpty) {
    return SeasonAwardsAdvance(franchise: franchise, winners: const {});
  }

  final activeRostersByAbbreviation = rostersByAbbreviation(franchise);
  final allMemberships = [
    for (final membership in franchise.roster) membership,
    for (final aiTeam in franchise.league.aiTeams) ...aiTeam.roster,
  ];
  final playersById = {
    for (final membership in allMemberships)
      membership.player.id: membership.player,
  };

  final mvpId = _bestPlayerId(leaders, (t) => t.mvpScore);
  final scoringLeaderId = _bestPlayerId(leaders, (t) => t.points);
  final defensiveMvpId = _bestPlayerId(leaders, (t) => t.disruptionScore);

  final sixthManCandidates = <Player>[];
  for (final roster in activeRostersByAbbreviation.values) {
    final candidate = _sixthManCandidate(roster, leaders);
    if (candidate != null) sixthManCandidates.add(candidate);
  }
  var sixthManId = '';
  var bestSixthManScore = double.negativeInfinity;
  for (final candidate in sixthManCandidates) {
    final score = leaders[candidate.id]?.mvpScore ?? 0;
    if (score > bestSixthManScore) {
      bestSixthManScore = score;
      sixthManId = candidate.id;
    }
  }

  final rookieIds = {
    for (final membership in allMemberships)
      if (membership.player.yearsOfService == 0) membership.player.id,
  };
  final rookieLeaders = {
    for (final entry in leaders.entries)
      if (rookieIds.contains(entry.key)) entry.key: entry.value,
  };
  final rookieOfTheYearId = rookieLeaders.isEmpty
      ? ''
      : _bestPlayerId(rookieLeaders, (t) => t.mvpScore);

  final mipCandidates = [
    for (final entry in franchise.seasonStartOverallByPlayerId.entries)
      if (playersById[entry.key] case final player?)
        (playerId: entry.key, delta: player.ratings.overall - entry.value),
  ]..sort((a, b) => b.delta.compareTo(a.delta));
  var mostImprovedId = '';
  for (final candidate in mipCandidates) {
    if (candidate.delta <= 0) {
      break; // sorted descending -- nobody left improved
    }
    if (candidate.playerId == rookieOfTheYearId) {
      continue; // the overlap rule: Rookie of the Year keeps it
    }
    mostImprovedId = candidate.playerId;
    break;
  }

  var updated = franchise;
  final winners = <Achievement, String>{};
  void grant(Achievement achievement, String winnerId) {
    if (winnerId.isEmpty) return;
    winners[achievement] = winnerId;
    updated = applyAchievementGrant(
      random,
      updated,
      playerId: winnerId,
      achievement: achievement,
      season: franchise.season,
    );
  }

  grant(Achievement.leagueMvp, mvpId);
  grant(Achievement.scoringLeader, scoringLeaderId);
  grant(Achievement.defensiveMvp, defensiveMvpId);
  grant(Achievement.sixthManOfTheYear, sixthManId);
  grant(Achievement.rookieOfTheYear, rookieOfTheYearId);
  grant(Achievement.mostImprovedPlayer, mostImprovedId);

  return SeasonAwardsAdvance(franchise: updated, winners: winners);
}
