import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
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

ScheduledGame _game(String home, String away) {
  return ScheduledGame(
    week: 2,
    homeTeamAbbreviation: home,
    awayTeamAbbreviation: away,
    type: GameType.regularSeason,
  );
}

void main() {
  test('copyWithWeekPlayed appends games and advances nextWeek by one', () {
    const progress = SeasonProgress(
      schedule: SeasonSchedule(games: []),
      playedGames: [],
      nextWeek: 2,
    );

    final updated = progress.copyWithWeekPlayed([
      PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
    ]);

    expect(updated.playedGames.length, 1);
    expect(updated.nextWeek, 3);
    // Original is untouched.
    expect(progress.playedGames, isEmpty);
    expect(progress.nextWeek, 2);
  });

  test('copyWithWeekPlayed accumulates across repeated calls', () {
    const progress = SeasonProgress(
      schedule: SeasonSchedule(games: []),
      playedGames: [],
      nextWeek: 2,
    );

    final afterWeek2 = progress.copyWithWeekPlayed([
      PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
    ]);
    final afterWeek3 = afterWeek2.copyWithWeekPlayed([
      PlayedGame(game: _game('CCC', 'DDD'), homeScore: 70, awayScore: 60),
    ]);

    expect(afterWeek3.playedGames.length, 2);
    expect(afterWeek3.nextWeek, 4);
  });

  test('currentStandings derives a real table from playedGames', () {
    final progress = SeasonProgress(
      schedule: const SeasonSchedule(games: []),
      playedGames: [
        // AAA wins both -- once at home, once on the road.
        PlayedGame(game: _game('AAA', 'BBB'), homeScore: 90, awayScore: 80),
        PlayedGame(game: _game('BBB', 'AAA'), homeScore: 60, awayScore: 70),
      ],
      nextWeek: 4,
    );

    final standings = currentStandings(progress, [_team('AAA'), _team('BBB')]);

    final aaa = standings.firstWhere((e) => e.teamAbbreviation == 'AAA');
    expect(aaa.wins, 2);
    expect(aaa.losses, 0);
  });
}
