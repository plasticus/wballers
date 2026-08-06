import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';

ScheduledGame _game() {
  return const ScheduledGame(
    week: 2,
    day: GameDay.thursday,
    homeTeamAbbreviation: 'AAA',
    awayTeamAbbreviation: 'BBB',
    type: GameType.regularSeason,
  );
}

void main() {
  test('rejects a tied score', () {
    expect(
      () => PlayedGame(game: _game(), homeScore: 80, awayScore: 80),
      throwsA(isA<AssertionError>()),
    );
  });

  test('winningTeamAbbreviation/losingTeamAbbreviation reflect who scored '
      'more', () {
    final homeWon = PlayedGame(game: _game(), homeScore: 90, awayScore: 80);
    expect(homeWon.winningTeamAbbreviation, 'AAA');
    expect(homeWon.losingTeamAbbreviation, 'BBB');

    final awayWon = PlayedGame(game: _game(), homeScore: 70, awayScore: 85);
    expect(awayWon.winningTeamAbbreviation, 'BBB');
    expect(awayWon.losingTeamAbbreviation, 'AAA');
  });

  test('toGameResult carries the same score and fixture through', () {
    final played = PlayedGame(game: _game(), homeScore: 90, awayScore: 80);

    final result = played.toGameResult();

    expect(result.game, played.game);
    expect(result.match.homeScore, 90);
    expect(result.match.awayScore, 80);
    expect(result.winningTeamAbbreviation, 'AAA');
  });
}
