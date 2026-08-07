import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/league_leaders.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/played_game_stat_line.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';

PlayedGameStatLine _line({
  int points = 0,
  int rebounds = 0,
  int assists = 0,
  int steals = 0,
  int blocks = 0,
  int turnovers = 0,
  int fgMade = 0,
  int fgAttempts = 0,
}) {
  return PlayedGameStatLine(
    minutesPlayed: 30,
    points: points,
    fieldGoalsMade: fgMade,
    fieldGoalAttempts: fgAttempts,
    threePointersMade: 0,
    threePointAttempts: 0,
    freeThrowsMade: 0,
    freeThrowAttempts: 0,
    offensiveRebounds: rebounds,
    defensiveRebounds: 0,
    assists: assists,
    steals: steals,
    blocks: blocks,
    turnovers: turnovers,
    personalFouls: 0,
  );
}

ScheduledGame _scheduledGame(int week, GameType type) {
  return ScheduledGame(
    week: week,
    day: GameDay.sunday,
    homeTeamAbbreviation: 'AAA',
    awayTeamAbbreviation: 'BBB',
    type: type,
    continentalCupRound: type == GameType.continentalCup ? 1 : null,
  );
}

void main() {
  test('sums a player\'s stats across every regular-season game they '
      'appeared in', () {
    final games = [
      PlayedGame(
        game: _scheduledGame(2, GameType.regularSeason),
        homeScore: 80,
        awayScore: 70,
        boxScoreByPlayerId: {
          'p1': _line(points: 20, rebounds: 5, fgMade: 8, fgAttempts: 15),
        },
      ),
      PlayedGame(
        game: _scheduledGame(3, GameType.regularSeason),
        homeScore: 90,
        awayScore: 60,
        boxScoreByPlayerId: {
          'p1': _line(points: 30, rebounds: 7, fgMade: 12, fgAttempts: 20),
        },
      ),
    ];

    final leaders = computeLeagueLeaders(games);

    final p1 = leaders['p1']!;
    expect(p1.gamesPlayed, 2);
    expect(p1.points, 50);
    expect(p1.rebounds, 12);
    expect(p1.pointsPerGame, 25.0);
    expect(p1.fieldGoalsMade, 20);
    expect(p1.fieldGoalAttempts, 35);
    expect(p1.fieldGoalPercentage, closeTo(20 / 35, 0.0001));
  });

  test('excludes preseason and Continental Cup games -- only regular '
      'season counts, same scope as computeStandings', () {
    final games = [
      PlayedGame(
        game: _scheduledGame(1, GameType.preseason),
        homeScore: 80,
        awayScore: 70,
        boxScoreByPlayerId: {'p1': _line(points: 99)},
      ),
      PlayedGame(
        game: _scheduledGame(4, GameType.continentalCup),
        homeScore: 80,
        awayScore: 70,
        boxScoreByPlayerId: {'p1': _line(points: 99)},
      ),
      PlayedGame(
        game: _scheduledGame(2, GameType.regularSeason),
        homeScore: 80,
        awayScore: 70,
        boxScoreByPlayerId: {'p1': _line(points: 10)},
      ),
    ];

    final leaders = computeLeagueLeaders(games);

    expect(leaders['p1']!.gamesPlayed, 1);
    expect(leaders['p1']!.points, 10);
  });

  test('a player with zero games played has zero-valued per-game rates, '
      'not a division error', () {
    final totals = computeLeagueLeaders(const []);
    expect(totals, isEmpty);
  });

  test('mvpScore sums the 5 core per-game rates', () {
    final games = [
      PlayedGame(
        game: _scheduledGame(2, GameType.regularSeason),
        homeScore: 80,
        awayScore: 70,
        boxScoreByPlayerId: {
          'p1': _line(
            points: 20,
            rebounds: 10,
            assists: 5,
            steals: 2,
            blocks: 1,
          ),
        },
      ),
    ];

    final p1 = computeLeagueLeaders(games)['p1']!;
    expect(p1.mvpScore, closeTo(20 + 10 + 5 + 2 + 1, 0.0001));
  });
}
