import '../../player/domain/player.dart';
import '../../player/domain/player_ratings.dart';
import '../../roster/domain/team_overall.dart';
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
