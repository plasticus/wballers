import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';

import '../../../support/match_test_players.dart';

// Week 2 has 2 game days (Sunday: AAA-BBB, Thursday: CCC-DDD). Week 3 is
// deliberately empty (a bye week). Week 4 has one game day.
const _schedule = SeasonSchedule(
  games: [
    ScheduledGame(
      week: 2,
      day: GameDay.sunday,
      homeTeamAbbreviation: 'AAA',
      awayTeamAbbreviation: 'BBB',
      type: GameType.regularSeason,
    ),
    ScheduledGame(
      week: 2,
      day: GameDay.thursday,
      homeTeamAbbreviation: 'CCC',
      awayTeamAbbreviation: 'DDD',
      type: GameType.regularSeason,
    ),
    ScheduledGame(
      week: 4,
      day: GameDay.sunday,
      homeTeamAbbreviation: 'AAA',
      awayTeamAbbreviation: 'CCC',
      type: GameType.regularSeason,
    ),
  ],
);

void main() {
  test('simulates every game scheduled for the next game day and advances '
      'the pointer by one', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextGameDayIndex: 0,
    );

    final result = advanceToNextGameDay(
      Random(1),
      progress,
      rostersByAbbreviation: rosters,
    );

    // Only the Sunday slate (week 2) played -- the Thursday slate of the
    // same week is a separate, later game day.
    expect(result.progress.playedGames.length, 1);
    expect(result.progress.nextGameDayIndex, 1);
    expect(result.progress.playedGames.single.game.day, GameDay.sunday);
    expect(result.gamesPlayed.length, 1);
    expect(result.gamesPlayed.single.game.day, GameDay.sunday);
  });

  test('a bye week never gets its own game day -- there is nothing to '
      'advance to that skips a slate', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    // Index 2 is week 4's game day, right after week 2's 2 game days --
    // week 3's bye never appears in gameDaysInOrder at all.
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextGameDayIndex: 2,
    );

    final result = advanceToNextGameDay(
      Random(1),
      progress,
      rostersByAbbreviation: rosters,
    );

    expect(result.progress.playedGames.length, 1);
    expect(result.progress.playedGames.single.game.week, 4);
    expect(result.progress.nextGameDayIndex, 3);
    expect(result.progress.isComplete, isTrue);
  });

  test('is deterministic for a given seed', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextGameDayIndex: 0,
    );

    final a = advanceToNextGameDay(
      Random(7),
      progress,
      rostersByAbbreviation: rosters,
    );
    final b = advanceToNextGameDay(
      Random(7),
      progress,
      rostersByAbbreviation: rosters,
    );

    for (var i = 0; i < a.progress.playedGames.length; i++) {
      expect(
        a.progress.playedGames[i].homeScore,
        b.progress.playedGames[i].homeScore,
      );
      expect(
        a.progress.playedGames[i].awayScore,
        b.progress.playedGames[i].awayScore,
      );
    }
  });

  test('repeated calls progress through every game day, then the season '
      'is complete', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    var progress = const SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextGameDayIndex: 0,
    );
    final random = Random(3);

    // Sunday (week 2, 1 game) -> Thursday (week 2, 1 game) -> Sunday
    // (week 4, 1 game). 3 game days total, no bye-week entries.
    progress = advanceToNextGameDay(
      random,
      progress,
      rostersByAbbreviation: rosters,
    ).progress;
    progress = advanceToNextGameDay(
      random,
      progress,
      rostersByAbbreviation: rosters,
    ).progress;
    progress = advanceToNextGameDay(
      random,
      progress,
      rostersByAbbreviation: rosters,
    ).progress;

    expect(progress.nextGameDayIndex, 3);
    expect(progress.playedGames.length, 3);
    expect(progress.isComplete, isTrue);
  });

  group('Continental Cup round-chaining', () {
    List<String> teamAbbreviations() => [
      for (var i = 0; i < 20; i++) 'T${i.toString().padLeft(2, '0')}',
    ];

    SeasonSchedule round1Schedule(List<String> abbreviations) {
      return SeasonSchedule(
        games: [
          for (var i = 0; i < abbreviations.length; i += 2)
            ScheduledGame(
              week: 4,
              day: GameDay.thursday,
              homeTeamAbbreviation: abbreviations[i],
              awayTeamAbbreviation: abbreviations[i + 1],
              type: GameType.continentalCup,
              continentalCupRound: 1,
            ),
        ],
      );
    }

    test('finishing Round 1 generates Round 2, with byes recorded', () {
      final abbreviations = teamAbbreviations();
      final rosters = {
        for (final abbr in abbreviations) abbr: testRoster(abbr),
      };
      var progress = SeasonProgress(
        schedule: round1Schedule(abbreviations),
        playedGames: const [],
        nextGameDayIndex: 0,
      );

      final result = advanceToNextGameDay(
        Random(2),
        progress,
        rostersByAbbreviation: rosters,
      );
      progress = result.progress;

      expect(result.gamesPlayed.length, 10);
      final round2Games = progress.schedule.games.where(
        (g) => g.continentalCupRound == 2,
      );
      expect(round2Games.length, 2);
      expect(progress.schedule.continentalCupRound1Byes, hasLength(6));
      // The 4 teams playing Round 2 are exactly the ones not on the bye
      // list.
      final round2Teams = {
        for (final g in round2Games) ...[
          g.homeTeamAbbreviation,
          g.awayTeamAbbreviation,
        ],
      };
      expect(
        round2Teams.intersection(
          progress.schedule.continentalCupRound1Byes!.toSet(),
        ),
        isEmpty,
      );
    });

    test('advancing through every round resolves to a single champion', () {
      final abbreviations = teamAbbreviations();
      final rosters = {
        for (final abbr in abbreviations) abbr: testRoster(abbr),
      };
      var progress = SeasonProgress(
        schedule: round1Schedule(abbreviations),
        playedGames: const [],
        nextGameDayIndex: 0,
      );
      final random = Random(9);

      var iterations = 0;
      while (!progress.isComplete && iterations < 10) {
        progress = advanceToNextGameDay(
          random,
          progress,
          rostersByAbbreviation: rosters,
        ).progress;
        iterations++;
      }

      final gamesByRound = <int, int>{};
      for (final played in progress.playedGames) {
        final round = played.game.continentalCupRound!;
        gamesByRound[round] = (gamesByRound[round] ?? 0) + 1;
      }
      expect(gamesByRound, {1: 10, 2: 2, 3: 4, 4: 2, 5: 1});
      expect(progress.isComplete, isTrue);

      // Nothing generated past the championship.
      expect(
        progress.schedule.games.any((g) => g.continentalCupRound == 6),
        isFalse,
      );
    });
  });
}
