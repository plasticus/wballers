import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../matchup/domain/coaching_option.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player.dart';
import '../../player/domain/trait.dart';
import '../domain/match_event.dart';
import '../domain/possession_result.dart';
import 'contest_resolver.dart';
import 'fatigue.dart';

/// "No effect" defaults for [simulatePossession]'s `offenseBonus`/
/// `defenseBonus` params -- every field zero, so omitting them (every
/// possession-level test that doesn't care about lineup shape or
/// defensive tactic) behaves exactly like before either concept existed.
const _noOffenseBonus = (interior: 0.0, perimeter: 0.0, passing: 0.0);
const _noDefenseBonus = (
  interior: 0.0,
  perimeter: 0.0,
  disruption: 0.0,
  targetedBonus: 0.0,
  spreadThinPenalty: 0.0,
);

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

/// Flat rating bump every home-team player gets for the game (TODO.md
/// item 11, a direct GM ask -- "at home, every home-team player's
/// in-game stats get a flat +2.5% bump"). Applied per underlying rating
/// before any averaging/contest math, not to a final blended number, so
/// it reads the same regardless of which two ratings a given contest
/// happens to combine.
const kHomeAdvantageBonus = 0.025;

/// Additional bump for a home player with [Trait.homeCourtHero] -- stacks
/// on top of [kHomeAdvantageBonus] rather than replacing it, per the
/// GM's own spec ("an additional +5% at home, stacking with the base
/// bump").
const kHomeCourtHeroBonus = 0.05;

/// Bump for a visiting player with [Trait.roadWarrior] -- independent of
/// [kHomeAdvantageBonus], since the away team never gets that bump to
/// begin with.
const kRoadWarriorBonus = 0.05;

/// Per-point conversion of a coach stat's gap from the neutral midpoint
/// (50) into a rating multiplier ([coachQualityBonus]) -- 0.2% per point,
/// the GM's own worked example (2026-08-20, replacing the earlier
/// opponent-relative [kCoachMatchupBonusPerPoint] model outright): "a
/// 60O/55D coach gets a 2% offense bump, 1% defense bump." No separate
/// cap needed -- the real coach-generation range (`kCoachMinStat`-
/// `kCoachMaxStat`, 30-79) only ever produces roughly -4% to +5.8%, well
/// under the biggest trait bonuses already in this engine
/// ([kHomeCourtHeroBonus]/[kRoadWarriorBonus], both 5%).
const kCoachQualityBonusPerPoint = 0.002;

enum _BallHandlerChoice { pass, drive, jumper }

/// [player]'s current fatigue penalty (`fatigue.dart`'s [fatigueBonusFor],
/// 0 or negative), read out of [energy] -- missing from the map (a caller
/// that doesn't track fatigue at all, e.g. most possession-level tests)
/// reads as [kMaxEnergy], i.e. no penalty, same "opt-in only" posture
/// every other bonus in this file already has. Meant to be summed into a
/// call site's `bonus` expression exactly like [coachQualityBonus]/
/// `OffenseShapeBonus`/`DefenseTacticBonus` already are -- fatigue is
/// symmetric (it costs the same at every rating a fatigued player is
/// read for), so this one helper covers every call site rather than
/// needing an offense/defense-specific variant.
double _fatigueBonus(Map<Player, double> energy, Player player) =>
    fatigueBonusFor(energy[player] ?? kMaxEnergy);

/// [player]'s current "playing through it" injury penalty, read out of
/// [injuryPenalty] -- 0 for an uninjured player, or missing from the map
/// entirely (a caller that doesn't track injuries at all, e.g. most
/// possession-level tests), same "opt-in only" posture [_fatigueBonus]
/// already has. Precomputed once per game from each player's
/// [PlayerInjury] state (`player_injury.dart`'s `injuryBonusFor`) rather
/// than looked up live here -- unlike fatigue, a player's injury tier
/// never changes mid-game. Summed into a call site's `bonus` expression
/// exactly alongside [_fatigueBonus] -- an injury costs the same at every
/// rating a hobbled player is read for, same symmetry reasoning.
double _injuryBonus(Map<Player, double> injuryPenalty, Player player) =>
    injuryPenalty[player] ?? 0.0;

