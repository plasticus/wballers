import 'played_game.dart';
import 'scheduled_game.dart';

/// One player's aggregated regular-season stat totals, derived fresh from
/// every [PlayedGame.boxScoreByPlayerId] entry that names them -- never
/// constructed or persisted directly, same "always re-derived, no cached
/// copy to drift" posture [StandingsEntry]/`computeStandings` already use.
/// Preseason and Continental Cup games don't count, matching
/// `computeStandings`'s own scope -- an exhibition scoring binge shouldn't
/// lead the league in points per game.
class PlayerSeasonTotals {
  const PlayerSeasonTotals({
    required this.playerId,
    required this.gamesPlayed,
    required this.minutes,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.fieldGoalsMade,
    required this.fieldGoalAttempts,
    required this.threePointersMade,
    required this.threePointAttempts,
    required this.freeThrowsMade,
    required this.freeThrowAttempts,
  });

  final String playerId;
  final int gamesPlayed;

  /// Total minutes across every counted game -- `season_awards_advancer.dart`'s
  /// `resolveSeasonAwards` is the only consumer so far (Sixth Man of the
  /// Year ranks each team's own active roster by this).
  final double minutes;
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
  final int fieldGoalsMade;
  final int fieldGoalAttempts;
  final int threePointersMade;
  final int threePointAttempts;
  final int freeThrowsMade;
  final int freeThrowAttempts;

  double get pointsPerGame => gamesPlayed == 0 ? 0 : points / gamesPlayed;
  double get reboundsPerGame => gamesPlayed == 0 ? 0 : rebounds / gamesPlayed;
  double get assistsPerGame => gamesPlayed == 0 ? 0 : assists / gamesPlayed;
  double get stealsPerGame => gamesPlayed == 0 ? 0 : steals / gamesPlayed;
  double get blocksPerGame => gamesPlayed == 0 ? 0 : blocks / gamesPlayed;
  double get minutesPerGame => gamesPlayed == 0 ? 0 : minutes / gamesPlayed;

  double get fieldGoalPercentage =>
      fieldGoalAttempts == 0 ? 0 : fieldGoalsMade / fieldGoalAttempts;
  double get threePointPercentage =>
      threePointAttempts == 0 ? 0 : threePointersMade / threePointAttempts;
  double get freeThrowPercentage =>
      freeThrowAttempts == 0 ? 0 : freeThrowsMade / freeThrowAttempts;

  /// A simple, transparent composite score for the MVP race -- the same
  /// counting stats a box score already shows, just summed per game
  /// rather than a hidden formula. Not a real advanced metric (no
  /// efficiency/usage weighting), deliberately: "leaders you can see the
  /// math on" beats a black-box number for a first pass.
  double get mvpScore =>
      pointsPerGame +
      reboundsPerGame +
      assistsPerGame +
      stealsPerGame +
      blocksPerGame;

  /// The GM's own "Disruption" shorthand -- steals + blocks, per game --
  /// as a real box-score composite, not just the rating-based stand-in
  /// `all_star_advancer.dart`'s Skills Competition field uses (no box
  /// score exists mid-heat there). `season_awards_advancer.dart`'s
  /// Defensive MVP is this composite's real consumer
  /// (`SeasonAwardsAnswers.md` #1 folded "Most Defensive Disruptions"
  /// into Defensive MVP rather than keeping it a separate award).
  double get disruptionScore => stealsPerGame + blocksPerGame;
}

class _MutableTotals {
  var gamesPlayed = 0;
  var minutes = 0.0;
  var points = 0;
  var rebounds = 0;
  var assists = 0;
  var steals = 0;
  var blocks = 0;
  var turnovers = 0;
  var fieldGoalsMade = 0;
  var fieldGoalAttempts = 0;
  var threePointersMade = 0;
  var threePointAttempts = 0;
  var freeThrowsMade = 0;
  var freeThrowAttempts = 0;
}

/// Every player who appeared in at least one regular-season game this
/// season, keyed by id, with their counting stats summed across every
/// such game. [playedGames] is expected to be a franchise's whole
/// [PlayedGame] history (`Franchise.seasonProgress.playedGames`), which
/// already covers both sides of every game -- the GM's own roster and
/// every AI team's -- so this naturally produces real leaguewide leaders,
/// not just the GM's own players.
Map<String, PlayerSeasonTotals> computeLeagueLeaders(
  List<PlayedGame> playedGames,
) {
  final totals = <String, _MutableTotals>{};
  for (final played in playedGames) {
    if (played.game.type != GameType.regularSeason) continue;
    for (final entry in played.boxScoreByPlayerId.entries) {
      final line = entry.value;
      final t = totals.putIfAbsent(entry.key, _MutableTotals.new);
      t.gamesPlayed++;
      t.minutes += line.minutesPlayed;
      t.points += line.points;
      t.rebounds += line.totalRebounds;
      t.assists += line.assists;
      t.steals += line.steals;
      t.blocks += line.blocks;
      t.turnovers += line.turnovers;
      t.fieldGoalsMade += line.fieldGoalsMade;
      t.fieldGoalAttempts += line.fieldGoalAttempts;
      t.threePointersMade += line.threePointersMade;
      t.threePointAttempts += line.threePointAttempts;
      t.freeThrowsMade += line.freeThrowsMade;
      t.freeThrowAttempts += line.freeThrowAttempts;
    }
  }

  return {
    for (final entry in totals.entries)
      entry.key: PlayerSeasonTotals(
        playerId: entry.key,
        gamesPlayed: entry.value.gamesPlayed,
        minutes: entry.value.minutes,
        points: entry.value.points,
        rebounds: entry.value.rebounds,
        assists: entry.value.assists,
        steals: entry.value.steals,
        blocks: entry.value.blocks,
        turnovers: entry.value.turnovers,
        fieldGoalsMade: entry.value.fieldGoalsMade,
        fieldGoalAttempts: entry.value.fieldGoalAttempts,
        threePointersMade: entry.value.threePointersMade,
        threePointAttempts: entry.value.threePointAttempts,
        freeThrowsMade: entry.value.freeThrowsMade,
        freeThrowAttempts: entry.value.freeThrowAttempts,
      ),
  };
}
