import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_event.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/match/domain/player_box_score.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

import '../../../support/match_test_players.dart';

void main() {
  group('computeBoxScore', () {
    final homeRoster = testLineup('home');
    final awayRoster = testLineup('away');
    final scorer = homeRoster[0];
    final passer = homeRoster[1];
    final reboundOff = homeRoster[2];
    final reboundDef = awayRoster[0];
    final stealDefender = awayRoster[1];
    final blockDefender = awayRoster[2];
    final shotClockVictim = homeRoster[3];
    final outOfBoundsPasser = homeRoster[4];
    final redirectRecovererAway = awayRoster[3];

    MatchResult resultWithEvents(List<MatchEvent> events) {
      return MatchResult(
        homeScore: 0,
        awayScore: 0,
        homeScoreByQuarter: const [0],
        awayScoreByQuarter: const [0],
        events: events,
        minutesPlayed: {
          for (final p in [...homeRoster, ...awayRoster]) p: 10.0,
        },
        personalFouls: const {},
        fouledOut: const {},
      );
    }

    test('tallies points, makes, and attempts for 2pt and 3pt shots', () {
      final result = resultWithEvents([
        MatchEvent(
          type: MatchEventType.shotAttempt,
          secondsElapsed: 3,
          player: scorer,
          isThreePointAttempt: false,
        ),
        MatchEvent(
          type: MatchEventType.shotMade,
          secondsElapsed: 0,
          player: scorer,
          isThreePointAttempt: false,
          points: 2,
        ),
        MatchEvent(
          type: MatchEventType.shotAttempt,
          secondsElapsed: 3,
          player: scorer,
          isThreePointAttempt: true,
        ),
        MatchEvent(
          type: MatchEventType.shotMade,
          secondsElapsed: 0,
          player: scorer,
          isThreePointAttempt: true,
          points: 3,
        ),
      ]);

      final boxScore = computeBoxScore(
        result,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ).firstWhere((b) => b.player == scorer);

      expect(boxScore.points, 5);
      expect(boxScore.fieldGoalsMade, 2);
      expect(boxScore.fieldGoalAttempts, 2);
      expect(boxScore.threePointersMade, 1);
      expect(boxScore.threePointAttempts, 1);
      expect(boxScore.fieldGoalPercentage, 1.0);
      expect(boxScore.threePointPercentage, 1.0);
    });

    test('tallies free throws separately from field goals', () {
      final result = resultWithEvents([
        MatchEvent(
          type: MatchEventType.freeThrowMade,
          secondsElapsed: 0,
          player: scorer,
          points: 1,
        ),
        MatchEvent(
          type: MatchEventType.freeThrowMissed,
          secondsElapsed: 0,
          player: scorer,
        ),
      ]);

      final boxScore = computeBoxScore(
        result,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ).firstWhere((b) => b.player == scorer);

      expect(boxScore.points, 1);
      expect(boxScore.freeThrowsMade, 1);
      expect(boxScore.freeThrowAttempts, 2);
      expect(boxScore.fieldGoalAttempts, 0);
      expect(boxScore.freeThrowPercentage, 0.5);
    });

    test('tallies rebounds, assists, steals, and blocks to the right '
        'players', () {
      final result = resultWithEvents([
        MatchEvent(
          type: MatchEventType.offensiveRebound,
          secondsElapsed: 0,
          player: reboundOff,
        ),
        MatchEvent(
          type: MatchEventType.defensiveRebound,
          secondsElapsed: 0,
          player: reboundDef,
        ),
        MatchEvent(
          type: MatchEventType.assist,
          secondsElapsed: 0,
          player: passer,
          secondPlayer: scorer,
        ),
        MatchEvent(
          type: MatchEventType.steal,
          secondsElapsed: 0,
          player: stealDefender,
          secondPlayer: scorer,
        ),
        MatchEvent(
          type: MatchEventType.shotBlocked,
          secondsElapsed: 0,
          player: blockDefender,
          secondPlayer: scorer,
        ),
      ]);

      final boxScores = computeBoxScore(
        result,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      PlayerBoxScore of(Player p) => boxScores.firstWhere((b) => b.player == p);

      expect(of(reboundOff).offensiveRebounds, 1);
      expect(of(reboundOff).totalRebounds, 1);
      expect(of(reboundDef).defensiveRebounds, 1);
      expect(of(passer).assists, 1);
      expect(of(stealDefender).steals, 1);
      // The steal also charges a turnover to the player who lost the ball.
      expect(of(scorer).turnovers, 1);
      expect(of(blockDefender).blocks, 1);
    });

    test('charges a turnover for a shot-clock violation and an '
        'out-of-bounds pass', () {
      final result = resultWithEvents([
        MatchEvent(
          type: MatchEventType.shotClockViolation,
          secondsElapsed: 0,
          player: shotClockVictim,
        ),
        MatchEvent(
          type: MatchEventType.passOutOfBounds,
          secondsElapsed: 0,
          player: outOfBoundsPasser,
        ),
      ]);

      final boxScores = computeBoxScore(
        result,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );

      expect(
        boxScores.firstWhere((b) => b.player == shotClockVictim).turnovers,
        1,
      );
      expect(
        boxScores.firstWhere((b) => b.player == outOfBoundsPasser).turnovers,
        1,
      );
    });

    test('a redirected pass only counts as a turnover if the other team '
        'recovers it', () {
      final recoveredByOwnTeam = MatchResult(
        homeScore: 0,
        awayScore: 0,
        homeScoreByQuarter: const [0],
        awayScoreByQuarter: const [0],
        events: [
          MatchEvent(
            type: MatchEventType.passRedirected,
            secondsElapsed: 0,
            player: reboundOff, // a home teammate recovers it
            secondPlayer: passer, // home player who threw the pass
          ),
        ],
        minutesPlayed: {
          for (final p in [...homeRoster, ...awayRoster]) p: 10.0,
        },
        personalFouls: const {},
        fouledOut: const {},
      );
      final recoveredByOtherTeam = MatchResult(
        homeScore: 0,
        awayScore: 0,
        homeScoreByQuarter: const [0],
        awayScoreByQuarter: const [0],
        events: [
          MatchEvent(
            type: MatchEventType.passRedirected,
            secondsElapsed: 0,
            player: redirectRecovererAway, // the other team recovers it
            secondPlayer: passer,
          ),
        ],
        minutesPlayed: {
          for (final p in [...homeRoster, ...awayRoster]) p: 10.0,
        },
        personalFouls: const {},
        fouledOut: const {},
      );

      final noTurnover = computeBoxScore(
        recoveredByOwnTeam,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ).firstWhere((b) => b.player == passer);
      final withTurnover = computeBoxScore(
        recoveredByOtherTeam,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      ).firstWhere((b) => b.player == passer);

      expect(noTurnover.turnovers, 0);
      expect(withTurnover.turnovers, 1);
    });

    test('still finds every player when homeRoster/awayRoster are different '
        'Player *objects* with the same ids as the ones in the match result '
        '-- regression test for a real bug (fixed 2026-08-10): '
        'advanceGameDay auto-resolving training in the same call it '
        'simulates a game day meant GameResultScreen could re-derive its '
        'roster from a *post-training* franchise (new Player objects for '
        'anyone whose ratings changed), while the match itself was '
        'simulated *pre-training* -- only players training left untouched '
        'still matched by object identity, silently dropping everyone '
        'else from the box score', () {
      final result = resultWithEvents([
        MatchEvent(
          type: MatchEventType.shotAttempt,
          secondsElapsed: 3,
          player: scorer,
          isThreePointAttempt: false,
        ),
        MatchEvent(
          type: MatchEventType.shotMade,
          secondsElapsed: 0,
          player: scorer,
          isThreePointAttempt: false,
          points: 2,
        ),
      ]);

      // Same ids, brand new Player objects -- exactly what a post-
      // training roster looks like for players whose ratings changed.
      final postTrainingHomeRoster = [
        for (final p in homeRoster) p.copyWithRatings(p.ratings),
      ];
      final postTrainingAwayRoster = [
        for (final p in awayRoster) p.copyWithRatings(p.ratings),
      ];
      expect(
        identical(postTrainingHomeRoster.first, homeRoster.first),
        isFalse,
        reason: 'the test setup itself must produce distinct objects',
      );

      final boxScores = computeBoxScore(
        result,
        homeRoster: postTrainingHomeRoster,
        awayRoster: postTrainingAwayRoster,
      );

      // Every one of the 10 players on the two test lineups shows up,
      // not just the ones an identity check would get lucky on.
      expect(boxScores.length, homeRoster.length + awayRoster.length);
      final postTrainingScorer = postTrainingHomeRoster.firstWhere(
        (p) => p.id == scorer.id,
      );
      final scorerLine = boxScores.firstWhere((b) => b.player.id == scorer.id);
      expect(scorerLine.points, 2);
      expect(scorerLine.player, same(postTrainingScorer));
    });

    test('only includes players who actually appeared in the game', () {
      final result = MatchResult(
        homeScore: 0,
        awayScore: 0,
        homeScoreByQuarter: const [0],
        awayScoreByQuarter: const [0],
        events: const [],
        minutesPlayed: {scorer: 12.0},
        personalFouls: const {},
        fouledOut: const {},
      );

      final boxScores = computeBoxScore(
        result,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );

      expect(boxScores.length, 1);
      expect(boxScores.single.player, scorer);
    });
  });

  group('computeBoxScore against a real simulated game', () {
    test('total points across all box scores equals the final score', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final match = simulateMatch(
        Random(41),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );

      final boxScores = computeBoxScore(
        match,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      final totalPoints = boxScores.fold<int>(0, (sum, b) => sum + b.points);

      expect(totalPoints, match.homeScore + match.awayScore);
    });

    test('every player with recorded minutes appears exactly once', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final match = simulateMatch(
        Random(41),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );

      final boxScores = computeBoxScore(
        match,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );

      expect(boxScores.length, match.minutesPlayed.length);
      expect(boxScores.map((b) => b.player).toSet().length, boxScores.length);
    });
  });
}
