import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/retirement_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

PlayedGame _finalsGame({required String winner, required String loser}) {
  return PlayedGame(
    game: ScheduledGame(
      week: 24,
      day: GameDay.sunday,
      homeTeamAbbreviation: winner,
      awayTeamAbbreviation: loser,
      type: GameType.postseason,
      postseasonRound: 3,
    ),
    homeScore: 80,
    awayScore: 70,
  );
}

/// Same "one controlled AI team, the other 18 straight from [testLeague]"
/// shape used elsewhere in this session's Aging & Churn tests.
/// [championAbbreviation], when given, appends a fabricated Finals result
/// so `seasonChampion` resolves to it.
Franchise _franchiseWithAiRoster(
  List<RosterMembership> roster, {
  String? championAbbreviation,
}) {
  final baseLeague = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final league = League(
    aiTeams: [
      baseLeague.aiTeams.first.copyWithRoster(roster),
      ...baseLeague.aiTeams.skip(1),
    ],
  );
  final playedGames = championAbbreviation == null
      ? const <PlayedGame>[]
      : [_finalsGame(winner: championAbbreviation, loser: 'ZZZ')];
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool[1],
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: const [],
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
  );
}

void main() {
  group('resolveAiTeamRetirements (2026-08-11, 0D_Season_2_Roadmap.md: Aging '
      '& roster churn -- retirement)', () {
    test('a player who hits the mandatory retirement age retires, no '
        'roll involved', () {
      final vet = playerWithOverall(
        70,
        id: 'vet',
        age: kMandatoryRetirementAge,
      );
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: vet, status: RosterStatus.active),
      ]);

      final advance = resolveAiTeamRetirements(Random(1), franchise);

      expect(advance.retiredPlayerIds, {'vet'});
      expect(
        advance.league.aiTeams.first.roster.map((m) => m.player.id),
        isNot(contains('vet')),
      );
    });

    test('a player who has declined kRetirementDeclineFromPeak or more from '
        'their recorded peak retires', () {
      final declined = Player(
        id: 'declined',
        name: 'Declined Vet',
        age: 30,
        yearsOfService: 8,
        hometown: 'Testville',
        primaryPosition: Position.smallForward,
        handedness: Handedness.right,
        biography: '',
        ratings: playerWithOverall(60, id: 'declined').ratings,
        heightInches: 70,
        archetype: kArchetypesByPosition[Position.smallForward]!.first,
        peakOverall: 60 + kRetirementDeclineFromPeak,
      );
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: declined, status: RosterStatus.active),
      ]);

      final advance = resolveAiTeamRetirements(Random(1), franchise);

      expect(advance.retiredPlayerIds, {'declined'});
    });

    test('a championship-team veteran can retire, but only when old enough, '
        'on the champion team, and the roll lands', () {
      final onChampion = playerWithOverall(
        80,
        id: 'on-champion',
        age: kChampionshipConsiderationAge,
      );
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: onChampion, status: RosterStatus.active),
      ], championAbbreviation: franchiseChampionAbbreviation());

      var advance = resolveAiTeamRetirements(Random(1), franchise);
      for (
        var seed = 2;
        advance.retiredPlayerIds.isEmpty && seed <= 30;
        seed++
      ) {
        advance = resolveAiTeamRetirements(Random(seed), franchise);
      }

      expect(advance.retiredPlayerIds, {'on-champion'});
    });

    test('the same championship-team veteran never retires when their team '
        'did not actually win it', () {
      final notChampion = playerWithOverall(
        80,
        id: 'not-champion',
        age: kChampionshipConsiderationAge,
      );
      // No championAbbreviation given -- seasonChampion resolves to
      // null, so this team can never match it.
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: notChampion, status: RosterStatus.active),
      ]);

      for (var seed = 1; seed <= 30; seed++) {
        final advance = resolveAiTeamRetirements(Random(seed), franchise);
        expect(advance.retiredPlayerIds, isEmpty, reason: 'seed $seed');
      }
    });

    test('a young, healthy, non-champion player never retires', () {
      final young = playerWithOverall(70, id: 'young', age: 24);
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: young, status: RosterStatus.active),
      ]);

      for (var seed = 1; seed <= 10; seed++) {
        final advance = resolveAiTeamRetirements(Random(seed), franchise);
        expect(advance.retiredPlayerIds, isEmpty, reason: 'seed $seed');
      }
    });

    test('a retired player is removed entirely, regardless of '
        'RosterStatus -- not gated by playing time', () {
      final reserve = playerWithOverall(
        60,
        id: 'reserve',
        age: kMandatoryRetirementAge,
      );
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: reserve, status: RosterStatus.reserveInactive),
      ]);

      final advance = resolveAiTeamRetirements(Random(1), franchise);

      expect(advance.retiredPlayerIds, {'reserve'});
    });

    test('every other AI team is untouched -- same 19 teams, same order, '
        'same players', () {
      final vet = playerWithOverall(
        70,
        id: 'vet',
        age: kMandatoryRetirementAge,
      );
      final franchise = _franchiseWithAiRoster([
        RosterMembership(player: vet, status: RosterStatus.active),
      ]);

      final advance = resolveAiTeamRetirements(Random(1), franchise);

      expect(advance.league.aiTeams, hasLength(19));
      for (var i = 1; i < franchise.league.aiTeams.length; i++) {
        expect(
          advance.league.aiTeams[i].team.abbreviation,
          franchise.league.aiTeams[i].team.abbreviation,
        );
        expect(
          advance.league.aiTeams[i].roster.map((m) => m.player.id),
          franchise.league.aiTeams[i].roster.map((m) => m.player.id),
        );
      }
    });
  });

  group('evaluateRetirementEligibility (the GM\'s-own-roster path -- no roll, '
      'even for the championship trigger)', () {
    test('flags the mandatory-age trigger', () {
      final player = playerWithOverall(
        70,
        id: 'p1',
        age: kMandatoryRetirementAge,
      );

      expect(
        evaluateRetirementEligibility(player, wonChampionship: false),
        RetirementReason.hitMandatoryAge,
      );
    });

    test('flags the peak-decline trigger', () {
      final player = Player(
        id: 'p1',
        name: 'Declined Vet',
        age: 30,
        yearsOfService: 8,
        hometown: 'Testville',
        primaryPosition: Position.smallForward,
        handedness: Handedness.right,
        biography: '',
        ratings: playerWithOverall(60, id: 'p1').ratings,
        heightInches: 70,
        archetype: kArchetypesByPosition[Position.smallForward]!.first,
        peakOverall: 60 + kRetirementDeclineFromPeak,
      );

      expect(
        evaluateRetirementEligibility(player, wonChampionship: false),
        RetirementReason.declinedFromPeak,
      );
    });

    test('flags the championship trigger with no roll -- always eligible '
        'when old enough and on the champion team, unlike '
        'evaluateRetirement', () {
      final player = playerWithOverall(
        80,
        id: 'p1',
        age: kChampionshipConsiderationAge,
      );

      expect(
        evaluateRetirementEligibility(player, wonChampionship: true),
        RetirementReason.wonChampionshipLate,
      );
    });

    test('never flags a young, healthy, non-champion player', () {
      final player = playerWithOverall(70, id: 'p1', age: 24);

      expect(
        evaluateRetirementEligibility(player, wonChampionship: true),
        isNull,
      );
    });
  });

  group('attemptRetirementPersuasion', () {
    test('a maxed-out Motivation coach still isn\'t a guaranteed success -- '
        'clamped at kMaxPersuasionChance', () {
      const coach = Coach(
        name: 'Coach',
        stats: CoachStats(
          offense: 50,
          defense: 50,
          development: 50,
          motivation: 99,
          management: 50,
        ),
        archetype: CoachArchetype.steadyHand,
      );

      var sawFailure = false;
      for (var seed = 1; seed <= 200 && !sawFailure; seed++) {
        if (!attemptRetirementPersuasion(Random(seed), coach)) {
          sawFailure = true;
        }
      }

      expect(
        sawFailure,
        isTrue,
        reason:
            'expected at least one failure within 200 seeds even at '
            'max Motivation',
      );
    });

    test('a bottomed-out Motivation coach still has a real chance -- clamped '
        'at kMinPersuasionChance', () {
      const coach = Coach(
        name: 'Coach',
        stats: CoachStats(
          offense: 50,
          defense: 50,
          development: 50,
          motivation: 1,
          management: 50,
        ),
        archetype: CoachArchetype.steadyHand,
      );

      var sawSuccess = false;
      for (var seed = 1; seed <= 200 && !sawSuccess; seed++) {
        if (attemptRetirementPersuasion(Random(seed), coach)) {
          sawSuccess = true;
        }
      }

      expect(
        sawSuccess,
        isTrue,
        reason:
            'expected at least one success within 200 seeds even at '
            'min Motivation',
      );
    });
  });
}

/// The controlled team's own abbreviation, whatever [testLeague]'s first
/// AI team happens to be for this fixture's seed -- kept in one place so
/// a championship-trigger test always names the *actual* first team, not
/// a guessed literal.
String franchiseChampionAbbreviation() {
  return testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  ).aiTeams.first.team.abbreviation;
}
