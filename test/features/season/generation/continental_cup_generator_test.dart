import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/continental_cup_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';

MatchResult _match({required int homeScore, required int awayScore}) {
  return MatchResult(
    homeScore: homeScore,
    awayScore: awayScore,
    homeScoreByQuarter: [homeScore],
    awayScoreByQuarter: [awayScore],
    events: const [],
    minutesPlayed: const {},
    personalFouls: const {},
    fouledOut: const {},
  );
}

GameResult _cupGame({
  required String home,
  required String away,
  required int homeScore,
  required int awayScore,
  required int round,
}) {
  return GameResult(
    game: ScheduledGame(
      week: 1,
      day: GameDay.thursday,
      homeTeamAbbreviation: home,
      awayTeamAbbreviation: away,
      type: GameType.continentalCup,
      continentalCupRound: round,
    ),
    match: _match(homeScore: homeScore, awayScore: awayScore),
  );
}

/// 10 Round 1 results with distinct, known margins (10, 20, ..., 100) so
/// the bye cutoff is unambiguous: winners with margins 50-100 (the top 6)
/// get byes, winners with margins 10-40 (the bottom 4) play Round 2.
List<GameResult> _round1ResultsWithKnownMargins() {
  return [
    for (var i = 0; i < 10; i++)
      _cupGame(
        home: 'W$i',
        away: 'L$i',
        homeScore: 80 + (i + 1) * 10,
        awayScore: 80,
        round: 1,
      ),
  ];
}

