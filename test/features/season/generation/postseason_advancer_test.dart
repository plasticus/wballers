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

  test('ownTeamAbbreviation makes that team\'s target minutes follow bench '
      'order instead of the automatic overall-based ranking', () {
    final abbreviations = _teamAbbreviations();
    final progress = _completedRegularSeason(abbreviations);
    // T00 is always seed 1 (undefeated in _completedRegularSeason) and
    // so is guaranteed at least one postseason game. Reversed relative
    // to testRoster's natural descending-overall order, so list
    // position 0 is the worst player on the roster.
    final rosters = <String, List<Player>>{
      'T00': testRoster('T00').reversed.toList(),
      for (final abbr in abbreviations.skip(1)) abbr: testRoster(abbr),
    };

    final advance = simulatePostseason(
      Random(3),
      progress,
      leagueTeams: _leagueTeams(abbreviations),
      rostersByAbbreviation: rosters,
      ownTeamAbbreviation: 'T00',
    );

    final ownRoster = rosters['T00']!;
    final topBenchOrderPlayer = ownRoster.first; // worst overall
    final bottomBenchOrderPlayer = ownRoster.last; // best overall
    final ownGame = advance.gamesPlayed.firstWhere(
      (result) =>
          result.game.homeTeamAbbreviation == 'T00' ||
          result.game.awayTeamAbbreviation == 'T00',
    );
    expect(
      ownGame.match.minutesPlayed[topBenchOrderPlayer]!,
      greaterThan(ownGame.match.minutesPlayed[bottomBenchOrderPlayer]!),
    );
  });

  test('reconstructPostseasonBracket rebuilds the exact bracket '
      'simulatePostseason produced', () {
    final abbreviations = _teamAbbreviations();
    final progress = _completedRegularSeason(abbreviations);
    final rosters = <String, List<Player>>{
      for (final abbr in abbreviations) abbr: testRoster(abbr),
    };
    final leagueTeams = _leagueTeams(abbreviations);

    final advance = simulatePostseason(
      Random(3),
      progress,
      leagueTeams: leagueTeams,
      rostersByAbbreviation: rosters,
    );

    final bracket = reconstructPostseasonBracket(
      advance.progress,
      leagueTeams: leagueTeams,
    );

    expect(bracket, isNotNull);
    expect(bracket!.length, 3);
    expect(bracket[0], hasLength(4)); // First Round: 4 series
    expect(bracket[1], hasLength(2)); // Semifinals: 2 series
    expect(bracket[2], hasLength(1)); // Finals: 1 series

    for (final round in bracket) {
      for (final series in round) {
        expect(series.winnerAbbreviation, isNotNull);
      }
    }
    expect(
      bracket[2].single.winnerAbbreviation,
      seasonChampion(advance.progress.playedGames),
    );

    // Round 1's pairing is the standard 1v8/2v7/3v6/4v5 bracket shape.
    final seeds = postseasonSeeds(
      currentStandings(advance.progress, leagueTeams),
    );
    expect(bracket[0][0].higherSeedAbbreviation, seeds[0]);
    expect(bracket[0][0].lowerSeedAbbreviation, seeds[7]);
    expect(bracket[0][3].higherSeedAbbreviation, seeds[3]);
    expect(bracket[0][3].lowerSeedAbbreviation, seeds[4]);
  });

  test('reconstructPostseasonBracket previews Round 1 pairings before any '
      'series is played, and leaves later rounds empty', () {
    final abbreviations = _teamAbbreviations();
    final progress = _completedRegularSeason(abbreviations);
    final leagueTeams = _leagueTeams(abbreviations);

    final bracket = reconstructPostseasonBracket(
      progress,
      leagueTeams: leagueTeams,
    );

    expect(bracket, isNotNull);
    expect(bracket![0], hasLength(4));
    for (final series in bracket[0]) {
      expect(series.games, isEmpty);
      expect(series.winnerAbbreviation, isNull);
    }
    // Nothing to seed yet for Semifinals/Finals until Round 1 has
    // decided winners.
    expect(bracket[1], isEmpty);
    expect(bracket[2], isEmpty);
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
