import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/played_game_stat_line.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_awards_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

PlayedGameStatLine _line({
  double minutesPlayed = 25,
  int points = 0,
  int rebounds = 0,
  int assists = 0,
  int steals = 0,
  int blocks = 0,
}) {
  return PlayedGameStatLine(
    minutesPlayed: minutesPlayed,
    points: points,
    fieldGoalsMade: 0,
    fieldGoalAttempts: 0,
    threePointersMade: 0,
    threePointAttempts: 0,
    freeThrowsMade: 0,
    freeThrowAttempts: 0,
    offensiveRebounds: rebounds,
    defensiveRebounds: 0,
    assists: assists,
    steals: steals,
    blocks: blocks,
    turnovers: 0,
    personalFouls: 0,
  );
}

RosterMembership _active(String id, {int overall = 60, int years = 5}) {
  return RosterMembership(
    player: playerWithOverall(
      overall,
      id: id,
      name: 'Player $id',
      yearsOfService: years,
    ),
    status: RosterStatus.active,
  );
}

/// A team's 6 active players, named "$idPrefix1".."$idPrefix6" -- the
/// caller supplies each one's actual box-score line (minutes/stats)
/// separately; this just gets 6 real roster slots in place so
/// `rostersByAbbreviation` has a full active roster to rank by minutes.
List<RosterMembership> _sixPlayerActiveRoster(String idPrefix) {
  return [
    for (var i = 1; i <= 6; i++)
      RosterMembership(
        player: playerWithOverall(
          60,
          id: '$idPrefix$i',
          name: 'Player $idPrefix$i',
        ),
        status: RosterStatus.active,
      ),
  ];
}