void main() {
  group('generateContinentalCupRound2', () {
    test('produces exactly 2 games, both Round 2 Continental Cup games', () {
      final result = generateContinentalCupRound2(
        _round1ResultsWithKnownMargins(),
        Random(1),
      );

      expect(result.games.length, 2);
      for (final game in result.games) {
        expect(game.type, GameType.continentalCup);
        expect(game.continentalCupRound, 2);
        expect(game.week, kContinentalCupRound2Week);
      }
    });

    test('gives byes to the 6 highest-margin winners', () {
      final result = generateContinentalCupRound2(
        _round1ResultsWithKnownMargins(),
        Random(1),
      );

      // Margins 50-100 belong to W4 through W9 (index i has margin
      // (i+1)*10).
      expect(result.byeTeamAbbreviations.toSet(), {
        'W4',
        'W5',
        'W6',
        'W7',
        'W8',
        'W9',
      });
    });

    test('the 2 games exactly cover the 4 lowest-margin winners', () {
      final result = generateContinentalCupRound2(
        _round1ResultsWithKnownMargins(),
        Random(1),
      );

      final playing = {
        for (final g in result.games) ...[
          g.homeTeamAbbreviation,
          g.awayTeamAbbreviation,
        ],
      };
      expect(playing, {'W0', 'W1', 'W2', 'W3'});
    });

    test('is deterministic for a given seed', () {
      final a = generateContinentalCupRound2(
        _round1ResultsWithKnownMargins(),
        Random(7),
      );
      final b = generateContinentalCupRound2(
        _round1ResultsWithKnownMargins(),
        Random(7),
      );

      expect(a.byeTeamAbbreviations, b.byeTeamAbbreviations);
      expect(
        a.games.map((g) => (g.homeTeamAbbreviation, g.awayTeamAbbreviation)),
        b.games.map((g) => (g.homeTeamAbbreviation, g.awayTeamAbbreviation)),
      );
    });

    test('throws unless given exactly 10 Round 1 results', () {
      expect(
        () => generateContinentalCupRound2(
          _round1ResultsWithKnownMargins().take(9).toList(),
          Random(1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('generateContinentalCupRound3', () {
    test('produces exactly 4 Quarterfinal games covering all 8 teams once '
        'each', () {
      final byes = ['B1', 'B2', 'B3', 'B4', 'B5', 'B6'];
      final round2Results = [
        _cupGame(
          home: 'S1',
          away: 'S2',
          homeScore: 90,
          awayScore: 80,
          round: 2,
        ),
        _cupGame(
          home: 'S3',
          away: 'S4',
          homeScore: 85,
          awayScore: 88,
          round: 2,
        ),
      ];

      final games = generateContinentalCupRound3(
        byes,
        round2Results,
        Random(1),
      );

      expect(games.length, 4);
      final field = {
        for (final g in games) ...[
          g.homeTeamAbbreviation,
          g.awayTeamAbbreviation,
        ],
      };
      expect(field, {'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'S1', 'S4'});
      for (final g in games) {
        expect(g.continentalCupRound, 3);
        expect(g.week, kContinentalCupRound3Week);
      }
    });

    test('throws unless given exactly 6 byes and 2 Round 2 results', () {
      final round2Results = [
        _cupGame(
          home: 'S1',
          away: 'S2',
          homeScore: 90,
          awayScore: 80,
          round: 2,
        ),
      ];

      expect(
        () => generateContinentalCupRound3(
          ['B1', 'B2'],
          round2Results,
          Random(1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('generateContinentalCupRound4', () {
    test('produces exactly 2 Semifinal games covering all 4 winners once '
        'each', () {
      final round3Results = [
        _cupGame(
          home: 'Q1',
          away: 'Q2',
          homeScore: 90,
          awayScore: 80,
          round: 3,
        ),
        _cupGame(
          home: 'Q3',
          away: 'Q4',
          homeScore: 70,
          awayScore: 75,
          round: 3,
        ),
        _cupGame(
          home: 'Q5',
          away: 'Q6',
          homeScore: 95,
          awayScore: 60,
          round: 3,
        ),
        _cupGame(
          home: 'Q7',
          away: 'Q8',
          homeScore: 66,
          awayScore: 68,
          round: 3,
        ),
      ];

      final games = generateContinentalCupRound4(round3Results, Random(1));

      expect(games.length, 2);
      final field = {
        for (final g in games) ...[
          g.homeTeamAbbreviation,
          g.awayTeamAbbreviation,
        ],
      };
      expect(field, {'Q1', 'Q4', 'Q5', 'Q8'});
      for (final g in games) {
        expect(g.continentalCupRound, 4);
        expect(g.week, kContinentalCupRound4Week);
      }
    });

    test('throws unless given exactly 4 Round 3 results', () {
      expect(
        () => generateContinentalCupRound4([], Random(1)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('generateContinentalCupRound5', () {
    test('produces exactly 1 Final game between the 2 Semifinal winners', () {
      final round4Results = [
        _cupGame(
          home: 'F1',
          away: 'F2',
          homeScore: 90,
          awayScore: 80,
          round: 4,
        ),
        _cupGame(
          home: 'F3',
          away: 'F4',
          homeScore: 70,
          awayScore: 75,
          round: 4,
        ),
      ];

      final games = generateContinentalCupRound5(round4Results, Random(1));

      expect(games.length, 1);
      final field = {
        games.first.homeTeamAbbreviation,
        games.first.awayTeamAbbreviation,
      };
      expect(field, {'F1', 'F4'});
      expect(games.first.continentalCupRound, 5);
      expect(games.first.week, kContinentalCupRound5Week);
    });

    test('throws unless given exactly 2 Round 4 results', () {
      expect(
        () => generateContinentalCupRound5([], Random(1)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('continentalCupChampion', () {
    test('null until the Round 5 Final has actually been played', () {
      final playedGames = [
        _playedCupGame(
          home: 'F1',
          away: 'F2',
          homeScore: 80,
          awayScore: 70,
          round: 4,
        ),
      ];

      expect(continentalCupChampion(playedGames), isNull);
    });

    test('the Final\'s winner once it\'s been played', () {
      final playedGames = [
        _playedCupGame(
          home: 'F1',
          away: 'F2',
          homeScore: 80,
          awayScore: 70,
          round: 4,
        ),
        _playedCupGame(
          home: 'F1',
          away: 'F3',
          homeScore: 65,
          awayScore: 90,
          round: 5,
        ),
      ];

      expect(continentalCupChampion(playedGames), 'F3');
    });
  });
}

PlayedGame _playedCupGame({
  required String home,
  required String away,
  required int homeScore,
  required int awayScore,
  required int round,
}) {
  return PlayedGame(
    game: ScheduledGame(
      week: 1,
      day: GameDay.thursday,
      homeTeamAbbreviation: home,
      awayTeamAbbreviation: away,
      type: GameType.continentalCup,
      continentalCupRound: round,
    ),
    homeScore: homeScore,
    awayScore: awayScore,
  );
}
