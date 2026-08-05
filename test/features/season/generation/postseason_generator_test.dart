import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';

import '../../../support/match_test_players.dart';

List<StandingsEntry> _standings(List<String> abbreviationsBestFirst) {
  return [
    for (var i = 0; i < abbreviationsBestFirst.length; i++)
      StandingsEntry(
        teamAbbreviation: abbreviationsBestFirst[i],
        wins: abbreviationsBestFirst.length - i,
        losses: i,
        pointsFor: 0,
        pointsAgainst: 0,
      ),
  ];
}

Map<String, List<Player>> _rostersFor(List<String> abbreviations) {
  return {
    for (var i = 0; i < abbreviations.length; i++)
      abbreviations[i]: testRoster(abbreviations[i], baseRating: 60 - i),
  };
}

const _eightSeeds = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'];

void main() {
  group('postseasonSeeds', () {
    test('takes the top 8 teams from standings, best record first', () {
      final teams = [for (var i = 0; i < 12; i++) 'T$i'];
      final seeds = postseasonSeeds(_standings(teams));

      expect(seeds, teams.take(8).toList());
    });

    test('throws when fewer than 8 teams are in standings', () {
      final teams = [for (var i = 0; i < 6; i++) 'T$i'];

      expect(
        () => postseasonSeeds(_standings(teams)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('simulateSeries', () {
    test('is deterministic for a given seed', () {
      final rosters = _rostersFor(['A', 'B']);

      final a = simulateSeries(
        Random(11),
        higherSeedAbbreviation: 'A',
        lowerSeedAbbreviation: 'B',
        winsNeeded: 2,
        week: 20,
        round: 1,
        rostersByAbbreviation: rosters,
      );
      final b = simulateSeries(
        Random(11),
        higherSeedAbbreviation: 'A',
        lowerSeedAbbreviation: 'B',
        winsNeeded: 2,
        week: 20,
        round: 1,
        rostersByAbbreviation: rosters,
      );

      expect(a.winningTeamAbbreviation, b.winningTeamAbbreviation);
      expect(a.games.length, b.games.length);
    });

    test('stops as soon as one side reaches winsNeeded -- a sweep is '
        'shorter than a full series', () {
      final rosters = _rostersFor(['A', 'B']);
      final random = Random(3);

      for (var i = 0; i < 50; i++) {
        final result = simulateSeries(
          random,
          higherSeedAbbreviation: 'A',
          lowerSeedAbbreviation: 'B',
          winsNeeded: 2,
          week: 20,
          round: 1,
          rostersByAbbreviation: rosters,
        );

        expect(result.games.length, inInclusiveRange(2, 3));
        expect(result.higherSeedWins >= 2 || result.lowerSeedWins >= 2, isTrue);
        expect(result.higherSeedWins < 2 || result.lowerSeedWins < 2, isTrue);
      }
    });

    test('every game is tagged with the right type, round, and week', () {
      final rosters = _rostersFor(['A', 'B']);

      final result = simulateSeries(
        Random(9),
        higherSeedAbbreviation: 'A',
        lowerSeedAbbreviation: 'B',
        winsNeeded: 3,
        week: kPostseasonSemifinalsWeek,
        round: 2,
        rostersByAbbreviation: rosters,
      );

      for (final g in result.games) {
        expect(g.game.type, GameType.postseason);
        expect(g.game.postseasonRound, 2);
        expect(g.game.week, kPostseasonSemifinalsWeek);
      }
    });

    test('the higher seed hosts the first 2 games of every series length', () {
      final rosters = _rostersFor(['A', 'B']);
      final random = Random(5);

      for (var i = 0; i < 20; i++) {
        final result = simulateSeries(
          random,
          higherSeedAbbreviation: 'A',
          lowerSeedAbbreviation: 'B',
          winsNeeded: 4,
          week: kPostseasonFinalsWeek,
          round: 3,
          rostersByAbbreviation: rosters,
        );

        expect(result.games[0].game.homeTeamAbbreviation, 'A');
        expect(result.games[1].game.homeTeamAbbreviation, 'A');
      }
    });
  });

  group('generatePostseasonFirstRound', () {
    test('produces 4 best-of-3 series in 1v8/2v7/3v6/4v5 bracket order', () {
      final rosters = _rostersFor(_eightSeeds);

      final results = generatePostseasonFirstRound(
        Random(1),
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );

      expect(results.length, 4);
      expect(results[0].higherSeedAbbreviation, 'S1');
      expect(results[0].lowerSeedAbbreviation, 'S8');
      expect(results[1].higherSeedAbbreviation, 'S2');
      expect(results[1].lowerSeedAbbreviation, 'S7');
      expect(results[2].higherSeedAbbreviation, 'S3');
      expect(results[2].lowerSeedAbbreviation, 'S6');
      expect(results[3].higherSeedAbbreviation, 'S4');
      expect(results[3].lowerSeedAbbreviation, 'S5');
      for (final r in results) {
        expect(r.winsNeeded, 2);
      }
    });

    test('throws unless given exactly 8 seeds', () {
      expect(
        () => generatePostseasonFirstRound(
          Random(1),
          seeds: _eightSeeds.take(6).toList(),
          rostersByAbbreviation: _rostersFor(_eightSeeds),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('generatePostseasonSemifinals', () {
    test('pairs game-0 winner with game-3 winner, and game-1 with game-2, '
        'each a best-of-5', () {
      final rosters = _rostersFor(_eightSeeds);
      final firstRound = generatePostseasonFirstRound(
        Random(2),
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );

      final semis = generatePostseasonSemifinals(
        Random(2),
        firstRoundResults: firstRound,
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );

      expect(semis.length, 2);
      final semi0Teams = {
        semis[0].higherSeedAbbreviation,
        semis[0].lowerSeedAbbreviation,
      };
      final semi1Teams = {
        semis[1].higherSeedAbbreviation,
        semis[1].lowerSeedAbbreviation,
      };
      expect(semi0Teams, {
        firstRound[0].winningTeamAbbreviation,
        firstRound[3].winningTeamAbbreviation,
      });
      expect(semi1Teams, {
        firstRound[1].winningTeamAbbreviation,
        firstRound[2].winningTeamAbbreviation,
      });
      for (final s in semis) {
        expect(s.winsNeeded, 3);
      }
    });

    test('throws unless given exactly 4 First Round results', () {
      expect(
        () => generatePostseasonSemifinals(
          Random(1),
          firstRoundResults: [],
          seeds: _eightSeeds,
          rostersByAbbreviation: _rostersFor(_eightSeeds),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('generatePostseasonFinals', () {
    test('is a single best-of-7 series between the 2 Semifinal winners', () {
      final rosters = _rostersFor(_eightSeeds);
      final firstRound = generatePostseasonFirstRound(
        Random(4),
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );
      final semis = generatePostseasonSemifinals(
        Random(4),
        firstRoundResults: firstRound,
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );

      final finals = generatePostseasonFinals(
        Random(4),
        semifinalResults: semis,
        seeds: _eightSeeds,
        rostersByAbbreviation: rosters,
      );

      expect(finals.winsNeeded, 4);
      final finalists = {
        finals.higherSeedAbbreviation,
        finals.lowerSeedAbbreviation,
      };
      expect(finalists, {
        semis[0].winningTeamAbbreviation,
        semis[1].winningTeamAbbreviation,
      });
    });

    test('throws unless given exactly 2 Semifinal results', () {
      expect(
        () => generatePostseasonFinals(
          Random(1),
          semifinalResults: [],
          seeds: _eightSeeds,
          rostersByAbbreviation: _rostersFor(_eightSeeds),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('a full bracket chains end to end to a single champion', () {
    final rosters = _rostersFor(_eightSeeds);
    final random = Random(2026);

    final firstRound = generatePostseasonFirstRound(
      random,
      seeds: _eightSeeds,
      rostersByAbbreviation: rosters,
    );
    final semis = generatePostseasonSemifinals(
      random,
      firstRoundResults: firstRound,
      seeds: _eightSeeds,
      rostersByAbbreviation: rosters,
    );
    final finals = generatePostseasonFinals(
      random,
      semifinalResults: semis,
      seeds: _eightSeeds,
      rostersByAbbreviation: rosters,
    );

    expect(_eightSeeds, contains(finals.winningTeamAbbreviation));
  });
}