/// Applies the home-court/trait bonuses above, plus [bonus] if given, to
/// one of [player]'s raw ratings, ahead of any contest that reads it.
/// [isHome] is which side of *this specific contest* [player] is playing
/// on -- callers thread through whichever of `offenseIsHome`/`defenseIsHome`
/// matches which list [player] came from, not a property of the player
/// itself (the same roster is the home team for the whole game either
/// way).
///
/// [bonus] (default 0, no effect) is a general multiplier-delta
/// accumulator, not a single named bonus -- a call site sums together
/// whichever of [coachQualityBonus], `OffenseShapeBonus`, or
/// `DefenseTacticBonus` actually apply to this specific rating before
/// passing the total in here. Was `coachBonus` (coach-quality-only) until
/// the 2026-08-14 offense-shape/defensive-tactic work gave this same slot
/// more than one possible contributor.
///
/// Deliberately a real (non-underscored) top-level function rather than
/// private to this file -- the actual bonus math is exact and
/// deterministic, unlike the rest of this engine's stochastic contests, so
/// it's tested directly against known inputs/outputs rather than inferred
/// statistically from thousands of simulated possessions.
int effectiveHomeAwayRating(
  Player player,
  int rawRating,
  bool isHome, {
  double bonus = 0.0,
}) {
  var multiplier = 1.0 + bonus;
  if (isHome) {
    multiplier += kHomeAdvantageBonus;
    if (player.traits.contains(Trait.homeCourtHero)) {
      multiplier += kHomeCourtHeroBonus;
    }
  } else if (player.traits.contains(Trait.roadWarrior)) {
    multiplier += kRoadWarriorBonus;
  }
  if (multiplier == 1.0) return rawRating;
  return (rawRating * multiplier).round().clamp(kMinRating, kMaxRating);
}

int _averageRating(int a, int b) => ((a + b) / 2).round();

/// Same as [_averageRating], but applies [effectiveHomeAwayRating] to each raw
/// rating first -- the usual way a contest rating gets built in this
/// file, since almost every check here combines two of a player's
/// ratings rather than reading one alone.
int _averageEffectiveRating(
  Player player,
  int ratingA,
  int ratingB,
  bool isHome, {
  double bonus = 0.0,
}) => _averageRating(
  effectiveHomeAwayRating(player, ratingA, isHome, bonus: bonus),
  effectiveHomeAwayRating(player, ratingB, isHome, bonus: bonus),
);

/// A team's own rating bonus from one of its head coach's stats, off a
/// flat 50-midpoint baseline -- not a comparison against the opponent
/// (that was the old [coachMatchupBonus] model, replaced outright
/// 2026-08-20 per a direct GM re-confirmation: "average coach score is
/// 50... anything above gets a slight bump... anything below, a
/// reduction... flip it on defense"). Called twice per team, once per
/// side of the ball: [coachQualityBonus] of `coach.stats.offense` becomes
/// that team's [offenseCoachBonus] whenever they're on offense;
/// [coachQualityBonus] of `coach.stats.defense` becomes their
/// [defenseCoachBonus] whenever they're on defense -- entirely
/// independent of which team they're playing, unlike the matchup model
/// it replaced.
double coachQualityBonus(int coachStat) =>
    (coachStat - 50) * kCoachQualityBonusPerPoint;

