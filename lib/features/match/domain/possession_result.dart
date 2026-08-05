import 'match_event.dart';

/// How a possession ended -- which team the ball goes to next follows
/// directly: every value hands the ball to the team that was on defense.
/// They're kept distinct because they're different box-score stats, not
/// because they lead anywhere different next.
enum PossessionEnd {
  scored,
  turnover,
  defensiveRebound,

  /// A foul sends the shooter (or fouled ball handler, on a bonus
  /// non-shooting foul) to the line, but no free throws went in -- not a
  /// turnover (the offense didn't lose the ball to a live defensive play)
  /// and not a rebound (there's no rebound off a missed free throw in this
  /// engine -- see `possession_engine.dart`'s doc comment).
  deadBallStop,
}

/// The full result of simulating one possession: every beat that happened
/// ([events], in order), how it ended, and the two numbers a game loop
/// actually needs to keep going -- points to add to the offense's score
/// and how much game clock to burn.
class PossessionResult {
  const PossessionResult({
    required this.events,
    required this.end,
    required this.pointsScored,
    required this.secondsElapsed,
  });

  final List<MatchEvent> events;
  final PossessionEnd end;
  final int pointsScored;
  final double secondsElapsed;
}
