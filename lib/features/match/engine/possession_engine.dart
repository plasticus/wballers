import 'dart:math';

import '../../player/domain/player.dart';
import '../domain/match_event.dart';
import '../domain/possession_result.dart';
import 'contest_resolver.dart';

/// Full shot clock, in seconds.
const _shotClockSeconds = 24.0;

/// Shot clock reset after an offensive rebound (real-rules value: shorter
/// than a fresh possession since the defense didn't get to reset either).
const _offensiveReboundShotClock = 14.0;

/// Every action takes 1-5 seconds ("3 seconds, +/- 2"), uniformly.
const _minActionSeconds = 1.0;
const _maxActionSeconds = 5.0;

/// Below this many seconds left, the ball handler stops considering a pass
/// and is forced into a shot -- nobody holds the ball into a shot-clock
/// violation on purpose.
const _forcedShotThreshold = 4.0;

/// Ball-handler decision weights with time still on the clock. Tuned
/// (2026-08-05) so an average possession runs ~4-5 actions before a shot
/// goes up -- a real WNBA possession averages roughly 14-15 seconds of
/// live clock (two teams sharing ~80 possessions each across a 40-minute
/// game), and at ~3 seconds/action that means ~5 actions, not the ~2 the
/// original 0.55/0.25 split produced. Empirically verified via a
/// throwaway full-game sanity check, not derived from real shot-selection
/// data -- still an approximation, just a better-aimed one.
const _passWeight = 0.82;
const _driveWeight = 0.10;
// Remaining weight (1 - pass - drive) goes to a jump-shot attempt.

/// Disrupted-pass sub-outcomes: most disruptions are stolen outright, some
/// get redirected to a random player on the floor, some are a reach-in
/// foul, and a few just go out of bounds. Initial guess, not yet
/// calibrated.
const _stealWeight = 0.45;
const _redirectWeight = 0.25;
const _reachInFoulRate = 0.15;
// Remaining weight goes out of bounds.

/// Of all jump-shot attempts, how many are three-point attempts rather
/// than mid-range -- there's no separate three-point rating yet
/// ([perimeterOffense] covers both), so this is a flat rate rather than
/// something that varies by player.
const _threePointAttemptRate = 0.4;

/// Shooting-foul rates per shot type -- drives to the rim draw contact far
/// more often than jump shots do, same as real basketball. Initial guess,
/// not yet calibrated.
const _driveFoulRate = 0.15;
const _jumperFoulRate = 0.06;

/// Shot-success curves per shot type. Ceilings trimmed down from an
/// earlier pass (2026-08-05, alongside the `_passWeight` retune) -- a
/// full-game sanity check was landing meaningfully above real WNBA
/// scoring even after the pacing fix, and shot efficiency (plus and-1/
/// bonus free-throw points layered on top of it) was the remaining
/// contributor. Still an approximation pending real calibration.
const _driveShotFloor = 0.15;
const _driveShotCeiling = 0.78;
const _driveShotSteepness = 0.04;
const _jumperShotFloor = 0.10;
const _jumperShotCeiling = 0.65;
const _jumperShotSteepness = 0.035;

/// Free throws are resolved against a fixed neutral rating rather than a
/// real defender -- nobody contests a free throw.
const _neutralFreeThrowDefense = 50;
const _freeThrowFloor = 0.55;
const _freeThrowCeiling = 0.95;

/// How often a pass attempt stays clean. Raised alongside `_passWeight`
/// (2026-08-05): with possessions now averaging several pass attempts
/// instead of ~1, the original 0.55/0.95 (25% disruption chance at equal
/// ratings) compounded into a far-too-high team turnover rate. 0.90/0.99
/// (~5.5% at equal ratings) was the empirically-checked replacement --
/// turnovers accumulate from repeated exposure across a possession, not
/// from any single pass being especially risky.
const _passCleanFloor = 0.90;
const _passCleanCeiling = 0.99;

