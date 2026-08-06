import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';

ScheduledGame _game() {
  return const ScheduledGame(
    week: 2,
    day: GameDay.thursday,
    homeTeamAbbreviation: 'AAA',
    awayTeamAbbreviation: 'BBB',
    type: GameType.regularSeason,
  );
}

void main() {
  test('rejects a tied score', () {
    expect(
      () => PlayedGame(game: _game(), homeScore: 80, awayScore: 80),
      throwsA(isA<AssertionError>()),
    );
  });

  test('winningTeamAbbreviation/losingTeamAbbreviation reflect who scored '
      'more', () {
    final homeWon = PlayedGame(game: _game(), homeScore: 90, awayScore: 80);
    expect(homeWon.winningTeamAbbreviation, 'AAA');
    expect(homeWon.losingTeamAbbreviation, 'BBB');

    final awayWon = PlayedGame(game: _game(), homeScore: 70, awayScore: 85);
    expect(awayWon.winningTeamAbbreviation, 'BBB');
    expect(awayWon.losingTeamAbbreviation, 'AAA');
  });

  test('toGameResult carries the same score and fixture through', () {
    final played = PlayedGame(game: _game(), homeScore: 90, awayScore: 80);

    final result = played.toGameResult();

    expect(result.game, played.game);
    expect(result.match.homeScore, 90);
    expect(result.match.awayScore, 80);
    expect(result.winningTeamAbbreviation, 'AAA');
  });

  group('fromResult', () {
    test('carries the score/minutes/box score for every player who '
        'actually played', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      final opponent = franchise.league.aiTeams.first.team;
      final rosters = rostersByAbbreviation(franchise);
      final match = simulateMatch(
        Random(1),
        homeRoster: rosters[franchise.team.abbreviation]!,
        awayRoster: rosters[opponent.abbreviation]!,
      );
      final result = GameResult(
        game: ScheduledGame(
          week: 2,
          day: GameDay.sunday,
          homeTeamAbbreviation: franchise.team.abbreviation,
          awayTeamAbbreviation: opponent.abbreviation,
          type: GameType.regularSeason,
        ),
        match: match,
      );

      final played = PlayedGame.fromResult(
        result,
        rostersByAbbreviation: rosters,
      );

      expect(played.homeScore, match.homeScore);
      expect(played.awayScore, match.awayScore);
      // Every player with recorded minutes gets both a minutes entry and a
      // full box-score stat line, keyed by the same player id.
      for (final entry in match.minutesPlayed.entries) {
        final playerId = entry.key.id;
        expect(played.minutesByPlayerId[playerId], entry.value);
        final line = played.boxScoreByPlayerId[playerId];
        expect(line, isNotNull);
        expect(line!.minutesPlayed, entry.value);
      }
      // Team point totals reconcile: every player's points sum to the
      // final score on each side.
      final homeIds = rosters[franchise.team.abbreviation]!
          .map((p) => p.id)
          .toSet();
      final homePoints = played.boxScoreByPlayerId.entries
          .where((e) => homeIds.contains(e.key))
          .fold(0, (sum, e) => sum + e.value.points);
      expect(homePoints, match.homeScore);
    });
  });
}
