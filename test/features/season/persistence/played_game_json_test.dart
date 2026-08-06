import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/played_game_stat_line.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/persistence/played_game_json.dart';

void main() {
  test('round-trips minutes and box score maps, keyed by player id', () {
    final played = PlayedGame(
      game: const ScheduledGame(
        week: 2,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'AAA',
        awayTeamAbbreviation: 'BBB',
        type: GameType.regularSeason,
      ),
      homeScore: 90,
      awayScore: 80,
      minutesByPlayerId: const {'p1': 32.5},
      boxScoreByPlayerId: const {
        'p1': PlayedGameStatLine(
          minutesPlayed: 32.5,
          points: 22,
          fieldGoalsMade: 8,
          fieldGoalAttempts: 15,
          threePointersMade: 2,
          threePointAttempts: 5,
          freeThrowsMade: 4,
          freeThrowAttempts: 5,
          offensiveRebounds: 1,
          defensiveRebounds: 5,
          assists: 3,
          steals: 2,
          blocks: 1,
          turnovers: 2,
          personalFouls: 3,
        ),
      },
    );

    final restored = playedGameFromJson(playedGameToJson(played));

    expect(restored.homeScore, 90);
    expect(restored.awayScore, 80);
    expect(restored.minutesByPlayerId, {'p1': 32.5});
    final line = restored.boxScoreByPlayerId['p1']!;
    expect(line.points, 22);
    expect(line.fieldGoalsMade, 8);
    expect(line.fieldGoalAttempts, 15);
    expect(line.threePointersMade, 2);
    expect(line.assists, 3);
    expect(line.steals, 2);
    expect(line.blocks, 1);
    expect(line.turnovers, 2);
    expect(line.personalFouls, 3);
    expect(line.totalRebounds, 6);
  });

  test('defaults boxScoreByPlayerId to empty when absent from older JSON', () {
    final json = {
      'game': {
        'week': 2,
        'day': 'thursday',
        'homeTeamAbbreviation': 'AAA',
        'awayTeamAbbreviation': 'BBB',
        'type': 'regularSeason',
      },
      'homeScore': 90,
      'awayScore': 80,
    };

    final restored = playedGameFromJson(json);

    expect(restored.minutesByPlayerId, isEmpty);
    expect(restored.boxScoreByPlayerId, isEmpty);
  });
}
