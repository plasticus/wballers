import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';

const _eightSeeds = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'];

Team _team(String abbreviation) => Team(
  abbreviation: abbreviation,
  location: abbreviation,
  name: abbreviation,
  conference: Conference.atlantic,
  colors: const TeamColors(
    primaryHex: '#000000',
    secondaryHex: '#111111',
    accentHex: '#222222',
  ),
  identityNote: '',
  emoji: '🏀',
);

final _leagueTeams = _eightSeeds.map(_team).toList();

/// A regular season fully played out among [_eightSeeds] -- every team
/// beats every team ranked below it, one game per week, so
/// `postseasonSeeds` always resolves to exactly [_eightSeeds] in that
/// order. [SeasonProgress.nextGameDayIndex] is already advanced past
/// every one of these game days, matching the real "regular season just
/// finished" state [growPostseasonSchedule] looks for.
SeasonProgress _regularSeasonComplete() {
  final games = <ScheduledGame>[];
  final played = <PlayedGame>[];
  var week = 1;
  for (var i = 0; i < _eightSeeds.length; i++) {
    for (var j = i + 1; j < _eightSeeds.length; j++) {
      final game = ScheduledGame(
        week: week,
        day: GameDay.sunday,
        homeTeamAbbreviation: _eightSeeds[i],
        awayTeamAbbreviation: _eightSeeds[j],
        type: GameType.regularSeason,
      );
      games.add(game);
      played.add(PlayedGame(game: game, homeScore: 80, awayScore: 70));
      week++;
    }
  }
  final schedule = SeasonSchedule(games: games);
  return SeasonProgress(
    schedule: schedule,
    playedGames: played,
    nextGameDayIndex: gameDaysInOrder(schedule).length,
  );
}

/// [_regularSeasonComplete] plus [extraGames] already folded into the
/// schedule/playedGames and [nextGameDayIndex] advanced past them too --
/// the shape `growPostseasonSchedule` expects once some postseason games
/// have already been played (it needs *today's* results already
/// reflected, same as `season_advancer.dart`'s own caller).
SeasonProgress _withPlayedPostseasonGames(List<PlayedGame> extraGames) {
  final base = _regularSeasonComplete();
  return SeasonProgress(
    schedule: base.schedule.copyWithAppendedGames([
      for (final g in extraGames) g.game,
    ]),
    playedGames: [...base.playedGames, ...extraGames],
    nextGameDayIndex: base.nextGameDayIndex + extraGames.length,
  );
}

PlayedGame _postseasonGame({
  required String home,
  required String away,
  required int round,
  required int week,
  required GameDay day,
  bool homeWins = true,
}) {
  return PlayedGame(
    game: ScheduledGame(
      week: week,
      day: day,
      homeTeamAbbreviation: home,
      awayTeamAbbreviation: away,
      type: GameType.postseason,
      postseasonRound: round,
    ),
    homeScore: homeWins ? 80 : 70,
    awayScore: homeWins ? 70 : 80,
  );
}

