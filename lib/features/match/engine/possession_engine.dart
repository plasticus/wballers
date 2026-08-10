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

/// Point margin at which the leading team starts protecting its lead by
/// slowing the pace down on its own possessions -- a direct GM ask
/// (2026-08-10, TODO.md item 5): longer possessions to eat clock and cut
/// down on 40+ point blowouts, explicitly *not* weaker shooting or any
/// other stat change -- pacing/clock management only. Only the
/// possession belonging to the team that's ahead by this much slows
/// down; the trailing team keeps playing at a normal pace, still trying
/// to come back, same as real basketball's "up big, milk the clock"
/// instinct not applying to whoever's behind.
const kBlowoutPaceMargin = 20;

/// How much longer each action runs, on top of the normal 1-5s roll,
/// once [kBlowoutPaceMargin] kicks in -- empirically tuned via a real
/// before/after diagnostic (500-game samples of realistic AI-vs-AI
/// matchups, `generateAiRoster`), not a guess. Without this, 40+ margins
/// hit ~1.2-2.8% of games (max observed 72) and 50+ margins weren't
/// unheard of; at 5.0, 40+ margins all but disappeared (0-1 per 500
/// across two independent seed ranges, max observed 40) while a
/// genuinely dominant team (a large, real rating gap, not just typical
/// AI-vs-AI variance) can still win by 30-70 -- this softens the
/// ordinary case without capping real separation when a team actually
/// is that much better. Values above ~6 stopped helping and started
/// reversing (fewer, longer possessions means less of the shot clock's
/// own natural smoothing survives per game) -- 5.0 sits past that curve.
const _kBlowoutPaceActionBonusSeconds = 5.0;

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

/// Chance that an already-missed, non-fouled shot gets specifically
/// attributed to the contesting defender as a block, via
/// [PlayerRatings.blocking] against the shooter's own shot rating.
/// Doesn't change whether the shot goes in -- that's already decided by
/// the time this rolls -- just whether this particular miss gets
/// credited as a block for box-score purposes. Initial guess, not yet
/// calibrated.
const _blockRateFloor = 0.03;
const _blockRateCeiling = 0.25;
const _blockRateSteepness = 0.03;

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

double _rollActionSeconds(Random random, {bool isProtectingLead = false}) {
  final base =
      _minActionSeconds +
      random.nextDouble() * (_maxActionSeconds - _minActionSeconds);
  return isProtectingLead ? base + _kBlowoutPaceActionBonusSeconds : base;
}

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
/// [offenseMargin] is [offense]'s score minus [defense]'s score right
/// before this possession -- `>=` [kBlowoutPaceMargin] slows every action
/// in *this* possession down (`_rollActionSeconds`'s `isProtectingLead`),
/// nothing else. Defaults to 0 (never protecting a lead) for any caller
/// that doesn't track a running score -- every real game does
/// (`match_engine.dart`), but a possession-level test shouldn't have to.
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
  int offenseMargin = 0,
}) {
  assert(offense.length == 5, 'offense must have exactly 5 players on court');
  assert(defense.length == 5, 'defense must have exactly 5 players on court');
  final isProtectingLead = offenseMargin >= kBlowoutPaceMargin;

  final events = <MatchEvent>[];
  var shotClock = _shotClockSeconds;
  var totalElapsed = 0.0;
  var ballHandler = _randomOf(random, offense);
  // Whoever threw the most recent clean pass -- credited with an assist
  // if [ballHandler] scores on the very next shot attempt, cleared after
  // any shot attempt (make or miss) so it never carries across more than
  // one beat.
  Player? assistCandidate;

  PossessionResult finish(PossessionEnd end, int points) {
    return PossessionResult(
      events: events,
      end: end,
      pointsScored: points,
      secondsElapsed: totalElapsed,
    );
  }

  while (true) {
    final actionSeconds = _rollActionSeconds(
      random,
      isProtectingLead: isProtectingLead,
    );
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
        assistCandidate = ballHandler;
        ballHandler = target;
        continue;
      }

      // Any disruption breaks the clean flow of the play, whether or not
      // the offense ends up keeping the ball -- no assist survives a
      // scramble.
      assistCandidate = null;
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
            secondPlayer: ballHandler,
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

    final isThree = !isDrive && random.nextDouble() < _threePointAttemptRate;
    final attemptPoints = isThree ? 3 : 2;
    events.add(
      MatchEvent(
        type: MatchEventType.shotAttempt,
        secondsElapsed: actionSeconds,
        player: ballHandler,
        secondPlayer: defender,
        isThreePointAttempt: isThree,
      ),
    );
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
    // The assist window only ever covers the very next shot attempt --
    // consumed here regardless of what happens to this one.
    final scoringAssist = assistCandidate;
    assistCandidate = null;

    if (fouled) {
      events.add(
        MatchEvent(
          type: made ? MatchEventType.shotMade : MatchEventType.shotMissed,
          secondsElapsed: 0,
          player: ballHandler,
          points: made ? attemptPoints : null,
          isThreePointAttempt: isThree,
        ),
      );
      if (made && scoringAssist != null) {
        events.add(
          MatchEvent(
            type: MatchEventType.assist,
            secondsElapsed: 0,
            player: scoringAssist,
            secondPlayer: ballHandler,
          ),
        );
      }
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
          isThreePointAttempt: isThree,
        ),
      );
      if (scoringAssist != null) {
        events.add(
          MatchEvent(
            type: MatchEventType.assist,
            secondsElapsed: 0,
            player: scoringAssist,
            secondPlayer: ballHandler,
          ),
        );
      }
      return finish(PossessionEnd.scored, attemptPoints);
    }

    events.add(
      MatchEvent(
        type: MatchEventType.shotMissed,
        secondsElapsed: 0,
        player: ballHandler,
        isThreePointAttempt: isThree,
      ),
    );
    final blocked = resolveContest(
      random,
      attackerRating: defender.ratings.blocking,
      defenderRating: shooterRating,
      floor: _blockRateFloor,
      ceiling: _blockRateCeiling,
      steepness: _blockRateSteepness,
    );
    if (blocked) {
      events.add(
        MatchEvent(
          type: MatchEventType.shotBlocked,
          secondsElapsed: 0,
          player: defender,
          secondPlayer: ballHandler,
        ),
      );
    }
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
