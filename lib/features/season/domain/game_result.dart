import '../../match/domain/match_result.dart';
import 'scheduled_game.dart';

/// The outcome of one [ScheduledGame] -- the fixture plus the full engine
/// output for it. [MatchResult.homeScore] is never equal to
/// [MatchResult.awayScore] (`simulateMatch` plays overtime until the tie
/// breaks), so [winningTeamAbbreviation] is always well-defined.
class GameResult {
  const GameResult({required this.game, required this.match});

  final ScheduledGame game;
  final MatchResult match;

  String get winningTeamAbbreviation => match.homeScore > match.awayScore
      ? game.homeTeamAbbreviation
      : game.awayTeamAbbreviation;

  String get losingTeamAbbreviation => match.homeScore > match.awayScore
      ? game.awayTeamAbbreviation
      : game.homeTeamAbbreviation;

  /// The winning team's margin of victory -- always positive. Used by the
  /// Continental Cup's Round 1 -> Round 2 bye determination
  /// (`continental_cup_generator.dart`).
  int get winningMargin => (match.homeScore - match.awayScore).abs();
}
