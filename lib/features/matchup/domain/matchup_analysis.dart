import '../../player/domain/player.dart';
import '../../player/domain/player_ratings.dart';
import '../../roster/domain/team_overall.dart';
import '../../season/domain/league_leaders.dart';
import 'analyst.dart';

/// A team's rank-weighted composite for whatever [selector] reads off a
/// player's [PlayerRatings] -- same formula and same [weightForRosterRank]
/// table `team_overall.dart`'s `teamOverallForPlayers` uses for team
/// overall, just generalized to any single rating (in practice
/// `PlayerRatings.offenseOverall`/`defenseOverall`/`physicalOverall`, the
/// "Matchup Analysis" screen's Team Strength bars). [playersInRankOrder]'
/// *list order* is what "rank" means, same caveat `teamOverallForPlayers`
/// documents -- pass the real roster order (bench order), not a re-sort
/// by rating. Returns `0` for an empty list rather than dividing by zero.
/// Unrounded (a `double`), unlike `teamOverallForPlayers` -- callers that
/// want a display-ready integer round it themselves; callers turning this
/// into a bar-width split want the unrounded precision.
double teamCompositeRating(
  List<Player> playersInRankOrder,
  int Function(PlayerRatings) selector,
) {
  if (playersInRankOrder.isEmpty) return 0;
  var weightedSum = 0.0;
  var totalWeight = 0.0;
  for (var i = 0; i < playersInRankOrder.length; i++) {
    final weight = weightForRosterRank(i + 1);
    weightedSum += selector(playersInRankOrder[i].ratings) * weight;
    totalWeight += weight;
  }
  return totalWeight == 0 ? 0 : weightedSum / totalWeight;
}

/// The best [count] of [players] by [PlayerRatings.overall], best first --
/// the "Top 3, Head to Head" section's own list for one side. Ties break
/// on [players]' own original order (`List.sort` is stable), same as
/// every other best-first sort in this codebase.
List<Player> topPlayersFor(List<Player> players, {int count = 3}) {
  final sorted = [...players]
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  return sorted.take(count).toList();
}

/// One analyst's pick for one matchup -- who she favors, nothing else.
/// [analystVerdicts] computes this fresh per matchup; nothing about a
/// pick is ever stored.
class AnalystVerdict {
  const AnalystVerdict({
    required this.analyst,
    required this.pickedTeamAbbreviation,
  });

  final Analyst analyst;
  final String pickedTeamAbbreviation;
}

/// The analyst panel's picks for one matchup -- each of [panel]'s 5 seats
/// (in seat order, matching `kAnalystPanel`'s own: offense, defense,
/// physical, overall, top player) favors whichever team wins on exactly
/// one real number the screen already computed elsewhere
/// ([teamCompositeRating]/`teamOverallForPlayers`/[topPlayersFor]) -- no
/// hidden randomness. Deliberately no reasoning surfaced alongside a
/// pick, and no criterion label either -- a direct GM call from the
/// design lab ("I don't actually want them to say what they're choosing
/// based on, just have them pick"), so [AnalystVerdict] itself carries no
/// criterion field to accidentally expose one.
List<AnalystVerdict> analystVerdicts({
  required List<Analyst> panel,
  required String homeAbbreviation,
  required String awayAbbreviation,
  required double homeOffense,
  required double awayOffense,
  required double homeDefense,
  required double awayDefense,
  required double homePhysical,
  required double awayPhysical,
  required int homeOverall,
  required int awayOverall,
  required int homeTopPlayerOverall,
  required int awayTopPlayerOverall,
}) {
  assert(panel.length == 5, 'the analyst panel always has exactly 5 seats');

  String winner(num home, num away) =>
      home >= away ? homeAbbreviation : awayAbbreviation;

  final picks = [
    winner(homeOffense, awayOffense),
    winner(homeDefense, awayDefense),
    winner(homePhysical, awayPhysical),
    winner(homeOverall, awayOverall),
    winner(homeTopPlayerOverall, awayTopPlayerOverall),
  ];

  return [
    for (var i = 0; i < 5; i++)
      AnalystVerdict(analyst: panel[i], pickedTeamAbbreviation: picks[i]),
  ];
}

/// Formats a player's top 3 counting stats per game (from points, rebounds,
/// assists, steals, blocks) formatted like `19.0 points, 6.7 assists, 3.2 blocks`.
/// Ties break in standard counting-stat order (points, rebounds, assists,
/// steals, blocks).
/// For a player with no games played or null totals, returns
/// `'0.0 points, 0.0 rebounds, 0.0 assists'`.
String topThreeStatLine(PlayerSeasonTotals? totals) {
  if (totals == null || totals.gamesPlayed == 0) {
    return '0.0 points, 0.0 rebounds, 0.0 assists';
  }
  final stats = [
    (value: totals.pointsPerGame, label: 'points'),
    (value: totals.reboundsPerGame, label: 'rebounds'),
    (value: totals.assistsPerGame, label: 'assists'),
    (value: totals.stealsPerGame, label: 'steals'),
    (value: totals.blocksPerGame, label: 'blocks'),
  ];
  stats.sort((a, b) => b.value.compareTo(a.value));
  return stats
      .take(3)
      .map((s) => '${s.value.toStringAsFixed(1)} ${s.label}')
      .join(', ');
}

