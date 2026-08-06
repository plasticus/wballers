import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';
import 'package:womensbballmgr/features/season/generation/season_simulator.dart';

import '../../../support/match_test_players.dart';

SeasonSchedule _miniSchedule() {
  return const SeasonSchedule(
    games: [
      ScheduledGame(
        week: 2,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'AAA',
        awayTeamAbbreviation: 'BBB',
        type: GameType.regularSeason,
      ),
      ScheduledGame(
        week: 1,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'CCC',
        awayTeamAbbreviation: 'DDD',
        type: GameType.preseason,
      ),
      ScheduledGame(
        week: 3,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BBB',
        awayTeamAbbreviation: 'CCC',
        type: GameType.regularSeason,
      ),
    ],
  );
}

Map<String, List<Player>> _rosters() {
  return {
    'AAA': testRoster('AAA', baseRating: 70),
    'BBB': testRoster('BBB', baseRating: 60),
    'CCC': testRoster('CCC', baseRating: 50),
    'DDD': testRoster('DDD', baseRating: 40),
  };
}

void main() {
  test('produces one GameResult per scheduled game', () {
    final results = simulateSeason(
      Random(5),
      schedule: _miniSchedule(),
      rostersByAbbreviation: _rosters(),
    );

    expect(results.length, 3);
  });

  test('is deterministic for a given seed', () {
    final schedule = _miniSchedule();
    final rosters = _rosters();

    final a = simulateSeason(
      Random(9),
      schedule: schedule,
      rostersByAbbreviation: rosters,
    );
    final b = simulateSeason(
      Random(9),
      schedule: schedule,
      rostersByAbbreviation: rosters,
    );

    for (var i = 0; i < a.length; i++) {
      expect(a[i].match.homeScore, b[i].match.homeScore);
      expect(a[i].match.awayScore, b[i].match.awayScore);
    }
  });

  test('simulates games in week order regardless of schedule list order', () {
    final results = simulateSeason(
      Random(5),
      schedule: _miniSchedule(),
      rostersByAbbreviation: _rosters(),
    );

    final weeks = results.map((r) => r.game.week).toList();
    expect(weeks, [1, 2, 3]);
  });

  test('each result only credits minutes to players from its own two '
      'rosters', () {
    final rosters = _rosters();
    final results = simulateSeason(
      Random(5),
      schedule: _miniSchedule(),
      rostersByAbbreviation: rosters,
    );

    for (final result in results) {
      final expectedIds = {
        ...rosters[result.game.homeTeamAbbreviation]!.map((p) => p.id),
        ...rosters[result.game.awayTeamAbbreviation]!.map((p) => p.id),
      };
      final creditedIds = result.match.minutesPlayed.keys
          .map((p) => p.id)
          .toSet();
      // Not every roster player is guaranteed to log minutes (a bench
      // player could end up never picked), so this checks a subset, not
      // equality -- what matters is nobody from an unrelated roster shows
      // up.
      expect(creditedIds.difference(expectedIds), isEmpty);
      expect(creditedIds, isNotEmpty);
    }
  });

  test('feeding results into computeStandings produces a table covering '
      'only the regular-season games', () {
    final results = simulateSeason(
      Random(5),
      schedule: _miniSchedule(),
      rostersByAbbreviation: _rosters(),
    );

    final standings = computeStandings(
      results,
      leagueTeams: [
        for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD'])
          Team(
            abbreviation: abbr,
            location: 'Testville',
            name: abbr,
            conference: Conference.atlantic,
            colors: const TeamColors(
              primaryHex: '#000000',
              secondaryHex: '#111111',
              accentHex: '#222222',
            ),
            identityNote: '',
          ),
      ],
    );
    final totalGamesPlayed = standings.fold<int>(
      0,
      (sum, e) => sum + e.gamesPlayed,
    );
    // 2 regular-season games x 2 teams each = 4 team-appearances; the
    // preseason game (CCC vs DDD) contributes nothing.
    expect(totalGamesPlayed, 4);
    expect(standings.map((e) => e.teamAbbreviation).toSet(), {
      'AAA',
      'BBB',
      'CCC',
    });
  });
}
