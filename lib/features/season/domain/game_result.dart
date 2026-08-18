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

/// Finds whichever of [results] belongs to [ownAbbreviation] -- pulling the
/// GM's own game out of a whole game day's batch (`advanceGameDay`,
/// `advanceGameDayWithOwnResult`) so a caller can show it distinctly
/// (`GameResultScreen`) instead of letting it disappear into the standings
/// like every other team's result that day. Shared by
/// `MatchPreviewScreen`'s Sim Instantly path and `LiveGameLabScreen`'s
/// Watch Live completion handler (2026-08-18, `TODO.md` item 8's live-game
/// architecture stage 5) -- both need the exact same lookup. Returns `null`
/// if there's no such game -- shouldn't happen from a real GM flow (both
/// callers only ever run this on a day the GM's own team was actually
/// scheduled), but every caller already treats that the same "fail safely
/// back" way rather than crashing on a null result.
GameResult? ownGameResultFrom(
  List<GameResult>? results,
  String ownAbbreviation,
) {
  if (results == null) return null;
  for (final result in results) {
    if (result.game.homeTeamAbbreviation == ownAbbreviation ||
        result.game.awayTeamAbbreviation == ownAbbreviation) {
      return result;
    }
  }
  return null;
}