void main() {
  group('postseasonSeeds', () {
    test('takes the top 8 teams from standings, best record first', () {
      final teams = [for (var i = 0; i < 12; i++) 'T$i'];
      final standings = [
        for (var i = 0; i < teams.length; i++)
          StandingsEntry(
            teamAbbreviation: teams[i],
            wins: teams.length - i,
            losses: i,
            pointsFor: 0,
            pointsAgainst: 0,
          ),
      ];

      expect(postseasonSeeds(standings), teams.take(8).toList());
    });

    test('throws when fewer than 8 teams are in standings', () {
      expect(() => postseasonSeeds(const []), throwsA(isA<AssertionError>()));
    });
  });

  group('growPostseasonSchedule -- kicking off Round 1', () {
    test('nothing to add while the regular season still has game days '
        'left', () {
      final base = _regularSeasonComplete();
      final progress = SeasonProgress(
        schedule: base.schedule,
        playedGames: base.playedGames,
        // Not actually advanced through everything yet.
        nextGameDayIndex: base.nextGameDayIndex - 1,
      );

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      expect(additions, isEmpty);
    });

    test('schedules 4 Round 1 Game 1s in 1v8/2v7/3v6/4v5 bracket order, '
        'higher seed home, once the regular season is genuinely done', () {
      final progress = _regularSeasonComplete();

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      expect(additions.length, 4);
      for (final g in additions) {
        expect(g.type, GameType.postseason);
        expect(g.postseasonRound, 1);
        expect(g.week, kPostseasonFirstRoundWeek);
        expect(g.day, GameDay.sunday);
      }
      expect(additions[0].homeTeamAbbreviation, 'S1');
      expect(additions[0].awayTeamAbbreviation, 'S8');
      expect(additions[1].homeTeamAbbreviation, 'S2');
      expect(additions[1].awayTeamAbbreviation, 'S7');
      expect(additions[2].homeTeamAbbreviation, 'S3');
      expect(additions[2].awayTeamAbbreviation, 'S6');
      expect(additions[3].homeTeamAbbreviation, 'S4');
      expect(additions[3].awayTeamAbbreviation, 'S5');
    });
  });

  group('growPostseasonSchedule -- mid-series', () {
    test('schedules only the next game for a series still alive, at the '
        'right home/away split for its game count', () {
      // S1 leads S8 1-0 in the best-of-3 -- game 2 (index 1) is also
      // higher-seed-home per the pattern.
      final progress = _withPlayedPostseasonGames([
        _postseasonGame(
          home: 'S1',
          away: 'S8',
          round: 1,
          week: kPostseasonFirstRoundWeek,
          day: GameDay.sunday,
        ),
      ]);

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      // Every other First Round series hasn't even had a Game 1 yet --
      // they're all still "alive" too, so they all get scheduled
      // alongside S1-S8's game 2.
      expect(additions.length, 4);
      final s1Game = additions.firstWhere(
        (g) => {g.homeTeamAbbreviation, g.awayTeamAbbreviation}.contains('S1'),
      );
      expect(s1Game.homeTeamAbbreviation, 'S1');
      expect(s1Game.awayTeamAbbreviation, 'S8');
      // One slot past the existing game -- Tuesday of the same week.
      expect(s1Game.week, kPostseasonFirstRoundWeek);
      expect(s1Game.day, GameDay.tuesday);
    });

    test('a series that already clinched (2-0 in a best-of-3) gets no '
        'more games scheduled for it, while other alive series do', () {
      final progress = _withPlayedPostseasonGames([
        _postseasonGame(
          home: 'S1',
          away: 'S8',
          round: 1,
          week: kPostseasonFirstRoundWeek,
          day: GameDay.sunday,
        ),
        _postseasonGame(
          home: 'S1',
          away: 'S8',
          round: 1,
          week: kPostseasonFirstRoundWeek,
          day: GameDay.tuesday,
        ),
      ]);

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      expect(
        additions.any(
          (g) =>
              {g.homeTeamAbbreviation, g.awayTeamAbbreviation}.contains('S1'),
        ),
        isFalse,
      );
      // The other 3 First Round series are still alive.
      expect(additions.length, 3);
    });
  });

  group('growPostseasonSchedule -- round transitions', () {
    test('once every First Round series clinches, schedules the Semifinal '
        'Game 1s, winners crossed correctly', () {
      final progress = _withPlayedPostseasonGames([
        // Each First Round series clinched 2-0.
        for (final (home, away) in [
          ('S1', 'S8'),
          ('S2', 'S7'),
          ('S3', 'S6'),
          ('S4', 'S5'),
        ])
          for (final day in [GameDay.sunday, GameDay.tuesday])
            _postseasonGame(
              home: home,
              away: away,
              round: 1,
              week: kPostseasonFirstRoundWeek,
              day: day,
            ),
      ]);

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      expect(additions.length, 2);
      for (final g in additions) {
        expect(g.postseasonRound, 2);
      }
      // Game-0 winner (S1) meets game-3 winner (S4); game-1 winner (S2)
      // meets game-2 winner (S3) -- same bracket-crossing
      // `reconstructPostseasonBracket` already established.
      final pairing0 = {
        additions[0].homeTeamAbbreviation,
        additions[0].awayTeamAbbreviation,
      };
      final pairing1 = {
        additions[1].homeTeamAbbreviation,
        additions[1].awayTeamAbbreviation,
      };
      expect(pairing0, {'S1', 'S4'});
      expect(pairing1, {'S2', 'S3'});
      // Higher seed hosts Game 1.
      expect(additions[0].homeTeamAbbreviation, 'S1');
      expect(additions[1].homeTeamAbbreviation, 'S2');
    });

    test('returns an empty list once the Finals are decided -- nothing '
        'left to ever schedule', () {
      final progress = _withPlayedPostseasonGames([
        for (final (home, away) in [
          ('S1', 'S8'),
          ('S2', 'S7'),
          ('S3', 'S6'),
          ('S4', 'S5'),
        ])
          for (final day in [GameDay.sunday, GameDay.tuesday])
            _postseasonGame(
              home: home,
              away: away,
              round: 1,
              week: kPostseasonFirstRoundWeek,
              day: day,
            ),
        for (final (home, away) in [('S1', 'S4'), ('S2', 'S3')])
          for (final day in [GameDay.sunday, GameDay.tuesday, GameDay.thursday])
            _postseasonGame(
              home: home,
              away: away,
              round: 2,
              week: kPostseasonSemifinalsWeek,
              day: day,
            ),
        for (final day in [
          GameDay.sunday,
          GameDay.tuesday,
          GameDay.thursday,
          GameDay.sunday,
        ])
          _postseasonGame(
            home: 'S1',
            away: 'S2',
            round: 3,
            week: kPostseasonFinalsWeek,
            day: day,
          ),
      ]);

      final additions = growPostseasonSchedule(
        progress,
        leagueTeams: _leagueTeams,
      );

      expect(additions, isEmpty);
    });
  });

  group('seasonChampion', () {
    test('null when no Finals games exist yet', () {
      expect(seasonChampion(const []), isNull);
    });

    test('null on a mid-series Finals lead -- only an actual clinch (4 '
        'wins) counts', () {
      final playedGames = [
        _postseasonGame(
          home: 'A',
          away: 'B',
          round: 3,
          week: kPostseasonFinalsWeek,
          day: GameDay.sunday,
        ),
        _postseasonGame(
          home: 'A',
          away: 'B',
          round: 3,
          week: kPostseasonFinalsWeek,
          day: GameDay.tuesday,
        ),
      ];

      expect(seasonChampion(playedGames), isNull);
    });

    test('whichever team actually reaches 4 Finals wins', () {
      final playedGames = [
        for (final day in [
          GameDay.sunday,
          GameDay.tuesday,
          GameDay.thursday,
          GameDay.sunday,
        ])
          _postseasonGame(
            home: 'A',
            away: 'B',
            round: 3,
            week: kPostseasonFinalsWeek,
            day: day,
          ),
      ];

      expect(seasonChampion(playedGames), 'A');
    });

    test('ignores non-Finals games entirely', () {
      final playedGames = [
        _postseasonGame(
          home: 'B',
          away: 'A',
          round: 1,
          week: kPostseasonFirstRoundWeek,
          day: GameDay.sunday,
        ),
      ];

      expect(seasonChampion(playedGames), isNull);
    });
  });
}