enum _BallHandlerChoice { pass, drive, jumper }

int _averageRating(int a, int b) => ((a + b) / 2).round();

double _rollActionSeconds(Random random) =>
    _minActionSeconds +
    random.nextDouble() * (_maxActionSeconds - _minActionSeconds);

_BallHandlerChoice _chooseAction(Random random, double shotClockRemaining) {
  if (shotClockRemaining <= _forcedShotThreshold) {
    return random.nextBool()
        ? _BallHandlerChoice.drive
        : _BallHandlerChoice.jumper;
  }
  final roll = random.nextDouble();
  if (roll < _passWeight) return _BallHandlerChoice.pass;
  if (roll < _passWeight + _driveWeight) return _BallHandlerChoice.drive;
  return _BallHandlerChoice.jumper;
}

Player _randomOther(Random random, List<Player> players, Player exclude) {
  final options = players.where((p) => p != exclude).toList();
  return options[random.nextInt(options.length)];
}

Player _randomOf(Random random, List<Player> players) =>
    players[random.nextInt(players.length)];

/// Contests a rebound after a missed shot: strength + interiorOffense for
/// the offense, strength + interiorDefense for the defense (the universal
/// formula, per `PlayerRatings`' doc comment), between one random
/// rebounder on each side. [ceiling] is capped below 50/50 favoring the
/// defense -- offensive rebounds are the exception, not the norm.
({bool offensiveRebound, Player rebounder}) _resolveRebound(
  Random random,
  List<Player> offense,
  List<Player> defense,
) {
  final offensiveRebounder = _randomOf(random, offense);
  final defensiveRebounder = _randomOf(random, defense);
  final offenseWins = resolveContest(
    random,
    attackerRating: _averageRating(
      offensiveRebounder.ratings.strength,
      offensiveRebounder.ratings.interiorOffense,
    ),
    defenderRating: _averageRating(
      defensiveRebounder.ratings.strength,
      defensiveRebounder.ratings.interiorDefense,
    ),
    floor: 0.05,
    ceiling: 0.6,
  );
  return (
    offensiveRebound: offenseWins,
    rebounder: offenseWins ? offensiveRebounder : defensiveRebounder,
  );
}

/// Shoots [attempts] free throws for [shooter], appending a made/missed
/// event for each, and returns how many went in. Resolved against a fixed
/// neutral rating (`_neutralFreeThrowDefense`) via [perimeterOffense] as
/// the closest existing proxy for touch -- there's no dedicated
/// free-throw rating.
int _shootFreeThrows(
  Random random,
  List<MatchEvent> events,
  Player shooter,
  int attempts,
) {
  var made = 0;
  for (var i = 0; i < attempts; i++) {
    final success = resolveContest(
      random,
      attackerRating: shooter.ratings.perimeterOffense,
      defenderRating: _neutralFreeThrowDefense,
      floor: _freeThrowFloor,
      ceiling: _freeThrowCeiling,
    );
    events.add(
      MatchEvent(
        type: success
            ? MatchEventType.freeThrowMade
            : MatchEventType.freeThrowMissed,
        secondsElapsed: 0,
        player: shooter,
        points: success ? 1 : null,
      ),
    );
    if (success) made++;
  }
  return made;
}

