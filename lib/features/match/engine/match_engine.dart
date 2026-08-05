import 'dart:math';

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

/// Simulates one full game between [homeRoster] and [awayRoster] (each the
/// full 12-player active roster) -- quarters, a running score, fouls
/// (personal and team, with bonus free throws), and automatic
/// substitutions driven by [targetMinutesFor]'s default ranking.
/// Deterministic for a given [random] stream.
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
MatchResult simulateMatch(
  Random random, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
}) {
  assert(homeRoster.length == 12, 'homeRoster must have exactly 12 players');
  assert(awayRoster.length == 12, 'awayRoster must have exactly 12 players');

  final homeTargetMinutes = targetMinutesFor(homeRoster);
  final awayTargetMinutes = targetMinutesFor(awayRoster);
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

      final result = simulatePossession(
        random,
        offense: offense,
        defense: defense,
        defenseInBonus: defenseInBonus,
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
