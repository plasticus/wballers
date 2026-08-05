import '../../player/domain/player.dart';

/// What kind of beat a [MatchEvent] represents. The box score and any
/// future play-by-play/commentary text are both built by reducing over a
/// game's event log, not tracked separately -- this is the one source of
/// truth for what happened.
enum MatchEventType {
  tipOff,
  passAttempt,
  passDisrupted,
  steal,
  passRedirected,
  passOutOfBounds,
  shotAttempt,
  shotMade,
  shotMissed,
  offensiveRebound,
  defensiveRebound,
  shotClockViolation,
  shootingFoul,
  nonShootingFoul,
  freeThrowMade,
  freeThrowMissed,
}

/// One resolved beat of a possession. [type] discriminates which of the
/// nullable fields are populated -- same pattern as `ScheduledGame`'s
/// [GameType]/`continentalCupRound`.
class MatchEvent {
  const MatchEvent({
    required this.type,
    required this.secondsElapsed,
    this.player,
    this.secondPlayer,
    this.points,
  });

  final MatchEventType type;

  /// Simulated game-clock time this single beat consumed.
  final double secondsElapsed;

  /// The player primarily responsible for this event -- the passer,
  /// shooter, rebounder, tip-off jumper, the defender credited with a
  /// steal, or (for [MatchEventType.shootingFoul]/[nonShootingFoul]) the
  /// defender who committed the foul.
  final Player? player;

  /// A second player involved, when relevant: the pass target, the
  /// defender who contested a shot or forced a disruption, the opposing
  /// jumper at a tip-off, or the player fouled.
  final Player? secondPlayer;

  /// Points scored by this event. Set for [MatchEventType.shotMade] and
  /// [MatchEventType.freeThrowMade] (always 1 for a free throw).
  final int? points;
}