/// Simulates one possession from the moment [offense] gains the ball to
/// the moment it ends -- a make, a turnover, a defensive rebound, a
/// shot-clock violation, or a dead-ball stop after a foul that produced no
/// points. Deterministic for a given [random] stream, same pattern as the
/// rest of generation: pass the same stream across a whole game so
/// possessions chain off one seed.
///
/// [offense] and [defense] are each the 5 players currently on the floor
/// for their team. [defenseInBonus] controls whether a non-shooting
/// (reach-in) foul sends the offense to the line -- shooting fouls always
/// do, regardless of bonus, same as real rules.
///
/// There's no court-position model yet (`0B_Planned.md`'s Phase 4 court
/// presentation): "driving" and "shooting a jumper" are modeled as a
/// choice between [PlayerRatings.interiorOffense] and
/// [PlayerRatings.perimeterOffense] rather than actual movement toward the
/// basket, reusing the split those ratings were already built for. There's
/// also no live rebound off a missed free throw -- the possession always
/// ends once free throws are done, make or miss on the last one.
PossessionResult simulatePossession(
  Random random, {
  required List<Player> offense,
  required List<Player> defense,
  bool defenseInBonus = false,
}) {
  assert(offense.length == 5, 'offense must have exactly 5 players on court');
  assert(defense.length == 5, 'defense must have exactly 5 players on court');

  final events = <MatchEvent>[];
  var shotClock = _shotClockSeconds;
  var totalElapsed = 0.0;
  var ballHandler = _randomOf(random, offense);

  PossessionResult finish(PossessionEnd end, int points) {
    return PossessionResult(
      events: events,
      end: end,
      pointsScored: points,
      secondsElapsed: totalElapsed,
    );
  }

  while (true) {
    final actionSeconds = _rollActionSeconds(random);
    if (actionSeconds >= shotClock) {
      totalElapsed += shotClock;
      events.add(
        MatchEvent(
          type: MatchEventType.shotClockViolation,
          secondsElapsed: shotClock,
          player: ballHandler,
        ),
      );
      return finish(PossessionEnd.turnover, 0);
    }
    shotClock -= actionSeconds;
    totalElapsed += actionSeconds;

    final choice = _chooseAction(random, shotClock);

    if (choice == _BallHandlerChoice.pass) {
      final target = _randomOther(random, offense, ballHandler);
      final defender = _randomOf(random, defense);
      final clean = resolveContest(
        random,
        attackerRating: _averageRating(
          ballHandler.ratings.agility,
          ballHandler.ratings.passing,
        ),
        defenderRating: _averageRating(
          defender.ratings.agility,
          defender.ratings.disruption,
        ),
        floor: _passCleanFloor,
        ceiling: _passCleanCeiling,
      );
      events.add(
        MatchEvent(
          type: MatchEventType.passAttempt,
          secondsElapsed: actionSeconds,
          player: ballHandler,
          secondPlayer: target,
        ),
      );
      if (clean) {
        ballHandler = target;
        continue;
      }

      events.add(
        MatchEvent(
          type: MatchEventType.passDisrupted,
          secondsElapsed: 0,
          player: defender,
          secondPlayer: ballHandler,
        ),
      );
      final disruptionRoll = random.nextDouble();
      if (disruptionRoll < _stealWeight) {
        events.add(
          MatchEvent(
            type: MatchEventType.steal,
            secondsElapsed: 0,
            player: defender,
            secondPlayer: ballHandler,
          ),
        );
        return finish(PossessionEnd.turnover, 0);
      } else if (disruptionRoll < _stealWeight + _redirectWeight) {
        final everyone = [...offense, ...defense];
        final recoverer = _randomOther(random, everyone, ballHandler);
        events.add(
          MatchEvent(
            type: MatchEventType.passRedirected,
            secondsElapsed: 0,
            player: recoverer,
          ),
        );
        if (offense.contains(recoverer)) {
          ballHandler = recoverer;
          continue;
        }
        return finish(PossessionEnd.turnover, 0);
      } else if (disruptionRoll <
          _stealWeight + _redirectWeight + _reachInFoulRate) {
        events.add(
          MatchEvent(
            type: MatchEventType.nonShootingFoul,
            secondsElapsed: 0,
            player: defender,
            secondPlayer: ballHandler,
          ),
        );
        if (!defenseInBonus) {
          // Dead ball, but not enough to send anyone to the line -- the
          // offense just keeps the ball and play continues.
          continue;
        }
        final freeThrowPoints = _shootFreeThrows(
          random,
          events,
          ballHandler,
          2,
        );
        return finish(
          freeThrowPoints > 0
              ? PossessionEnd.scored
              : PossessionEnd.deadBallStop,
          freeThrowPoints,
        );
      } else {
        events.add(
          MatchEvent(
            type: MatchEventType.passOutOfBounds,
            secondsElapsed: 0,
            player: ballHandler,
          ),
        );
        return finish(PossessionEnd.turnover, 0);
      }
    }

    // A shot attempt: interior (a "drive") or perimeter (a "jumper"),
    // sharing everything past "which two ratings contest each other."
    final isDrive = choice == _BallHandlerChoice.drive;
    final defender = _randomOf(random, defense);
    final shooterRating = isDrive
        ? _averageRating(
            ballHandler.ratings.strength,
            ballHandler.ratings.interiorOffense,
          )
        : _averageRating(
            ballHandler.ratings.agility,
            ballHandler.ratings.perimeterOffense,
          );
    final defenderRating = isDrive
        ? _averageRating(
            defender.ratings.strength,
            defender.ratings.interiorDefense,
          )
        : _averageRating(
            defender.ratings.agility,
            defender.ratings.perimeterDefense,
          );

    events.add(
      MatchEvent(
        type: MatchEventType.shotAttempt,
        secondsElapsed: actionSeconds,
        player: ballHandler,
        secondPlayer: defender,
      ),
    );
    final isThree = !isDrive && random.nextDouble() < _threePointAttemptRate;
    final attemptPoints = isThree ? 3 : 2;
    final made = resolveContest(
      random,
      attackerRating: shooterRating,
      defenderRating: defenderRating,
      floor: isDrive ? _driveShotFloor : _jumperShotFloor,
      ceiling: isDrive ? _driveShotCeiling : _jumperShotCeiling,
      steepness: isDrive ? _driveShotSteepness : _jumperShotSteepness,
    );
    final fouled =
        random.nextDouble() < (isDrive ? _driveFoulRate : _jumperFoulRate);

    if (fouled) {
      events.add(
        MatchEvent(
          type: made ? MatchEventType.shotMade : MatchEventType.shotMissed,
          secondsElapsed: 0,
          player: ballHandler,
          points: made ? attemptPoints : null,
        ),
      );
      events.add(
        MatchEvent(
          type: MatchEventType.shootingFoul,
          secondsElapsed: 0,
          player: defender,
          secondPlayer: ballHandler,
        ),
      );
      final freeThrowAttempts = made ? 1 : attemptPoints;
      final freeThrowPoints = _shootFreeThrows(
        random,
        events,
        ballHandler,
        freeThrowAttempts,
      );
      final totalPoints = (made ? attemptPoints : 0) + freeThrowPoints;
      return finish(
        totalPoints > 0 ? PossessionEnd.scored : PossessionEnd.deadBallStop,
        totalPoints,
      );
    }

    if (made) {
      events.add(
        MatchEvent(
          type: MatchEventType.shotMade,
          secondsElapsed: 0,
          player: ballHandler,
          points: attemptPoints,
        ),
      );
      return finish(PossessionEnd.scored, attemptPoints);
    }

    events.add(
      MatchEvent(
        type: MatchEventType.shotMissed,
        secondsElapsed: 0,
        player: ballHandler,
      ),
    );
    final rebound = _resolveRebound(random, offense, defense);
    events.add(
      MatchEvent(
        type: rebound.offensiveRebound
            ? MatchEventType.offensiveRebound
            : MatchEventType.defensiveRebound,
        secondsElapsed: 0,
        player: rebound.rebounder,
      ),
    );
    if (!rebound.offensiveRebound) {
      return finish(PossessionEnd.defensiveRebound, 0);
    }
    ballHandler = rebound.rebounder;
    shotClock = _offensiveReboundShotClock;
  }
}
