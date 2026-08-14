import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player.dart';
import '../domain/match_event.dart';
import '../domain/match_result.dart';
import 'possession_engine.dart';
import 'substitution_policy.dart';
import 'tip_off_resolver.dart';

/// WNBA quarter length, in seconds (10 minutes).
const _quarterSeconds = 600.0;
const _quarterCount = 4;

/// WNBA overtime period length, in seconds (5 minutes).
const _overtimeSeconds = 300.0;

/// Team fouls in a quarter at which the opposing team goes into the bonus
/// (2 free throws on any subsequent non-shooting foul that quarter).
const _teamFoulBonusThreshold = 5;

/// Personal fouls at which a player fouls out and must be substituted.
const _personalFoulOutLimit = 6;

/// How often on-court lineups get re-picked, in simulated seconds. Locking
/// lineups only at quarter boundaries (600s) meant nobody with a target
/// under a full quarter's worth of minutes (the bottom of the bench,
/// 4-8 target minutes) could ever be "due" -- a throwaway full-game sanity
/// check confirmed those players sat the whole game. Rechecking every 2
/// minutes gives even a 4-minute target a real chance to be the most
/// due at some point in the quarter.
const _substitutionCheckSeconds = 120.0;

Player _tallest(List<Player> players) =>
    players.reduce((a, b) => a.heightInches >= b.heightInches ? a : b);

/// The id of whoever in [roster] rates highest by `PlayerRatings.overall`
/// -- [DefensiveTactic.faceGuardStar]'s target, always computed off the
/// *opposing* team's roster. Null-safe on an empty roster (never actually
/// empty for a real 12-player game, but cheap to guard).
String? _bestPlayerId(List<Player> roster) {
  if (roster.isEmpty) return null;
  return roster
      .reduce((a, b) => a.ratings.overall >= b.ratings.overall ? a : b)
      .id;
}