void main() {
  group('resolveSeasonAwards', () {
    test('returns the franchise unchanged, no winners, when no games have '
        'been played yet', () {
      final franchise = _baseFranchise(ownRoster: [_active('A')]);

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners, isEmpty);
      expect(result.franchise, same(franchise));
    });

    test('League MVP and Scoring Leader can go to different players -- '
        'the highest total-points scorer isn\'t always the highest '
        'composite', () {
      final a = _active('A', overall: 70); // high points, nothing else
      final b = _active('B', overall: 70); // balanced composite, fewer pts
      final game = _game({
        'A': _line(points: 30),
        'B': _line(points: 20, rebounds: 10, assists: 8, steals: 3, blocks: 2),
      });
      final franchise = _baseFranchise(ownRoster: [a, b], playedGames: [game]);

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners[Achievement.leagueMvp], 'B');
      expect(result.winners[Achievement.scoringLeader], 'A');
    });

    test('Defensive MVP goes to the best steals+blocks composite, '
        'independent of the other awards', () {
      final a = _active('A');
      final c = _active('C'); // steals+blocks specialist
      final game = _game({
        'A': _line(points: 30),
        'C': _line(points: 5, steals: 8, blocks: 6),
      });
      final franchise = _baseFranchise(ownRoster: [a, c], playedGames: [game]);

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners[Achievement.defensiveMvp], 'C');
    });

    test('Sixth Man of the Year compares each team\'s own #6-by-minutes '
        'player across the whole league, not just within one team', () {
      final teamOneRoster = _sixPlayerActiveRoster('D');
      final teamTwoRoster = _sixPlayerActiveRoster('E');
      final game = _game({
        'D1': _line(minutesPlayed: 35, points: 10),
        'D2': _line(minutesPlayed: 32, points: 10),
        'D3': _line(minutesPlayed: 30, points: 10),
        'D4': _line(minutesPlayed: 28, points: 10),
        'D5': _line(minutesPlayed: 25, points: 10),
        'D6': _line(minutesPlayed: 20, points: 8), // team 1's sixth man
        'E1': _line(minutesPlayed: 35, points: 10),
        'E2': _line(minutesPlayed: 32, points: 10),
        'E3': _line(minutesPlayed: 30, points: 10),
        'E4': _line(minutesPlayed: 28, points: 10),
        'E5': _line(minutesPlayed: 25, points: 10),
        // team 2's sixth man -- fewer minutes than D1-D5, but a much
        // better composite than D6, so this one should win league-wide.
        'E6': _line(minutesPlayed: 20, points: 25, rebounds: 5),
      });
      final franchise = _baseFranchise(
        ownRoster: [_active('A')],
        aiTeamRosters: {0: teamOneRoster, 1: teamTwoRoster},
        playedGames: [game],
      );

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners[Achievement.sixthManOfTheYear], 'E6');
    });

    test('Sixth Man of the Year has no winner when no team has 6 active '
        'players who played', () {
      final a = _active('A');
      final game = _game({'A': _line(points: 10)});
      final franchise = _baseFranchise(ownRoster: [a], playedGames: [game]);

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(
        result.winners.containsKey(Achievement.sixthManOfTheYear),
        isFalse,
      );
    });

    test('Rookie of the Year goes to the best composite among 0-years-of-'
        'service players; a veteran with a better composite doesn\'t '
        'affect it', () {
      final veteran = _active('B', years: 5);
      final rookie = _active('R', years: 0);
      final game = _game({
        'B': _line(points: 20, rebounds: 10, assists: 8, steals: 3, blocks: 2),
        'R': _line(points: 15, rebounds: 5, assists: 3, steals: 1, blocks: 1),
      });
      final franchise = _baseFranchise(
        ownRoster: [veteran, rookie],
        playedGames: [game],
      );

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners[Achievement.rookieOfTheYear], 'R');
      expect(result.winners[Achievement.leagueMvp], 'B');
    });

    test('Rookie of the Year has no winner when no rookie played', () {
      final veteran = _active('B', years: 5);
      final game = _game({'B': _line(points: 20)});
      final franchise = _baseFranchise(
        ownRoster: [veteran],
        playedGames: [game],
      );

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners.containsKey(Achievement.rookieOfTheYear), isFalse);
    });

    test('Most Improved Player has no winner when seasonStartOverallByPlayerId '
        'is empty (season 0, never captured)', () {
      final a = _active('A', overall: 70);
      final game = _game({'A': _line(points: 10)});
      final franchise = _baseFranchise(ownRoster: [a], playedGames: [game]);

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(
        result.winners.containsKey(Achievement.mostImprovedPlayer),
        isFalse,
      );
    });

    test('Most Improved Player has no winner when nobody actually gained '
        'overall (only declines/flat deltas exist)', () {
      final a = _active('A', overall: 70);
      final game = _game({'A': _line(points: 10)});
      final franchise = _baseFranchise(
        ownRoster: [a],
        playedGames: [game],
        seasonStartOverallByPlayerId: {'A': 75}, // declined, not improved
      );

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(
        result.winners.containsKey(Achievement.mostImprovedPlayer),
        isFalse,
      );
    });

    test('the Most Improved Player / Rookie of the Year overlap rule: when '
        'the same player would win both, Rookie of the Year keeps it and '
        'Most Improved Player rolls down to the next real gain '
        '(SeasonAwardsAnswers.md #6)', () {
      final a = _active('A', overall: 70); // veteran, smaller real gain
      final rookie = _active('R', overall: 55, years: 0); // bigger gain
      final game = _game({
        'A': _line(points: 20),
        'R': _line(points: 15, rebounds: 5, assists: 3, steals: 1, blocks: 1),
      });
      final franchise = _baseFranchise(
        ownRoster: [a, rookie],
        playedGames: [game],
        seasonStartOverallByPlayerId: {
          'A': 62, // delta +8
          'R': 45, // delta +10 -- would top MIP on raw delta alone
        },
      );

      final result = resolveSeasonAwards(Random(1), franchise);

      expect(result.winners[Achievement.rookieOfTheYear], 'R');
      expect(result.winners[Achievement.mostImprovedPlayer], 'A');
    });

    test('every winner actually has the achievement applied on the '
        'returned franchise', () {
      final a = _active('A', overall: 70);
      final game = _game({'A': _line(points: 30)});
      final franchise = _baseFranchise(ownRoster: [a], playedGames: [game]);

      final result = resolveSeasonAwards(Random(1), franchise);

      final updated = result.franchise.roster.single.player;
      expect(
        updated.achievements.any((r) => r.achievement == Achievement.leagueMvp),
        isTrue,
      );
      expect(
        updated.achievements.any(
          (r) => r.achievement == Achievement.scoringLeader,
        ),
        isTrue,
      );
    });
  });
}

PlayedGame _game(Map<String, PlayedGameStatLine> boxScore) {
  return PlayedGame(
    game: const ScheduledGame(
      week: 2,
      day: GameDay.sunday,
      homeTeamAbbreviation: 'AAA',
      awayTeamAbbreviation: 'BBB',
      type: GameType.regularSeason,
    ),
    homeScore: 80,
    awayScore: 70,
    boxScoreByPlayerId: boxScore,
  );
}

Franchise _baseFranchise({
  required List<RosterMembership> ownRoster,
  Map<int, List<RosterMembership>> aiTeamRosters = const {},
  List<PlayedGame> playedGames = const [],
  Map<String, int> seasonStartOverallByPlayerId = const {},
}) {
  var league = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  if (aiTeamRosters.isNotEmpty) {
    league = League(
      aiTeams: [
        for (var i = 0; i < league.aiTeams.length; i++)
          if (aiTeamRosters[i] case final roster?)
            league.aiTeams[i].copyWithRoster(roster)
          else
            league.aiTeams[i],
      ],
    );
  }
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool[1],
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: ownRoster,
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: league,
    seasonProgress: SeasonProgress(
      schedule: SeasonSchedule(games: [for (final g in playedGames) g.game]),
      playedGames: playedGames,
      nextGameDayIndex: playedGames.length,
    ),
    trainingCoaches: const [
      TrainingCoach(name: 'Coach A'),
      TrainingCoach(name: 'Coach B'),
      TrainingCoach(name: 'Coach C'),
    ],
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
    seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
  );
}
