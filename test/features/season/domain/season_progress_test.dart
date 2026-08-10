import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';

const _dummyColors = TeamColors(
  primaryHex: '#000000',
  secondaryHex: '#111111',
  accentHex: '#222222',
);

Team _team(String abbreviation) {
  return Team(
    abbreviation: abbreviation,
    location: 'Testville',
    name: abbreviation,
    conference: Conference.atlantic,
    colors: _dummyColors,
    identityNote: '',
    emoji: '🏀',
  );
}

ScheduledGame _game(
  String home,
  String away, {
  int week = 2,
  GameDay day = GameDay.sunday,
  GameType type = GameType.regularSeason,
  int? continentalCupRound,
}) {
  return ScheduledGame(
    week: week,
    day: day,
    homeTeamAbbreviation: home,
    awayTeamAbbreviation: away,
    type: type,
    continentalCupRound: continentalCupRound,
  );
}

void main() {
  test('copyWithGameDayPlayed appends games and advances '
      'nextGameDayIndex by one', () {
    const progress = SeasonProgress(
      schedule: SeasonSchedule(games: []),
      playedGames: [],
      nextGameDayIndex: 0,
    );

    final updated = progress.copyWithGameDayPlayed([
      PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
    ]);

    expect(updated.playedGames.length, 1);
    expect(updated.nextGameDayIndex, 1);
    // Original is untouched.
    expect(progress.playedGames, isEmpty);
    expect(progress.nextGameDayIndex, 0);
  });

  test('copyWithGameDayPlayed accumulates across repeated calls', () {
    const progress = SeasonProgress(
      schedule: SeasonSchedule(games: []),
      playedGames: [],
      nextGameDayIndex: 0,
    );

    final afterFirst = progress.copyWithGameDayPlayed([
      PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
    ]);
    final afterSecond = afterFirst.copyWithGameDayPlayed([
      PlayedGame(game: _game('CCC', 'DDD'), homeScore: 70, awayScore: 60),
    ]);

    expect(afterSecond.playedGames.length, 2);
    expect(afterSecond.nextGameDayIndex, 2);
  });

  test('currentStandings derives a real table from playedGames', () {
    final progress = SeasonProgress(
      schedule: const SeasonSchedule(games: []),
      playedGames: [
        // AAA wins both -- once at home, once on the road.
        PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
        PlayedGame(game: _game('BBB', 'AAA'), homeScore: 60, awayScore: 70),
      ],
      nextGameDayIndex: 2,
    );

    final standings = currentStandings(progress, [_team('AAA'), _team('BBB')]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    expect(aaa.wins, 2);
    expect(aaa.losses, 0);
  });

  group('gameDaysInOrder', () {
    test('lists only distinct (week, day) pairs that actually have a '
        'game, in chronological order', () {
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 3, day: GameDay.thursday),
          _game('CCC', 'DDD', week: 2, day: GameDay.sunday),
          // Same (week, day) as the first game, from another matchup --
          // should collapse to one entry, not two.
          _game('EEE', 'FFF', week: 3, day: GameDay.thursday),
          _game('AAA', 'CCC', week: 2, day: GameDay.thursday),
        ],
      );

      expect(gameDaysInOrder(schedule), [
        (2, GameDay.sunday),
        (2, GameDay.thursday),
        (3, GameDay.thursday),
      ]);
    });
  });

  group('isComplete', () {
    test('is false while game days remain', () {
      final schedule = SeasonSchedule(games: [_game('AAA', 'BBB')]);
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );
      expect(progress.isComplete, isFalse);
    });

    test('is true once every game day has been consumed', () {
      final schedule = SeasonSchedule(games: [_game('AAA', 'BBB')]);
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 1,
      );
      expect(progress.isComplete, isTrue);
    });
  });

  group('lastFullyCompletedWeek', () {
    test('null when nothing has been played yet', () {
      final schedule = SeasonSchedule(
        games: [_game('AAA', 'BBB', week: 2, day: GameDay.sunday)],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );
      expect(lastFullyCompletedWeek(progress), isNull);
    });

    test('null while a week\'s later game day still hasn\'t been played', () {
      // Week 2 has two game days -- only the first has been played.
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 2, day: GameDay.sunday),
          _game('CCC', 'DDD', week: 2, day: GameDay.thursday),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 1,
      );
      expect(lastFullyCompletedWeek(progress), isNull);
    });

    test('returns the week once every one of its game days is played', () {
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 2, day: GameDay.sunday),
          _game('CCC', 'DDD', week: 2, day: GameDay.thursday),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 2,
      );
      expect(lastFullyCompletedWeek(progress), 2);
    });

    test('advances to the next week once that one starts filling in too', () {
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 2, day: GameDay.sunday),
          _game('CCC', 'DDD', week: 3, day: GameDay.sunday),
        ],
      );
      // Week 2's one game day is done; week 3's has started but the
      // pointer hasn't reached it yet, so week 2 is the last complete one.
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 1,
      );
      expect(lastFullyCompletedWeek(progress), 2);
    });
  });

  group('nextOwnGame', () {
    test('the team\'s game on the very next game day, if they have one', () {
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 2, day: GameDay.sunday),
          _game('CCC', 'DDD', week: 2, day: GameDay.sunday),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      expect(nextOwnGame(progress, 'AAA')?.awayTeamAbbreviation, 'BBB');
      // Home or away, either side of the fixture matches.
      expect(nextOwnGame(progress, 'DDD')?.homeTeamAbbreviation, 'CCC');
    });

    test('null on a bye day -- the next game day has games, just none for '
        'this team', () {
      const schedule = SeasonSchedule(games: []);
      final progressWithByeDay = SeasonProgress(
        schedule: SeasonSchedule(
          games: [_game('CCC', 'DDD', week: 2, day: GameDay.sunday)],
        ),
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      expect(nextOwnGame(progressWithByeDay, 'AAA'), isNull);
      // Sanity: an empty schedule (no game days at all) is also null, not
      // a crash.
      expect(
        nextOwnGame(
          SeasonProgress(
            schedule: schedule,
            playedGames: const [],
            nextGameDayIndex: 0,
          ),
          'AAA',
        ),
        isNull,
      );
    });

    test('null once the season is fully played out', () {
      final schedule = SeasonSchedule(
        games: [_game('AAA', 'BBB', week: 2, day: GameDay.sunday)],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: gameDaysInOrder(schedule).length,
      );

      expect(nextOwnGame(progress, 'AAA'), isNull);
    });

    test('only looks at the very next game day, not later ones', () {
      final schedule = SeasonSchedule(
        games: [
          _game('CCC', 'DDD', week: 2, day: GameDay.sunday),
          _game('AAA', 'BBB', week: 3, day: GameDay.sunday),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      // AAA does play later this season, just not on the next game day.
      expect(nextOwnGame(progress, 'AAA'), isNull);
    });
  });

  group('nextGameDayTypes (TODO.md item 12)', () {
    test('the game type(s) scheduled on the very next game day', () {
      final schedule = SeasonSchedule(
        games: [_game('AAA', 'BBB', week: 2, day: GameDay.sunday)],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      expect(nextGameDayTypes(progress), {GameType.regularSeason});
    });

    test('reports Continental Cup even when the GM\'s own team has no game '
        'that day -- the rest of the league is still playing', () {
      final schedule = SeasonSchedule(
        games: [
          _game(
            'CCC',
            'DDD',
            week: 4,
            day: GameDay.thursday,
            type: GameType.continentalCup,
            continentalCupRound: 1,
          ),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      expect(nextGameDayTypes(progress), {GameType.continentalCup});
    });

    test('can report more than one type on a day where the calendar '
        'overlaps', () {
      final schedule = SeasonSchedule(
        games: [
          _game('AAA', 'BBB', week: 4, day: GameDay.thursday),
          _game(
            'CCC',
            'DDD',
            week: 4,
            day: GameDay.thursday,
            type: GameType.continentalCup,
            continentalCupRound: 1,
          ),
        ],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      expect(nextGameDayTypes(progress), {
        GameType.regularSeason,
        GameType.continentalCup,
      });
    });

    test('empty once the season is fully played out', () {
      final schedule = SeasonSchedule(
        games: [_game('AAA', 'BBB', week: 2, day: GameDay.sunday)],
      );
      final progress = SeasonProgress(
        schedule: schedule,
        playedGames: const [],
        nextGameDayIndex: gameDaysInOrder(schedule).length,
      );

      expect(nextGameDayTypes(progress), isEmpty);
    });
  });
}