/// Simulates one full game between [homeRoster] and [awayRoster] (each the
/// full 12-player active roster) -- quarters, a running score, fouls
/// (personal and team, with bonus free throws), and automatic
/// substitutions driven by target minutes. [homeTargetMinutes]/
/// [awayTargetMinutes] are optional -- when omitted, each side falls back
/// to [targetMinutesFor]'s automatic overall-based ranking (the AI-team
/// default); a caller with a real ranking to use instead (the GM's own
/// bench order, via [targetMinutesForOrderedRoster]) passes it directly
/// rather than letting this function re-derive one. Deterministic for a
/// given [random] stream.
///
/// Simplifications, all deliberate and worth revisiting later:
/// - **Lineups re-pick every `_substitutionCheckSeconds`** (plus
///   immediately on a foul-out) rather than modeling exact live
///   substitution timing. Coarser than real coaching, which reacts to
///   specific dead-ball moments, but converges toward each player's
///   target minutes reasonably well. Can produce choppier in/out patterns
///   than a real coach would -- the greedy "most behind schedule" rule has
///   no stickiness once a player's minutes catch up.
/// - **Quarters end after whichever possession is in progress completes**,
///   not mid-action -- a quarter can run a little past its nominal 600
///   seconds rather than truncating a possession exactly at the buzzer.
/// - **Quarter-start possession strictly alternates** (home, away, home,
///   away, keyed off who won the opening tip) rather than modeling the
///   real alternating-possession arrow precisely -- extended the same way
///   into overtime periods.
/// - **Overtime is as many 5-minute periods as it takes** to break a tie
///   (real WNBA/NBA length) -- a season simulator needs a winner out of
///   every game, so a tied game after Q4 doesn't just end tied.
///   [MatchResult.homeScoreByQuarter]/`awayScoreByQuarter` can run longer
///   than 4 entries when this happens.
/// - **No energy/fatigue model yet** (`0B_Planned.md`'s stamina appendix)
///   -- substitutions are driven purely by target minutes and foul-outs.
/// - **Blowout pace rubber-banding** (TODO.md item 5): whichever team is
///   ahead by `kBlowoutPaceMargin` or more slows its own possessions down
///   (`possession_engine.dart`'s `simulatePossession` `offenseMargin`
///   param) -- longer possessions eat clock for both teams, capping how
///   many total possessions (and therefore points) are left for the
///   margin to keep growing on. Pacing only -- no rating or shot-quality
///   change for either team.
/// - **Home team advantage** (TODO.md item 11): every home-team player's
///   ratings get a flat `kHomeAdvantageBonus` bump for every contest this
///   game (`possession_engine.dart`), on top of which
///   [Trait.homeCourtHero] adds a further home-only bump and
///   [Trait.roadWarrior] adds an away-only one. [homeRoster] is always
///   the home team here -- there's no neutral-site game.
/// - **Coach Offense-vs-Defense matchup** (TODO.md's coach-stats item, a
///   direct GM ask): [homeCoach]/[awayCoach] are optional (`null` skips
///   the bonus entirely, e.g. an exhibition with no real per-team coach
///   assigned) -- when both are given, each team's own coach's
///   `CoachStats.offense` against the *other* coach's `CoachStats.defense`
///   ([coachMatchupBonus], `possession_engine.dart`) becomes that team's
///   flat rating bump whenever they're on offense, computed once here for
///   the whole game (coach stats don't change mid-game) rather than
///   re-derived every possession.
/// - **Offense shape** (2026-08-14, a direct GM ask, following the
///   "Coach's Board" design artifact): fully automatic, no param to set --
///   each side's starting five (the 5 players carrying the most minutes
///   in its resolved target-minutes map, via `startingFiveByMinutes`)
///   determines an `OffenseShape` (`offense_shape.dart`), which becomes
///   that team's flat rating bump whenever they're on offense. Applies to
///   every game this function ever simulates, including postseason,
///   All-Star, and AI-vs-AI regular-season games -- there's no opt-out,
///   since it's read straight off real roster data rather than a GM
///   choice.
/// - **Defensive tactic** (2026-08-14, same ask): [homeDefenseTactic]/
///   [awayDefenseTactic] default to [DefensiveTactic.balanced] --
///   deliberately *not* nullable/coach-style all-or-nothing, since
///   Balanced is a legitimate value on its own (every AI opponent and
///   every non-"today's game" call site just leaves these at their
///   default, which *is* "AI always plays Balanced," with no separate
///   AI-decision logic anywhere). Only the pre-game screen's Play Game
///   flow ever passes something else, for the GM's own team only. Each
///   side's tactic becomes that team's rating bump whenever they're on
///   *defense* (`defensive_tactic.dart`'s `DefenseTacticBonus`) --
///   [DefensiveTactic.faceGuardStar] additionally targets whichever
///   player on the *opposing* roster has the highest
///   `PlayerRatings.overall` (this game's fixed target for the whole
///   game, not re-evaluated possession to possession).
MatchResult simulateMatch(
  Random random, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
  Map<Player, int>? homeTargetMinutes,
  Map<Player, int>? awayTargetMinutes,
  Coach? homeCoach,
  Coach? awayCoach,
  DefensiveTactic homeDefenseTactic = DefensiveTactic.balanced,
  DefensiveTactic awayDefenseTactic = DefensiveTactic.balanced,
}) {
  assert(homeRoster.length == 12, 'homeRoster must have exactly 12 players');
  assert(awayRoster.length == 12, 'awayRoster must have exactly 12 players');

  homeTargetMinutes ??= targetMinutesFor(homeRoster);
  awayTargetMinutes ??= targetMinutesFor(awayRoster);
  final homeOffenseCoachBonus = homeCoach == null || awayCoach == null
      ? 0.0
      : coachMatchupBonus(
          offenseCoachOffense: homeCoach.stats.offense,
          defenseCoachDefense: awayCoach.stats.defense,
        );
  final awayOffenseCoachBonus = homeCoach == null || awayCoach == null
      ? 0.0
      : coachMatchupBonus(
          offenseCoachOffense: awayCoach.stats.offense,
          defenseCoachDefense: homeCoach.stats.defense,
        );
  final homeOffenseBonus = offenseBonusFor(
    detectOffenseShape(startingFiveByMinutes(homeTargetMinutes)),
  );
  final awayOffenseBonus = offenseBonusFor(
    detectOffenseShape(startingFiveByMinutes(awayTargetMinutes)),
  );
  final homeDefenseBonus = defenseBonusFor(homeDefenseTactic);
  final awayDefenseBonus = defenseBonusFor(awayDefenseTactic);
  // Each side's Face-Guard-the-Star target (if any) is whoever on the
  // *opposing* roster rates highest overall -- null-safe, though a real
  // 12-player roster is never empty in practice.
  final homeDefenseTargetId = _bestPlayerId(awayRoster);
  final awayDefenseTargetId = _bestPlayerId(homeRoster);
  final minutesPlayed = <Player, double>{};
  final personalFouls = <Player, int>{};
  final fouledOut = <Player>{};

  var homeScore = 0;
  var awayScore = 0;
  final homeScoreByQuarter = <int>[];
  final awayScoreByQuarter = <int>[];
  final events = <MatchEvent>[];

  var homeOnCourt = pickOnCourt(
    roster: homeRoster,
    targetMinutes: homeTargetMinutes,
    minutesPlayed: minutesPlayed,
    fouledOut: fouledOut,
  );
  var awayOnCourt = pickOnCourt(
    roster: awayRoster,
    targetMinutes: awayTargetMinutes,
    minutesPlayed: minutesPlayed,
    fouledOut: fouledOut,
  );
  final tipOffWinnerIsHome = resolveTipOff(
    random,
    _tallest(homeOnCourt),
    _tallest(awayOnCourt),
  );

  var quarter = 1;
  while (quarter <= _quarterCount || homeScore == awayScore) {
    final periodSeconds = quarter <= _quarterCount
        ? _quarterSeconds
        : _overtimeSeconds;
    if (quarter > 1) {
      homeOnCourt = pickOnCourt(
        roster: homeRoster,
        targetMinutes: homeTargetMinutes,
        minutesPlayed: minutesPlayed,
        fouledOut: fouledOut,
      );
      awayOnCourt = pickOnCourt(
        roster: awayRoster,
        targetMinutes: awayTargetMinutes,
        minutesPlayed: minutesPlayed,
        fouledOut: fouledOut,
      );
    }

    var homeTeamFouls = 0;
    var awayTeamFouls = 0;
    var quarterClock = periodSeconds;
    var secondsSinceSubCheck = 0.0;
    var offenseIsHome = quarter.isOdd
        ? tipOffWinnerIsHome
        : !tipOffWinnerIsHome;
    final homeScoreBeforeQuarter = homeScore;
    final awayScoreBeforeQuarter = awayScore;

    while (quarterClock > 0) {
      final offense = offenseIsHome ? homeOnCourt : awayOnCourt;
      final defense = offenseIsHome ? awayOnCourt : homeOnCourt;
      final defenseInBonus = offenseIsHome
          ? awayTeamFouls >= _teamFoulBonusThreshold
          : homeTeamFouls >= _teamFoulBonusThreshold;
      final offenseMargin = offenseIsHome
          ? homeScore - awayScore
          : awayScore - homeScore;

      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: defenseInBonus,
        offenseMargin: offenseMargin,
        offenseIsHome: offenseIsHome,
        defenseIsHome: !offenseIsHome,
        offenseCoachBonus: offenseIsHome
            ? homeOffenseCoachBonus
            : awayOffenseCoachBonus,
        offenseBonus: offenseIsHome ? homeOffenseBonus : awayOffenseBonus,
        defenseBonus: offenseIsHome ? awayDefenseBonus : homeDefenseBonus,
        defenseTargetPlayerId: offenseIsHome
            ? awayDefenseTargetId
            : homeDefenseTargetId,
      );
      events.addAll(result.events);
      quarterClock -= result.secondsElapsed;
      secondsSinceSubCheck += result.secondsElapsed;

      final minutesThisPossession = result.secondsElapsed / 60;
      for (final p in offense) {
        minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
      }
      for (final p in defense) {
        minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
      }

      if (offenseIsHome) {
        homeScore += result.pointsScored;
      } else {
        awayScore += result.pointsScored;
      }

      for (final event in result.events) {
        if (event.type != MatchEventType.shootingFoul &&
            event.type != MatchEventType.nonShootingFoul) {
          continue;
        }
        final foulingPlayer = event.player!;
        personalFouls[foulingPlayer] = (personalFouls[foulingPlayer] ?? 0) + 1;
        final foulerIsHome = homeRoster.contains(foulingPlayer);
        if (foulerIsHome) {
          homeTeamFouls++;
        } else {
          awayTeamFouls++;
        }

        if (personalFouls[foulingPlayer]! >= _personalFoulOutLimit) {
          fouledOut.add(foulingPlayer);
          if (foulerIsHome) {
            homeOnCourt = substituteForFoulOut(
              foulingPlayer: foulingPlayer,
              onCourt: homeOnCourt,
              roster: homeRoster,
              targetMinutes: homeTargetMinutes,
              minutesPlayed: minutesPlayed,
              fouledOut: fouledOut,
            );
          } else {
            awayOnCourt = substituteForFoulOut(
              foulingPlayer: foulingPlayer,
              onCourt: awayOnCourt,
              roster: awayRoster,
              targetMinutes: awayTargetMinutes,
              minutesPlayed: minutesPlayed,
              fouledOut: fouledOut,
            );
          }
        }
      }

      if (secondsSinceSubCheck >= _substitutionCheckSeconds) {
        secondsSinceSubCheck = 0;
        homeOnCourt = pickOnCourt(
          roster: homeRoster,
          targetMinutes: homeTargetMinutes,
          minutesPlayed: minutesPlayed,
          fouledOut: fouledOut,
        );
        awayOnCourt = pickOnCourt(
          roster: awayRoster,
          targetMinutes: awayTargetMinutes,
          minutesPlayed: minutesPlayed,
          fouledOut: fouledOut,
        );
      }

      offenseIsHome = !offenseIsHome;
    }

    homeScoreByQuarter.add(homeScore - homeScoreBeforeQuarter);
    awayScoreByQuarter.add(awayScore - awayScoreBeforeQuarter);
    quarter++;
  }

  return MatchResult(
    homeScore: homeScore,
    awayScore: awayScore,
    homeScoreByQuarter: homeScoreByQuarter,
    awayScoreByQuarter: awayScoreByQuarter,
    events: events,
    minutesPlayed: minutesPlayed,
    personalFouls: personalFouls,
    fouledOut: fouledOut,
  );
}