/// [extraSeconds] (2026-08-17, the quarter-break coaching-options catalog
/// -- `0B_Planned.md`'s quarter-break bullet) is a coach-picked pace
/// nudge on top of [isProtectingLead]'s automatic one: whichever of
/// [CoachingOptionBonus.ownPaceSecondsBonus]/`opponentPaceSecondsBonus`
/// applies to *this* action, summed by the caller before this is called.
/// Can be negative ([CoachingOption.pickUpThePace]) -- clamped so the
/// result never drops below [_minActionSeconds], the same floor a plain
/// unmodified roll already respects.
double _rollActionSeconds(
  Random random, {
  bool isProtectingLead = false,
  double extraSeconds = 0.0,
}) {
  final base =
      _minActionSeconds +
      random.nextDouble() * (_maxActionSeconds - _minActionSeconds);
  final withBlowout = isProtectingLead
      ? base + _kBlowoutPaceActionBonusSeconds
      : base;
  final withCoaching = withBlowout + extraSeconds;
  return withCoaching < _minActionSeconds ? _minActionSeconds : withCoaching;
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
///
/// [offenseBonus]/[defenseBonus] are the offense-shape/defensive-tactic
/// bonuses for each side this game -- both default to "no effect" so a
/// caller that doesn't care about either gets the exact old behavior.
/// [defenseTargetPlayerId] (a defensive-tactic Face-Guard-the-Star target,
/// if any) swaps [defenseBonus]'s `targetedBonus` in for its
/// `spreadThinPenalty` specifically when the offensive rebounder being
/// contested is the flagged player.
///
/// [energy] is each player's current fatigue energy (`fatigue.dart`) --
/// defaults to empty (nobody fatigued), same opt-in posture as every
/// other bonus here; folded into both rebounders' `bonus` via
/// [_fatigueBonus].
({bool offensiveRebound, Player rebounder}) _resolveRebound(
  Random random,
  List<Player> offense,
  List<Player> defense, {
  required bool offenseIsHome,
  required bool defenseIsHome,
  double offenseCoachBonus = 0.0,
  double defenseCoachBonus = 0.0,
  OffenseShapeBonus offenseBonus = _noOffenseBonus,
  DefenseTacticBonus defenseBonus = _noDefenseBonus,
  String? defenseTargetPlayerId,
  Map<Player, double> energy = const {},
  Map<Player, double> injuryPenalty = const {},
  CoachingOptionBonus offenseCoachingBonus = kNoCoachingOptionBonus,
  CoachingOptionBonus defenseCoachingBonus = kNoCoachingOptionBonus,
}) {
  final offensiveRebounder = _randomOf(random, offense);
  final defensiveRebounder = _randomOf(random, defense);
  final offenseWins = resolveContest(
    random,
    attackerRating: _averageEffectiveRating(
      offensiveRebounder,
      offensiveRebounder.ratings.strength,
      offensiveRebounder.ratings.interiorOffense,
      offenseIsHome,
      bonus:
          offenseCoachBonus +
          offenseBonus.interior +
          offenseCoachingBonus.offenseBonus +
          offenseCoachingBonus.reboundingBonus +
          _fatigueBonus(energy, offensiveRebounder) +
          _injuryBonus(injuryPenalty, offensiveRebounder),
    ),
    defenderRating: _averageEffectiveRating(
      defensiveRebounder,
      defensiveRebounder.ratings.strength,
      defensiveRebounder.ratings.interiorDefense,
      defenseIsHome,
      bonus:
          defenseCoachBonus +
          defenseBonus.interior +
          defenseCoachingBonus.defenseBonus +
          defenseCoachingBonus.reboundingBonus +
          _defenseTargetBonus(
            defenseBonus,
            offensiveRebounder,
            defenseTargetPlayerId,
          ) +
          _fatigueBonus(energy, defensiveRebounder) +
          _injuryBonus(injuryPenalty, defensiveRebounder),
    ),
    floor: 0.05,
    ceiling: 0.6,
  );
  return (
    offensiveRebound: offenseWins,
    rebounder: offenseWins ? offensiveRebounder : defensiveRebounder,
  );
}

/// [DefenseTacticBonus.targetedBonus] when [attacker] is the flagged
/// Face-Guard-the-Star target, else [DefenseTacticBonus.spreadThinPenalty]
/// -- both 0 for every tactic except [DefensiveTactic.faceGuardStar], so
/// this is always safe to add in regardless of which tactic is actually
/// active.
double _defenseTargetBonus(
  DefenseTacticBonus defenseBonus,
  Player attacker,
  String? defenseTargetPlayerId,
) {
  return attacker.id == defenseTargetPlayerId
      ? defenseBonus.targetedBonus
      : defenseBonus.spreadThinPenalty;
}

/// Shoots [attempts] free throws for [shooter], appending a made/missed
/// event for each, and returns how many went in. Resolved against a fixed
/// neutral rating (`_neutralFreeThrowDefense`) via [perimeterOffense] as
/// the closest existing proxy for touch -- there's no dedicated
/// free-throw rating. [shooterIsHome] is always the *offense*'s home
/// status -- a free-throw shooter is always the team that had the ball.
/// [bonus] is the offense's combined coach-matchup + offense-shape
/// perimeter bonus for this game -- nobody's actively defending a free
/// throw, but the shooter's own bonuses still apply to their touch.
int _shootFreeThrows(
  Random random,
  List<MatchEvent> events,
  Player shooter,
  int attempts, {
  required bool shooterIsHome,
  double bonus = 0.0,
}) {
  var made = 0;
  for (var i = 0; i < attempts; i++) {
    final success = resolveContest(
      random,
      attackerRating: effectiveHomeAwayRating(
        shooter,
        shooter.ratings.perimeterOffense,
        shooterIsHome,
        bonus: bonus,
      ),
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
/// [offenseIsHome]/[defenseIsHome] drive [kHomeAdvantageBonus] and the
/// [Trait.homeCourtHero]/[Trait.roadWarrior] bumps -- both default to
/// `false`, so a possession-level test that doesn't care about home
/// court gets the exact old behavior (neither side boosted) rather than
/// having to opt out explicitly. `match_engine.dart` is the only caller
/// that sets these for real, one `true` and one `false` every possession
/// since a game always has exactly one home team.
///
/// [offenseCoachBonus]/[defenseCoachBonus] are [coachQualityBonus]'s
/// result for whichever team is on offense/defense *this* possession --
/// each side's own bonus, off its own coach's `stats.offense`/
/// `stats.defense` against the flat 50 midpoint, entirely independent of
/// the opponent (2026-08-20, replacing the earlier opponent-relative
/// `coachMatchupBonus` model outright -- see [coachQualityBonus]'s own
/// doc comment). Both default to 0 (no effect), same opt-in-only posture
/// as the home-court params. [offenseCoachBonus] applies to every
/// attacking-side rating this possession touches (passing, shooting,
/// free throws, offensive rebounding); [defenseCoachBonus] applies to
/// every defending-side rating (shot defense, pass disruption, blocking,
/// defensive rebounding) -- both via [effectiveHomeAwayRating]'s `bonus`.
///
/// [offenseBonus]/[defenseBonus] (2026-08-14, a direct GM ask following
/// the "Coach's Board" design artifact) are the current offense's
/// lineup-shape bonus (`offense_shape.dart`) and the current defense's
/// GM-picked tactic bonus (`defensive_tactic.dart`) -- both default to
/// "no effect," summed into the same defending-side ratings
/// [defenseCoachBonus] reaches. [defenseTargetPlayerId], when set (only
/// ever meaningful for `DefensiveTactic.faceGuardStar`), swaps
/// [defenseBonus]'s `targetedBonus` in for its `spreadThinPenalty` at
/// every one of those defender-side spots specifically when the
/// offensive player involved in that contest is the flagged target.
///
/// There's no court-position model yet (`0B_Planned.md`'s Phase 4 court
/// presentation): "driving" and "shooting a jumper" are modeled as a
/// choice between [PlayerRatings.interiorOffense] and
/// [PlayerRatings.perimeterOffense] rather than actual movement toward the
/// basket, reusing the split those ratings were already built for. There's
/// also no live rebound off a missed free throw -- the possession always
/// ends once free throws are done, make or miss on the last one.
///
/// [offenseCoachingBonus]/[defenseCoachingBonus] (2026-08-17, the
/// quarter-break coaching-options catalog -- `0B_Planned.md`'s
/// quarter-break bullet) are whichever [CoachingOption] each side
/// currently has active, resolved via `coaching_option.dart`'s
/// `coachingBonusFor` -- both default to "no effect," same opt-in-only
/// posture as every other bonus here. Unlike [offenseBonus]/[defenseBonus]
/// (persistent for the whole game), these are transient -- the caller
/// (`match_engine.dart`) is responsible for only passing a non-default
/// value while that team's pick is still within its 1-quarter/final-2-
/// minutes duration.
///
/// [energy] (2026-08-17, `fatigue.dart`) is every on-court player's
/// current fatigue energy, keyed by [Player] -- defaults to empty, same
/// opt-in posture as every other bonus here (a possession-level test that
/// doesn't pass it gets the exact old behavior, nobody fatigued). Applied
/// symmetrically at every rating lookup in this function via
/// [_fatigueBonus] -- passing, shooting, free throws, blocking, and
/// rebounding all cost a fatigued player the same penalty, on both
/// offense and defense.
PossessionResult simulatePossession(
  Random random, {
  required List<Player> offense,
  required List<Player> defense,
  bool defenseInBonus = false,
  int offenseMargin = 0,
  bool offenseIsHome = false,
  bool defenseIsHome = false,
  double offenseCoachBonus = 0.0,
  double defenseCoachBonus = 0.0,
  OffenseShapeBonus offenseBonus = _noOffenseBonus,
  DefenseTacticBonus defenseBonus = _noDefenseBonus,
  String? defenseTargetPlayerId,
  Map<Player, double> energy = const {},
  Map<Player, double> injuryPenalty = const {},
  CoachingOptionBonus offenseCoachingBonus = kNoCoachingOptionBonus,
  CoachingOptionBonus defenseCoachingBonus = kNoCoachingOptionBonus,
}) {
  assert(offense.length == 5, 'offense must have exactly 5 players on court');
  assert(defense.length == 5, 'defense must have exactly 5 players on court');
  final isProtectingLead = offenseMargin >= kBlowoutPaceMargin;
  // The offense's own pace pick (Park the Bus/Pace Yourself/Pick Up the
  // Pace, applied while they have the ball) plus the defense's pick that
  // targets *this* possession's ball-handler (Full-Court Press/Park the
  // Bus/Pace Yourself) -- summed once per possession since every action
  // within it belongs to the same offense/defense pairing.
  final extraActionSeconds =
      offenseCoachingBonus.ownPaceSecondsBonus +
      defenseCoachingBonus.opponentPaceSecondsBonus;

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
      extraSeconds: extraActionSeconds,
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
        attackerRating: _averageEffectiveRating(
          ballHandler,
          ballHandler.ratings.agility,
          ballHandler.ratings.passing,
          offenseIsHome,
          bonus:
              offenseCoachBonus +
              offenseBonus.passing +
              offenseCoachingBonus.offenseBonus +
              _fatigueBonus(energy, ballHandler) +
              _injuryBonus(injuryPenalty, ballHandler),
        ),
        defenderRating: _averageEffectiveRating(
          defender,
          defender.ratings.agility,
          defender.ratings.disruption,
          defenseIsHome,
          bonus:
              defenseCoachBonus +
              defenseBonus.disruption +
              defenseCoachingBonus.defenseBonus +
              defenseCoachingBonus.disruptionBonus +
              _defenseTargetBonus(
                defenseBonus,
                ballHandler,
                defenseTargetPlayerId,
              ) +
              _fatigueBonus(energy, defender) +
              _injuryBonus(injuryPenalty, defender),
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
          shooterIsHome: offenseIsHome,
          bonus:
              offenseCoachBonus +
              offenseBonus.perimeter +
              offenseCoachingBonus.offenseBonus +
              _fatigueBonus(energy, ballHandler) +
              _injuryBonus(injuryPenalty, ballHandler),
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
    final shooterFatigue =
        _fatigueBonus(energy, ballHandler) +
        _injuryBonus(injuryPenalty, ballHandler);
    final defenderFatigue =
        _fatigueBonus(energy, defender) + _injuryBonus(injuryPenalty, defender);
    final shooterRating = isDrive
        ? _averageEffectiveRating(
            ballHandler,
            ballHandler.ratings.strength,
            ballHandler.ratings.interiorOffense,
            offenseIsHome,
            bonus:
                offenseCoachBonus +
                offenseBonus.interior +
                offenseCoachingBonus.offenseBonus +
                shooterFatigue,
          )
        : _averageEffectiveRating(
            ballHandler,
            ballHandler.ratings.agility,
            ballHandler.ratings.perimeterOffense,
            offenseIsHome,
            bonus:
                offenseCoachBonus +
                offenseBonus.perimeter +
                offenseCoachingBonus.offenseBonus +
                shooterFatigue,
          );
    final defenseTargetBonus = _defenseTargetBonus(
      defenseBonus,
      ballHandler,
      defenseTargetPlayerId,
    );
    final defenderRating = isDrive
        ? _averageEffectiveRating(
            defender,
            defender.ratings.strength,
            defender.ratings.interiorDefense,
            defenseIsHome,
            bonus:
                defenseCoachBonus +
                defenseBonus.interior +
                defenseCoachingBonus.defenseBonus +
                defenseTargetBonus +
                defenderFatigue,
          )
        : _averageEffectiveRating(
            defender,
            defender.ratings.agility,
            defender.ratings.perimeterDefense,
            defenseIsHome,
            bonus:
                defenseCoachBonus +
                defenseBonus.perimeter +
                defenseCoachingBonus.defenseBonus +
                defenseCoachingBonus.perimeterDefenseBonus +
                defenseTargetBonus +
                defenderFatigue,
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
        shooterIsHome: offenseIsHome,
        bonus:
            offenseCoachBonus +
            offenseBonus.perimeter +
            offenseCoachingBonus.offenseBonus +
            shooterFatigue,
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
      attackerRating: effectiveHomeAwayRating(
        defender,
        defender.ratings.blocking,
        defenseIsHome,
        // Blocking reads as rim protection regardless of shot type, so it
        // shares the drive/jumper defender's own interior bonus + target
        // check rather than needing a third variant. defenderFatigue is
        // the same `defender` as above -- reused, not re-derived.
        bonus:
            defenseCoachBonus +
            defenseBonus.interior +
            defenseCoachingBonus.defenseBonus +
            defenseTargetBonus +
            defenderFatigue,
      ),
      // shooterRating is already boosted for offenseIsHome above -- reused
      // as-is rather than re-derived.
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
    final rebound = _resolveRebound(
      random,
      offense,
      defense,
      offenseIsHome: offenseIsHome,
      defenseIsHome: defenseIsHome,
      offenseCoachBonus: offenseCoachBonus,
      defenseCoachBonus: defenseCoachBonus,
      offenseBonus: offenseBonus,
      defenseBonus: defenseBonus,
      defenseTargetPlayerId: defenseTargetPlayerId,
      energy: energy,
      injuryPenalty: injuryPenalty,
      offenseCoachingBonus: offenseCoachingBonus,
      defenseCoachingBonus: defenseCoachingBonus,
    );
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
