import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';

const _dummyColors = TeamColors(
  primaryHex: '#000000',
  secondaryHex: '#111111',
  accentHex: '#222222',
);

Team _team(String abbreviation, Conference conference) {
  return Team(
    abbreviation: abbreviation,
    location: 'Testville',
    name: abbreviation,
    conference: conference,
    colors: _dummyColors,
    identityNote: '',
  );
}

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

/// Every fixture team defaults to the same conference -- most tests below
/// don't exercise the conference-record tiebreaker, so this keeps them
/// simple. Tests that specifically exercise conference splits build their
/// own team list.
final _sameConferenceTeams = [
  for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD', 'EEE', 'FFF'])
    _team(abbr, Conference.atlantic),
];

void main() {
  test('records a win for the home team and a loss for the away team', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 90, awayScore: 80),
    ], leagueTeams: _sameConferenceTeams);

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
    ], leagueTeams: _sameConferenceTeams);

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
    ], leagueTeams: _sameConferenceTeams);

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
    ], leagueTeams: _sameConferenceTeams);

    expect(standings, isEmpty);
  });

  test('gamesPlayed and winPercentage are derived correctly', () {
    final standings = computeStandings([
      _game(home: 'AAA', away: 'BBB', homeScore: 90, awayScore: 80),
      _game(home: 'AAA', away: 'CCC', homeScore: 70, awayScore: 90),
    ], leagueTeams: _sameConferenceTeams);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    expect(aaa.gamesPlayed, 2);
    expect(aaa.winPercentage, closeTo(0.5, 1e-9));
  });

  group('tiebreakers', () {
    test('head-to-head record breaks a tie between two teams', () {
      final standings = computeStandings([
        // AAA and BBB both finish 1-1 overall, but AAA won their one
        // meeting -- that alone should decide it.
        _game(home: 'AAA', away: 'BBB', homeScore: 60, awayScore: 55),
        _game(home: 'AAA', away: 'CCC', homeScore: 50, awayScore: 90),
        _game(home: 'BBB', away: 'DDD', homeScore: 90, awayScore: 50),
      ], leagueTeams: _sameConferenceTeams);

      final aaaIndex = standings.indexWhere((e) => e.teamAbbreviation == 'AAA');
      final bbbIndex = standings.indexWhere((e) => e.teamAbbreviation == 'BBB');
      expect(aaaIndex, lessThan(bbbIndex));
    });

    test('falls back to conference record when there is no head-to-head '
        'history', () {
      final teams = [
        _team('AAA', Conference.atlantic),
        _team('BBB', Conference.pacific),
        _team('CCC', Conference.atlantic),
        _team('DDD', Conference.atlantic),
      ];
      final standings = computeStandings([
        // AAA and BBB never play each other, so head-to-head is a
        // no-op (neutral) -- conference record should decide instead.
        // AAA: 2-0 overall, both wins in-conference (perfect
        // in-conference record).
        _game(home: 'AAA', away: 'CCC', homeScore: 60, awayScore: 50),
        _game(home: 'AAA', away: 'DDD', homeScore: 60, awayScore: 50),
        // BBB: 2-0 overall too (same win percentage as AAA), but both
        // wins are against atlantic opponents -- BBB (pacific) never
        // plays a fellow pacific team, so its in-conference record is
        // an empty, neutral sample rather than a strong one.
        _game(home: 'BBB', away: 'CCC', homeScore: 60, awayScore: 50),
        _game(home: 'BBB', away: 'DDD', homeScore: 60, awayScore: 50),
      ], leagueTeams: teams);

      final aaaIndex = standings.indexWhere((e) => e.teamAbbreviation == 'AAA');
      final bbbIndex = standings.indexWhere((e) => e.teamAbbreviation == 'BBB');
      expect(aaaIndex, lessThan(bbbIndex));
    });

    test('falls back to point differential once head-to-head and '
        'conference record are both exactly even', () {
      final standings = computeStandings(
        [
          // AAA and BBB split their season series 1-1 (even head-to-head)
          // and never play a same-conference opponent (even, neutral
          // in-conference record) -- point differential should decide.
          _game(home: 'AAA', away: 'BBB', homeScore: 60, awayScore: 55),
          _game(home: 'BBB', away: 'AAA', homeScore: 70, awayScore: 50),
        ],
        leagueTeams: [
          _team('AAA', Conference.atlantic),
          _team('BBB', Conference.pacific),
        ],
      );

      // AAA: +60-55=+5, -50-70=-20 => total -15. BBB: -5, +20 => total +15.
      final aaaIndex = standings.indexWhere((e) => e.teamAbbreviation == 'AAA');
      final bbbIndex = standings.indexWhere((e) => e.teamAbbreviation == 'BBB');
      expect(bbbIndex, lessThan(aaaIndex));
    });
  });
}
