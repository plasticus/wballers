import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/postseason_advancer.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';

import '../../../support/match_test_players.dart';

const _dummyColors = TeamColors(
  primaryHex: '#000000',
  secondaryHex: '#111111',
  accentHex: '#222222',
);

List<String> _teamAbbreviations() => [
  for (var i = 0; i < 10; i++) 'T${i.toString().padLeft(2, '0')}',
];

List<Team> _leagueTeams(List<String> abbreviations) {
  return [
    for (final abbr in abbreviations)
      Team(
        abbreviation: abbr,
        location: 'Testville',
        name: abbr,
        conference: Conference.atlantic,
        colors: _dummyColors,
        identityNote: '',
        emoji: '🏀',
      ),
  ];
}

/// A finished "regular season": each team plays every other team once,
/// with a fixed higher-index-always-wins outcome -- enough for a clear,
/// deterministic standings order with more than the 8 teams
/// [postseasonSeeds] needs.
SeasonProgress _completedRegularSeason(List<String> abbreviations) {
  final playedGames = <PlayedGame>[];
  for (var i = 0; i < abbreviations.length; i++) {
    for (var j = i + 1; j < abbreviations.length; j++) {
      // Lower index (better standing) always wins, at home.
      playedGames.add(
        PlayedGame(
          game: ScheduledGame(
            week: 2,
            day: GameDay.sunday,
            homeTeamAbbreviation: abbreviations[i],
            awayTeamAbbreviation: abbreviations[j],
            type: GameType.regularSeason,
          ),
          homeScore: 80,
          awayScore: 60,
        ),
      );
    }
  }
  return SeasonProgress(
    schedule: SeasonSchedule(games: [for (final p in playedGames) p.game]),
    playedGames: playedGames,
    nextGameDayIndex: 999, // irrelevant here -- isComplete isn't consulted.
  );
}

void main() {
  test('seeds and simulates the full bracket, resolving to a champion', () {
    final abbreviations = _teamAbbreviations();
    final progress = _completedRegularSeason(abbreviations);
    final rosters = <String, List<Player>>{
      for (final abbr in abbreviations) abbr: testRoster(abbr),
    };

    final advance = simulatePostseason(
      Random(3),
      progress,
      leagueTeams: _leagueTeams(abbreviations),
      rostersByAbbreviation: rosters,
    );

    expect(advance.gamesPlayed, isNotEmpty);
    final byRound = <int, int>{};
    for (final result in advance.gamesPlayed) {
      final round = result.game.postseasonRound!;
      byRound[round] = (byRound[round] ?? 0) + 1;
    }
    // First Round (best-of-3, 4 series) -> Semifinals (best-of-5, 2
    // series) -> Finals (best-of-7, 1 series) -- each series plays at
    // least its minimum win count in games.
    expect(byRound[1], greaterThanOrEqualTo(8));
    expect(byRound[2], greaterThanOrEqualTo(4));
    expect(byRound[3], greaterThanOrEqualTo(2));

    final champion = seasonChampion(advance.progress.playedGames);
    expect(champion, isNotNull);

    // The updated progress is fully "consumed" -- nothing left to
    // advance to via the day-by-day path.
    expect(advance.progress.isComplete, isTrue);
  });

  test('is idempotent -- calling again on an already-played postseason '
      'is a no-op', () {
    final abbreviations = _teamAbbreviations();
    final progress = _completedRegularSeason(abbreviations);
    final rosters = <String, List<Player>>{
      for (final abbr in abbreviations) abbr: testRoster(abbr),
    };

    final first = simulatePostseason(
      Random(3),
      progress,
      leagueTeams: _leagueTeams(abbreviations),
      rostersByAbbreviation: rosters,
    );
    final second = simulatePostseason(
      Random(3),
      first.progress,
      leagueTeams: _leagueTeams(abbreviations),
      rostersByAbbreviation: rosters,
    );

    expect(second.gamesPlayed, isEmpty);
    expect(
      second.progress.playedGames.length,
      first.progress.playedGames.length,
    );
  });
}
