import 'game_result.dart';

/// The outcome of one best-of-N postseason series between two teams --
/// [higherSeedAbbreviation] is whichever team earned home-court advantage
/// (the better regular-season seed), not necessarily the eventual winner.
/// [games] holds only the games actually played -- a sweep is shorter
/// than a full series, same as real playoff basketball.
class SeriesResult {
  SeriesResult({
    required this.higherSeedAbbreviation,
    required this.lowerSeedAbbreviation,
    required this.winsNeeded,
    required this.games,
  }) : assert(games.isNotEmpty, 'a series must have at least one game');

  final String higherSeedAbbreviation;
  final String lowerSeedAbbreviation;

  /// Wins required to clinch the series -- 2 (best-of-3), 3 (best-of-5),
  /// or 4 (best-of-7).
  final int winsNeeded;

  final List<GameResult> games;

  int get higherSeedWins => games
      .where((g) => g.winningTeamAbbreviation == higherSeedAbbreviation)
      .length;

  int get lowerSeedWins => games
      .where((g) => g.winningTeamAbbreviation == lowerSeedAbbreviation)
      .length;

  String get winningTeamAbbreviation => higherSeedWins >= winsNeeded
      ? higherSeedAbbreviation
      : lowerSeedAbbreviation;

  String get losingTeamAbbreviation =>
      winningTeamAbbreviation == higherSeedAbbreviation
      ? lowerSeedAbbreviation
      : higherSeedAbbreviation;
}
