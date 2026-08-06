import '../../league/domain/team.dart';
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

/// [abbreviation]'s entry in [standings], or a 0-0 placeholder if it
/// hasn't played a regular-season game yet (so it has no entry at all --
/// [computeStandings] only produces entries for teams that appear in at
/// least one counted result). Previously duplicated as a private
/// `_recordFor` in three separate screens; promoted here since it's
/// genuinely shared, not UI-specific.
StandingsEntry recordFor(String abbreviation, List<StandingsEntry> standings) {
  for (final entry in standings) {
    if (entry.teamAbbreviation == abbreviation) return entry;
  }
  return StandingsEntry(
    teamAbbreviation: abbreviation,
    wins: 0,
    losses: 0,
    pointsFor: 0,
    pointsAgainst: 0,
  );
}

/// Builds a standings table from every [GameResult.game] with
/// [GameType.regularSeason] in [results] -- preseason and Continental Cup
/// games don't count. Sorted best-to-worst by win percentage; teams that
/// tie exactly on win percentage are broken by [leagueTeams]' conference
/// assignments through a tiebreaker cascade: head-to-head record among
/// just the tied teams, then in-conference record, then point
/// differential, then team abbreviation as a final, purely-for-
/// determinism fallback. This project's own resolution of a real
/// standings tiebreaker system (`0B_Planned.md`), not a literal replica
/// of the WNBA's own tiebreaker rules.
List<StandingsEntry> computeStandings(
  List<GameResult> results, {
  required List<Team> leagueTeams,
}) {
  final regularSeasonResults = results
      .where((r) => r.game.type == GameType.regularSeason)
      .toList();

  final wins = <String, int>{};
  final losses = <String, int>{};
  final pointsFor = <String, int>{};
  final pointsAgainst = <String, int>{};

  for (final result in regularSeasonResults) {
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
  entries.sort((a, b) => b.winPercentage.compareTo(a.winPercentage));

  final conferenceByAbbreviation = {
    for (final team in leagueTeams) team.abbreviation: team.conference,
  };

  final resolved = <StandingsEntry>[];
  var i = 0;
  while (i < entries.length) {
    var j = i + 1;
    while (j < entries.length &&
        entries[j].winPercentage == entries[i].winPercentage) {
      j++;
    }
    final group = entries.sublist(i, j);
    resolved.addAll(
      group.length == 1
          ? group
          : _resolveTieGroup(
              group,
              regularSeasonResults,
              conferenceByAbbreviation,
            ),
    );
    i = j;
  }
  return resolved;
}

/// Breaks a tie among [group] (2+ teams sharing the same win percentage):
/// head-to-head win percentage in games played only against each other,
/// then win percentage in games played only against same-conference
/// opponents, then point differential, then abbreviation (alphabetical,
/// purely to guarantee a deterministic result if every real tiebreaker
/// above is also exactly tied).
List<StandingsEntry> _resolveTieGroup(
  List<StandingsEntry> group,
  List<GameResult> regularSeasonResults,
  Map<String, Conference> conferenceByAbbreviation,
) {
  final groupAbbreviations = group.map((e) => e.teamAbbreviation).toSet();

  double winPercentageAgainst(
    String team,
    bool Function(String opponent) opponentMatches,
  ) {
    var w = 0;
    var l = 0;
    for (final result in regularSeasonResults) {
      final home = result.game.homeTeamAbbreviation;
      final away = result.game.awayTeamAbbreviation;
      if (home != team && away != team) continue;
      final opponent = home == team ? away : home;
      if (!opponentMatches(opponent)) continue;
      if (result.winningTeamAbbreviation == team) {
        w++;
      } else {
        l++;
      }
    }
    final total = w + l;
    // No games played against that group -- stay neutral rather than
    // letting an empty sample masquerade as a 0% or 100% record.
    return total == 0 ? 0.5 : w / total;
  }

  final sorted = [...group]
    ..sort((a, b) {
      final byHeadToHead =
          winPercentageAgainst(
            b.teamAbbreviation,
            groupAbbreviations.contains,
          ).compareTo(
            winPercentageAgainst(
              a.teamAbbreviation,
              groupAbbreviations.contains,
            ),
          );
      if (byHeadToHead != 0) return byHeadToHead;

      final byConference =
          winPercentageAgainst(
            b.teamAbbreviation,
            (opponent) =>
                conferenceByAbbreviation[opponent] ==
                conferenceByAbbreviation[b.teamAbbreviation],
          ).compareTo(
            winPercentageAgainst(
              a.teamAbbreviation,
              (opponent) =>
                  conferenceByAbbreviation[opponent] ==
                  conferenceByAbbreviation[a.teamAbbreviation],
            ),
          );
      if (byConference != 0) return byConference;

      final byDifferential = b.pointDifferential.compareTo(a.pointDifferential);
      if (byDifferential != 0) return byDifferential;

      return a.teamAbbreviation.compareTo(b.teamAbbreviation);
    });
  return sorted;
}
