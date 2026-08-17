import '../../player/domain/player.dart';
import 'match_event.dart';

/// The full result of simulating one game: final score, the complete
/// event log every possession fed into (in chronological order -- the box
/// score and any future play-by-play feed both reduce over this), and the
/// per-player numbers a box score needs that don't live on individual
/// events (minutes played, fouls committed).
class MatchResult {
  const MatchResult({
    required this.homeScore,
    required this.awayScore,
    required this.homeScoreByQuarter,
    required this.awayScoreByQuarter,
    required this.events,
    required this.minutesPlayed,
    required this.personalFouls,
    required this.fouledOut,
    required this.finalEnergy,
  });

  /// Never equal to [awayScore] -- `simulateMatch` plays overtime periods
  /// until the tie breaks, same as a real game.
  final int homeScore;
  final int awayScore;

  /// Points scored per period, index 0 = Q1. Usually length 4, but longer
  /// if the game went to overtime (index 4+ = OT periods).
  final List<int> homeScoreByQuarter;
  final List<int> awayScoreByQuarter;

  final List<MatchEvent> events;

  /// Minutes actually played, keyed by player -- distinct from each
  /// player's *target* minutes (`substitution_policy.dart`), which is
  /// just the goal the substitution policy chases.
  final Map<Player, double> minutesPlayed;
  final Map<Player, int> personalFouls;

  /// Players who reached 6 personal fouls and were substituted out for
  /// the rest of the game.
  final Set<Player> fouledOut;

  /// Each of the 24 rostered players' energy (`fatigue.dart`) at the
  /// final buzzer, 0-100 -- tracked for the whole game (not just whoever
  /// finished on court). The in-game fatigue penalty itself is already
  /// real (`possession_engine.dart`'s `_fatigueBonus`) whether or not
  /// anything ever reads this field; it exists on `MatchResult` (not
  /// just as an internal engine detail) specifically so a *post-game*
  /// consumer can too -- e.g. a future "most tired players" callout to
  /// help the GM see who to rest more (a direct GM ask, 2026-08-17), or
  /// a rotation-slot suggestion off of it. No such consumer exists yet.
  /// Same transient-window lifetime as [events]/[minutesPlayed] today
  /// (`GameResultScreen`'s own doc comment: once that screen is gone,
  /// only the lean `PlayedGame` survives in the save) -- never persisted,
  /// never read past one `MatchResult`, matching the GM's own call that
  /// fatigue doesn't carry between games either.
  final Map<Player, double> finalEnergy;
}
