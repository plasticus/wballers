import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';

import '../../../support/match_test_players.dart';

const _schedule = SeasonSchedule(
  games: [
    ScheduledGame(
      week: 2,
      homeTeamAbbreviation: 'AAA',
      awayTeamAbbreviation: 'BBB',
      type: GameType.regularSeason,
    ),
    ScheduledGame(
      week: 2,
      homeTeamAbbreviation: 'CCC',
      awayTeamAbbreviation: 'DDD',
      type: GameType.regularSeason,
    ),
    // Week 3 is deliberately empty (a bye week) to prove that's handled.
    ScheduledGame(
      week: 4,
      homeTeamAbbreviation: 'AAA',
      awayTeamAbbreviation: 'CCC',
      type: GameType.regularSeason,
    ),
  ],
);

void main() {
  test('simulates every game scheduled for nextWeek and advances the '
      'pointer by one', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextWeek: 2,
    );

    final updated = advanceOneWeek(
      Random(1),
      progress,
      rostersByAbbreviation: rosters,
    );

    expect(updated.playedGames.length, 2);
    expect(updated.nextWeek, 3);
    expect(updated.playedGames.map((p) => p.game.week).toSet(), {2});
  });

  test('a week with nothing scheduled just advances the pointer', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextWeek: 3,
    );

    final updated = advanceOneWeek(
      Random(1),
      progress,
      rostersByAbbreviation: rosters,
    );

    expect(updated.playedGames, isEmpty);
    expect(updated.nextWeek, 4);
  });

  test('is deterministic for a given seed', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    const progress = SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextWeek: 2,
    );

    final a = advanceOneWeek(
      Random(7),
      progress,
      rostersByAbbreviation: rosters,
    );
    final b = advanceOneWeek(
      Random(7),
      progress,
      rostersByAbbreviation: rosters,
    );

    for (var i = 0; i < a.playedGames.length; i++) {
      expect(a.playedGames[i].homeScore, b.playedGames[i].homeScore);
      expect(a.playedGames[i].awayScore, b.playedGames[i].awayScore);
    }
  });

  test('repeated calls progress through subsequent weeks', () {
    final rosters = {
      for (final abbr in ['AAA', 'BBB', 'CCC', 'DDD']) abbr: testRoster(abbr),
    };
    var progress = const SeasonProgress(
      schedule: _schedule,
      playedGames: [],
      nextWeek: 2,
    );
    final random = Random(3);

    // Week 2 (2 games) -> week 3 (bye) -> week 4 (1 game).
    progress = advanceOneWeek(random, progress, rostersByAbbreviation: rosters);
    progress = advanceOneWeek(random, progress, rostersByAbbreviation: rosters);
    progress = advanceOneWeek(random, progress, rostersByAbbreviation: rosters);

    expect(progress.nextWeek, 5);
    expect(progress.playedGames.length, 3);
  });
}
