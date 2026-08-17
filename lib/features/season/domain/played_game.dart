import '../../match/domain/match_result.dart';
import '../../match/domain/player_box_score.dart';
import '../../player/domain/player.dart';
import 'game_result.dart';
import 'played_game_stat_line.dart';
import 'scheduled_game.dart';

/// A completed game, trimmed down to just what's worth persisting for a
/// whole season's history: the fixture, the final score, and a compact
/// per-player box score. Deliberately *not* a full `GameResult`/
/// `MatchResult` -- those carry a possession-by-possession event log
/// referencing full `Player` objects, which would blow up save-file size
/// if kept for all ~300 games in a season. A just-played game's full
/// detail is a transient, in-memory-only thing (e.g. showing a play-by-
/// play right after playing) that gets trimmed down to a [PlayedGame]
/// before it's appended to season history -- the box score is the one
/// piece of that detail worth keeping around afterward too (see
/// [boxScoreByPlayerId]), everything else about *how* the game unfolded
/// is gone once this trim happens.
class PlayedGame {
  const PlayedGame({
    required this.game,
    required this.homeScore,
    required this.awayScore,
    this.minutesByPlayerId = const {},
    this.boxScoreByPlayerId = const {},
  }) : assert(homeScore != awayScore, 'a completed game is never a tie');

  final ScheduledGame game;
  final int homeScore;
  final int awayScore;

  /// Minutes played, keyed by `Player.id` rather than the full `Player`
  /// object `MatchResult.minutesPlayed` uses -- lean enough to persist
  /// for a whole season (a ~12-entry map of id->double per game) without
  /// the event-log/full-`Player` bloat the rest of this class exists to
  /// avoid. What `features/training/`'s weekly growth engine sums to know
  /// how many reps a player got -- nothing else needs this.
  final Map<String, double> minutesByPlayerId;

  /// Every player who appeared in this game, keyed by `Player.id`, with
  /// their full stat line (`PlayedGameStatLine`) -- what the Results
  /// screen (`season/presentation/results_screen.dart`) shows for any
  /// past game, and what a future player-detail screen's season stats can
  /// aggregate from directly, without needing to re-simulate anything.
  /// Deliberately *not* reconstructed on demand by replaying the season:
  /// `features/training/` mutates roster ratings week over week, so a
  /// replay using *current* ratings wouldn't reliably reproduce the exact
  /// outcome a game actually had back when it was played -- this is
  /// computed once, from the real `MatchResult`, at the moment
  /// [fromResult] runs, and never touched again.
  final Map<String, PlayedGameStatLine> boxScoreByPlayerId;

  /// Trims a full [GameResult] down to what's worth persisting -- the one
  /// place `MatchResult`'s `Player`-keyed maps and event log get reduced
  /// to the leaner id-keyed summaries this class actually stores, so
  /// `season_advancer.dart` and `postseason_advancer.dart` don't each
  /// reimplement it. [rostersByAbbreviation] needs at least the two teams
  /// [result.game] references -- same map shape `advanceToNextGameDay`/
  /// `simulatePostseason` already thread through for `computeBoxScore`'s
  /// turnover-crossed-team-lines check.
  factory PlayedGame.fromResult(
    GameResult result, {
    required Map<String, List<Player>> rostersByAbbreviation,
  }) {
    final boxScore = computeBoxScore(
      result.match,
      homeRoster:
          rostersByAbbreviation[result.game.homeTeamAbbreviation] ?? const [],
      awayRoster:
          rostersByAbbreviation[result.game.awayTeamAbbreviation] ?? const [],
    );
    return PlayedGame(
      game: result.game,
      homeScore: result.match.homeScore,
      awayScore: result.match.awayScore,
      minutesByPlayerId: {
        for (final entry in result.match.minutesPlayed.entries)
          entry.key.id: entry.value,
      },
      boxScoreByPlayerId: {
        for (final line in boxScore) line.player.id: _statLineOf(line),
      },
    );
  }

  String get winningTeamAbbreviation => homeScore > awayScore
      ? game.homeTeamAbbreviation
      : game.awayTeamAbbreviation;

  String get losingTeamAbbreviation =>
      winningTeamAbbreviation == game.homeTeamAbbreviation
      ? game.awayTeamAbbreviation
      : game.homeTeamAbbreviation;

  /// Wraps this back into a [GameResult] with a score-only [MatchResult]
  /// (empty event log/minutes/fouls) -- lets a season's played-game history
  /// feed straight into `computeStandings` and the Continental
  /// Cup/postseason generators, which all already operate on [GameResult],
  /// without a parallel reimplementation of the same logic.
  GameResult toGameResult() {
    return GameResult(
      game: game,
      match: MatchResult(
        homeScore: homeScore,
        awayScore: awayScore,
        homeScoreByQuarter: [homeScore],
        awayScoreByQuarter: [awayScore],
        events: const [],
        minutesPlayed: const {},
        personalFouls: const {},
        fouledOut: const {},
        finalEnergy: const {},
      ),
    );
  }
}

/// Narrows a [PlayerBoxScore] (which embeds a full [Player]) down to the
/// id-keyed [PlayedGameStatLine] this class actually persists.
PlayedGameStatLine _statLineOf(PlayerBoxScore line) {
  return PlayedGameStatLine(
    minutesPlayed: line.minutesPlayed,
    points: line.points,
    fieldGoalsMade: line.fieldGoalsMade,
    fieldGoalAttempts: line.fieldGoalAttempts,
    threePointersMade: line.threePointersMade,
    threePointAttempts: line.threePointAttempts,
    freeThrowsMade: line.freeThrowsMade,
    freeThrowAttempts: line.freeThrowAttempts,
    offensiveRebounds: line.offensiveRebounds,
    defensiveRebounds: line.defensiveRebounds,
    assists: line.assists,
    steals: line.steals,
    blocks: line.blocks,
    turnovers: line.turnovers,
    personalFouls: line.personalFouls,
  );
}
