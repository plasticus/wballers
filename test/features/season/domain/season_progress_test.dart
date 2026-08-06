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
  );
}

ScheduledGame _game(
  String home,
  String away, {
  int week = 2,
  GameDay day = GameDay.sunday,
}) {
  return ScheduledGame(
    week: week,
    day: day,
    homeTeamAbbreviation: home,
    awayTeamAbbreviation: away,
    type: GameType.regularSeason,
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
}
