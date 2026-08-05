import 'game_result.dart';
import 'scheduled_game.dart';

/// One team's regular-season record, derived from [computeStandings] --
/// never constructed or persisted directly, so there's nothing to keep in
/// sync if the derivation logic changes.
class StandingsEntry {
  const StandingsEntry({
    required this.teamAbbreviation,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  final String teamAbbreviation;
  final int wins;
  final int losses;
  final int pointsFor;
  final int pointsAgainst;

  int get gamesPlayed => wins + losses;
  double get winPercentage => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
  int get pointDifferential => pointsFor - pointsAgainst;
}

/// Builds a standings table from every [GameResult.game] with
/// [GameType.regularSeason] in [results] -- preseason and Continental Cup
/// games don't count. Sorted best-to-worst by win percentage, then point
/// differential as a tiebreaker -- a placeholder ordering, not the real
/// tiebreaker system `0B_Planned.md` still has as an open item.
List<StandingsEntry> computeStandings(List<GameResult> results) {
  final wins = <String, int>{};
  final losses = <String, int>{};
  final pointsFor = <String, int>{};
  final pointsAgainst = <String, int>{};

  for (final result in results) {
    if (result.game.type != GameType.regularSeason) continue;

    final home = result.game.homeTeamAbbreviation;
    final away = result.game.awayTeamAbbreviation;
    pointsFor[home] = (pointsFor[home] ?? 0) + result.match.homeScore;
    pointsAgainst[home] = (pointsAgainst[home] ?? 0) + result.match.awayScore;
    pointsFor[away] = (pointsFor[away] ?? 0) + result.match.awayScore;
    pointsAgainst[away] = (pointsAgainst[away] ?? 0) + result.match.homeScore;

    final winner = result.winningTeamAbbreviation;
    final loser = result.losingTeamAbbreviation;
    wins[winner] = (wins[winner] ?? 0) + 1;
    losses[loser] = (losses[loser] ?? 0) + 1;
  }

  final teams = {...pointsFor.keys, ...pointsAgainst.keys};
  final entries = [
    for (final team in teams)
      StandingsEntry(
        teamAbbreviation: team,
        wins: wins[team] ?? 0,
        losses: losses[team] ?? 0,
        pointsFor: pointsFor[team] ?? 0,
        pointsAgainst: pointsAgainst[team] ?? 0,
      ),
  ];
  entries.sort((a, b) {
    final byWinPercentage = b.winPercentage.compareTo(a.winPercentage);
    if (byWinPercentage != 0) return byWinPercentage;
    return b.pointDifferential.compareTo(a.pointDifferential);
  });
  return entries;
}
