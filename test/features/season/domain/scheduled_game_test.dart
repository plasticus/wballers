import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';

void main() {
  test('rejects a team playing itself', () {
    expect(
      () => ScheduledGame(
        week: 2,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BOS',
        type: GameType.regularSeason,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a continentalCupRound on a non-cup game', () {
    expect(
      () => ScheduledGame(
        week: 2,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.regularSeason,
        continentalCupRound: 1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a missing continentalCupRound on a cup game', () {
    expect(
      () => ScheduledGame(
        week: 4,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.continentalCup,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('accepts a well-formed cup game', () {
    expect(
      () => ScheduledGame(
        week: 4,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.continentalCup,
        continentalCupRound: 1,
      ),
      returnsNormally,
    );
  });

  test('rejects a postseasonRound on a non-postseason game', () {
    expect(
      () => ScheduledGame(
        week: 2,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.regularSeason,
        postseasonRound: 1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a missing postseasonRound on a postseason game', () {
    expect(
      () => ScheduledGame(
        week: 20,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.postseason,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('accepts a well-formed postseason game', () {
    expect(
      () => ScheduledGame(
        week: 20,
        day: GameDay.thursday,
        homeTeamAbbreviation: 'BOS',
        awayTeamAbbreviation: 'BKN',
        type: GameType.postseason,
        postseasonRound: 1,
      ),
      returnsNormally,
    );
  });
}
