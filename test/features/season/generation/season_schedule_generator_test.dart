import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/all_star_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';

List<Team> _leagueTeams() {
  final atlantic = kLeagueTeamPool
      .where((team) => team.conference == Conference.atlantic)
      .take(10);
  final pacific = kLeagueTeamPool
      .where((team) => team.conference == Conference.pacific)
      .take(10);
  return [...atlantic, ...pacific];
}

Map<String, List<ScheduledGame>> _gamesByTeam(List<ScheduledGame> games) {
  final byTeam = <String, List<ScheduledGame>>{};
  for (final game in games) {
    byTeam.putIfAbsent(game.homeTeamAbbreviation, () => []).add(game);
    byTeam.putIfAbsent(game.awayTeamAbbreviation, () => []).add(game);
  }
  return byTeam;
}

void main() {
  test('every team gets exactly 2 preseason games, both inter-conference', () {
    final teams = _leagueTeams();
    final byAbbreviation = {for (final team in teams) team.abbreviation: team};
    final schedule = generateSeasonSchedule(teams, Random(1));

    final preseasonByTeam = _gamesByTeam(
      schedule.games.where((g) => g.type == GameType.preseason).toList(),
    );

    for (final team in teams) {
      final games = preseasonByTeam[team.abbreviation]!;
      expect(games, hasLength(2));
      for (final game in games) {
        final opponentAbbreviation =
            game.homeTeamAbbreviation == team.abbreviation
            ? game.awayTeamAbbreviation
            : game.homeTeamAbbreviation;
        expect(
          byAbbreviation[opponentAbbreviation]!.conference,
          isNot(team.conference),
        );
      }
    }
  });

  test('a team never faces the same preseason opponent twice (2026-08-21, '
      'a GM bug report: two independent shuffles used to be able to repeat '
      'a pairing by chance) -- checked across many seeds since it\'s a '
      'chance-based bug', () {
    final teams = _leagueTeams();
    for (var seed = 0; seed < 200; seed++) {
      final schedule = generateSeasonSchedule(teams, Random(seed));
      final preseasonByTeam = _gamesByTeam(
        schedule.games.where((g) => g.type == GameType.preseason).toList(),
      );
      for (final team in teams) {
        final games = preseasonByTeam[team.abbreviation]!;
        final opponents = games.map(
          (game) => game.homeTeamAbbreviation == team.abbreviation
              ? game.awayTeamAbbreviation
              : game.homeTeamAbbreviation,
        );
        expect(
          opponents.toSet(),
          hasLength(2),
          reason:
              'seed $seed, team ${team.abbreviation} faced the same '
              'preseason opponent twice',
        );
      }
    }
  });

  test('never crashes across a wide sweep of seeds (2026-08-21, a real bug: '
      'the regular-season greedy packer could paint itself into a corner '
      'for an unlucky pair order and hit a null-check crash -- now retries '
      'with a reshuffled order instead of ever throwing)', () {
    final teams = _leagueTeams();
    for (var seed = 0; seed < 500; seed++) {
      expect(
        () => generateSeasonSchedule(teams, Random(seed)),
        returnsNormally,
        reason: 'seed $seed crashed',
      );
    }
  });

  test('every team gets exactly 28 regular-season games: 18 intra-conference '
      '(2x each of 9 opponents) + 10 inter-conference (1x each of 10)', () {
    final teams = _leagueTeams();
    final byAbbreviation = {for (final team in teams) team.abbreviation: team};
    final schedule = generateSeasonSchedule(teams, Random(2));

    final regularSeasonByTeam = _gamesByTeam(
      schedule.games.where((g) => g.type == GameType.regularSeason).toList(),
    );

    for (final team in teams) {
      final games = regularSeasonByTeam[team.abbreviation]!;
      expect(games, hasLength(28));

      final opponentCounts = <String, int>{};
      for (final game in games) {
        final opponentAbbreviation =
            game.homeTeamAbbreviation == team.abbreviation
            ? game.awayTeamAbbreviation
            : game.homeTeamAbbreviation;
        opponentCounts[opponentAbbreviation] =
            (opponentCounts[opponentAbbreviation] ?? 0) + 1;
      }

      for (final entry in opponentCounts.entries) {
        final opponent = byAbbreviation[entry.key]!;
        final expectedCount = opponent.conference == team.conference ? 2 : 1;
        expect(entry.value, expectedCount, reason: entry.key);
      }
      expect(opponentCounts.keys, hasLength(19));
    }
  });

  test('regular-season games stay within the regular season week window, '
      'and no team ever gets more than 2 games in the same week', () {
    final teams = _leagueTeams();
    final schedule = generateSeasonSchedule(teams, Random(3));
    final regularSeasonGames = schedule.games
        .where((g) => g.type == GameType.regularSeason)
        .toList();

    for (final game in regularSeasonGames) {
      expect(
        game.week,
        inInclusiveRange(kRegularSeasonStartWeek, kRegularSeasonEndWeek),
      );
    }

    final countsByTeamAndWeek = <String, Map<int, int>>{};
    for (final game in regularSeasonGames) {
      for (final abbreviation in [
        game.homeTeamAbbreviation,
        game.awayTeamAbbreviation,
      ]) {
        final byWeek = countsByTeamAndWeek.putIfAbsent(abbreviation, () => {});
        byWeek[game.week] = (byWeek[game.week] ?? 0) + 1;
      }
    }
    for (final byWeek in countsByTeamAndWeek.values) {
      for (final count in byWeek.values) {
        expect(count, lessThanOrEqualTo(2));
      }
    }
  });

  test('Continental Cup Round 1 has 10 games, all 20 teams appear exactly '
      'once, in week 4', () {
    final teams = _leagueTeams();
    final schedule = generateSeasonSchedule(teams, Random(4));
    final cupGames = schedule.games
        .where((g) => g.type == GameType.continentalCup)
        .toList();

    expect(cupGames, hasLength(10));
    for (final game in cupGames) {
      expect(game.week, kContinentalCupRound1Week);
      expect(game.continentalCupRound, 1);
    }

    final appearances = <String>[
      for (final game in cupGames) ...[
        game.homeTeamAbbreviation,
        game.awayTeamAbbreviation,
      ],
    ];
    expect(appearances.toSet(), hasLength(20));
    expect(appearances, hasLength(20));
  });

  test('no team is ever double-booked on the same (week, day) -- '
      'Continental Cup Round 1 in particular used to collide with a '
      'regular-season game in week 4 (fixed 2026-08-07)', () {
    final teams = _leagueTeams();
    for (var seed = 0; seed < 30; seed++) {
      final schedule = generateSeasonSchedule(teams, Random(seed));
      final byTeam = _gamesByTeam(schedule.games);
      for (final entry in byTeam.entries) {
        final seen = <(int, GameDay)>{};
        for (final game in entry.value) {
          final key = (game.week, game.day);
          expect(
            seen.contains(key),
            isFalse,
            reason:
                'seed $seed: ${entry.key} has two games on week '
                '${game.week} ${game.day}',
          );
          seen.add(key);
        }
      }
    }
  });

  test('is deterministic for the same random stream', () {
    final teams = _leagueTeams();
    final a = generateSeasonSchedule(teams, Random(9));
    final b = generateSeasonSchedule(teams, Random(9));

    expect(a.games, hasLength(b.games.length));
    for (var i = 0; i < a.games.length; i++) {
      expect(a.games[i].week, b.games[i].week);
      expect(a.games[i].homeTeamAbbreviation, b.games[i].homeTeamAbbreviation);
      expect(a.games[i].awayTeamAbbreviation, b.games[i].awayTeamAbbreviation);
      expect(a.games[i].type, b.games[i].type);
    }
  });

  test('total game count is 20 preseason + 280 regular season + 10 cup', () {
    final teams = _leagueTeams();
    final schedule = generateSeasonSchedule(teams, Random(5));

    expect(
      schedule.games.where((g) => g.type == GameType.preseason),
      hasLength(20),
    );
    expect(
      schedule.games.where((g) => g.type == GameType.regularSeason),
      hasLength(280),
    );
    expect(
      schedule.games.where((g) => g.type == GameType.continentalCup),
      hasLength(10),
    );
  });

  test('bye days are spread across the season, not back-loaded onto its '
      'last couple of weeks (2026-08-19, a direct GM ask after watching a '
      'real season end with 2 completely dead weeks)', () {
    final teams = _leagueTeams();

    for (var seed = 0; seed < 10; seed++) {
      final schedule = generateSeasonSchedule(teams, Random(seed));
      final regularSeasonGames = schedule.games
          .where((g) => g.type == GameType.regularSeason)
          .toList();

      final gamesPerWeek = <int, int>{};
      for (final game in regularSeasonGames) {
        gamesPerWeek[game.week] = (gamesPerWeek[game.week] ?? 0) + 1;
      }

      // Every regular-season week has *some* real action -- the failure
      // mode this guards against is a week (usually the last one or two)
      // sitting at literal zero for the entire league, not merely having
      // fewer games than average.
      for (
        var week = kRegularSeasonStartWeek;
        week <= kRegularSeasonEndWeek;
        week++
      ) {
        expect(
          gamesPerWeek[week] ?? 0,
          greaterThan(0),
          reason:
              'seed $seed: week $week has no regular-season games at '
              'all',
        );
      }

      // No week is left carrying dramatically more than its fair share
      // either -- the old back-loaded shape had week 4 (a 1-day week,
      // Thursday reserved for the Cup) as the only real outlier; every
      // other week should land within a small band of the 280-game,
      // 17-week average (~16.5/week).
      final loadedWeeks = gamesPerWeek.entries.where(
        (e) => e.key != kContinentalCupRound1Week,
      );
      for (final entry in loadedWeeks) {
        expect(
          entry.value,
          inInclusiveRange(10, 20),
          reason: 'seed $seed: week ${entry.key} has ${entry.value} games',
        );
      }
    }
  });

  test('the All-Star week has exactly 2 entries, and the Skills Competition '
      'resolves before the Game (2026-08-10, TODO.md items 5/6)', () {
    final teams = _leagueTeams();
    final schedule = generateSeasonSchedule(teams, Random(5));

    final allStarGames = schedule.games
        .where((g) => g.week == kAllStarWeek)
        .toList();
    expect(allStarGames, hasLength(2));
    expect(allStarGames.map((g) => g.type).toSet(), {
      GameType.skillsCompetition,
      GameType.allStarGame,
    });

    // Regardless of which literal GameDay each uses, the Skills
    // Competition must sort ahead of the Game in gameDaysInOrder --
    // see `all_star_generator.dart`'s own doc comment on why this
    // isn't simply "Thursday, then Sunday."
    final order = gameDaysInOrder(
      schedule,
    ).where((d) => d.$1 == kAllStarWeek).toList();
    expect(order, hasLength(2));
    final skillsDay = allStarGames
        .firstWhere((g) => g.type == GameType.skillsCompetition)
        .day;
    final gameDay = allStarGames
        .firstWhere((g) => g.type == GameType.allStarGame)
        .day;
    expect(order.first.$2, skillsDay);
    expect(order.last.$2, gameDay);
  });
}
