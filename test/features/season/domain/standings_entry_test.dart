import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';

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

GameResult _game({
  required String home,
  required String away,
  required int homeScore,
  required int awayScore,
  GameType type = GameType.regularSeason,
  int? continentalCupRound,
}) {
  return GameResult(
    game: ScheduledGame(
      week: 1,
      homeTeamAbbreviation: home,
      awayTeamAbbreviation: away,
      type: type,
      continentalCupRound: continentalCupRound,
    ),
    match: _match(homeScore: homeScore, awayScore: awayScore),
  );
}

void main() {
  test('records a win for the home team and a loss for the away team', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 90, awayScore: 80),
    ]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    final bbb = standings.firstWhere((e) => e.teamAbbreviation == 'BBB');
    expect(aaa.wins, 1);
    expect(aaa.losses, 0);
    expect(bbb.wins, 0);
    expect(bbb.losses, 1);
  });

  test('records a win for the away team when they outscore the home team', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 70, awayScore: 85),
    ]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    final bbb = standings.firstWhere((e) => e.teamAbbreviation == 'BBB');
    expect(aaa.wins, 0);
    expect(aaa.losses, 1);
    expect(bbb.wins, 1);
    expect(bbb.losses, 0);
  });

  test('accumulates points for and against across multiple games', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 90, awayScore: 80),
      _game(home: 'BBB', away: 'AAA', homeScore: 70, awayScore: 100),
    ]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    expect(aaa.wins, 2);
    expect(aaa.losses, 0);
    expect(aaa.pointsFor, 190);
    expect(aaa.pointsAgainst, 150);
    expect(aaa.pointDifferential, 40);
  });

  test('ignores preseason and Continental Cup games', () {
    final standings = computeStandings([
      _game(
        home: 'AAA',
        away: 'BBB',
        homeScore: 90,
        awayScore: 80,
        type: GameType.preseason,
      ),
      _game(
        home: 'AAA',
        away: 'BBB',
        homeScore: 90,
        awayScore: 80,
        type: GameType.continentalCup,
        continentalCupRound: 1,
      ),
    ]);

    expect(standings, isEmpty);
  });

  test('sorts best win percentage first, point differential as a '
      'tiebreaker', () {
    final standings = computeStandings([
      // AAA: 1-1, +5 differential.
      _game(home: 'AAA', away: 'CCC', homeScore: 90, awayScore: 80),
      _game(home: 'DDD', away: 'AAA', homeScore: 85, awayScore: 70),
      // BBB: 1-1, +25 differential -- same record as AAA, better point
      // differential.
      _game(home: 'BBB', away: 'CCC', homeScore: 100, awayScore: 70),
      _game(home: 'DDD', away: 'BBB', homeScore: 90, awayScore: 60),
    ]);

    final aaaIndex = standings.indexWhere((e) => e.teamAbbreviation == 'AAA');
    final bbbIndex = standings.indexWhere((e) => e.teamAbbreviation == 'BBB');
    expect(bbbIndex, lessThan(aaaIndex));
  });

  test('gamesPlayed and winPercentage are derived correctly', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 90, awayScore: 80),
      _game(home: 'AAA', away: 'CCC', homeScore: 70, awayScore: 90),
    ]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    expect(aaa.gamesPlayed, 2);
    expect(aaa.winPercentage, closeTo(0.5, 1e-9));
  });
}
