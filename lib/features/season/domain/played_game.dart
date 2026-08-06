import '../../match/domain/match_result.dart';
import 'game_result.dart';
import 'scheduled_game.dart';

/// A completed game, trimmed down to just what's worth persisting for a
/// whole season's history: the fixture and the final score. Deliberately
/// *not* a full `GameResult`/`MatchResult` -- those carry a possession-by-
/// possession event log referencing full `Player` objects, which would
/// blow up save-file size if kept for all ~300 games in a season. A
/// just-played game's full detail is a transient, in-memory-only thing
/// (e.g. showing a box score right after playing) that gets trimmed down
/// to a [PlayedGame] before it's appended to season history.
class PlayedGame {
  const PlayedGame({
    required this.game,
    required this.homeScore,
    required this.awayScore,
    this.minutesByPlayerId = const {},
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

  /// Trims a full [GameResult] down to what's worth persisting -- the
  /// one place `minutesPlayed`'s `Player`-keyed map gets narrowed to the
  /// leaner id-keyed one this class actually stores, so `season_advancer.dart`
  /// and `postseason_advancer.dart` don't each reimplement it.
  factory PlayedGame.fromResult(GameResult result) {
    return PlayedGame(
      game: result.game,
      homeScore: result.match.homeScore,
      awayScore: result.match.awayScore,
      minutesByPlayerId: {
        for (final entry in result.match.minutesPlayed.entries)
          entry.key.id: entry.value,
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
      ),
    );
  }
}
