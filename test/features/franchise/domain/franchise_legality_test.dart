import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise_legality.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart'
    show kPreseasonWeek;
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWithRoster(
  List<RosterMembership> roster, {
  SeasonProgress? seasonProgress,
}) {
  return Franchise(
    id: 'test-franchise',
    gmName: 'Test GM',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Test Coach',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: roster,
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress:
        seasonProgress ??
        testSeasonProgress(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
          ownTeam: kLeagueTeamPool.first,
        ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

/// A minimal 2-game-day schedule -- one preseason day, one regular-season
/// day right after it -- so [blockedByIllegalActiveRoster] tests can
/// point [SeasonProgress.nextGameDayIndex] at either without needing a
/// full generated season.
SeasonProgress _twoDayProgress({required int nextGameDayIndex}) {
  return SeasonProgress(
    schedule: const SeasonSchedule(
      games: [
        ScheduledGame(
          week: kPreseasonWeek,
          day: GameDay.sunday,
          homeTeamAbbreviation: 'AAA',
          awayTeamAbbreviation: 'BBB',
          type: GameType.preseason,
        ),
        ScheduledGame(
          week: 2,
          day: GameDay.sunday,
          homeTeamAbbreviation: 'AAA',
          awayTeamAbbreviation: 'BBB',
          type: GameType.regularSeason,
        ),
      ],
    ),
    playedGames: const [],
    nextGameDayIndex: nextGameDayIndex,
  );
}

void main() {
  test('a legal active roster with no developmental players is legal', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Player $i'),
          status: RosterStatus.active,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isTrue);
  });

  test('reserve/inactive members never count toward any cap', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Active $i'),
          status: RosterStatus.active,
        ),
      // Even four-star reserves shouldn't push the four-star count up.
      for (var i = 0; i < 5; i++)
        RosterMembership(
          player: playerWithOverall(95, name: 'Reserve $i'),
          status: RosterStatus.reserveInactive,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isTrue);
    expect(legality.fourStarCount, 0);
  });

  test('too many active four-star players makes the franchise illegal', () {
    final roster = [
      for (var i = 0; i < 3; i++)
        RosterMembership(
          player: playerWithOverall(95, name: 'Star $i'),
          status: RosterStatus.active,
        ),
      for (var i = 0; i < 9; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Role $i'),
          status: RosterStatus.active,
        ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isFalse);
    expect(legality.hasLegalFourStarCount, isFalse);
  });

  test('an ineligible developmental player makes the franchise illegal', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Active $i'),
          status: RosterStatus.active,
        ),
      RosterMembership(
        player: playerWithOverall(50, name: 'Veteran', yearsOfService: 8),
        status: RosterStatus.developmental,
      ),
    ];

    final legality = evaluateFranchiseLegality(_franchiseWithRoster(roster));

    expect(legality.isLegal, isFalse);
    expect(legality.hasOnlyEligibleDevelopmentalPlayers, isFalse);
  });

  group('blockedByIllegalActiveRoster (2026-08-23, a direct GM design call: '
      '"you can roll an illegal roster through preseason, then... if your '
      'roster is illegal before game 1, it won\'t let you play the game '
      'until you drop/trade players and make it legal")', () {
    // 15 active -- over kActiveRosterSize, illegal on roster size alone.
    List<RosterMembership> illegalRoster() => [
      for (var i = 0; i < 15; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Player $i'),
          status: RosterStatus.active,
        ),
    ];
    List<RosterMembership> legalRoster() => [
      for (var i = 0; i < 12; i++)
        RosterMembership(
          player: playerWithOverall(50, name: 'Player $i'),
          status: RosterStatus.active,
        ),
    ];

    test('never blocks an illegal roster from playing through the '
        'preseason', () {
      final franchise = _franchiseWithRoster(
        illegalRoster(),
        seasonProgress: _twoDayProgress(nextGameDayIndex: 0),
      );

      expect(blockedByIllegalActiveRoster(franchise), isFalse);
    });

    test('blocks an illegal roster from advancing into the regular '
        'season', () {
      final franchise = _franchiseWithRoster(
        illegalRoster(),
        seasonProgress: _twoDayProgress(nextGameDayIndex: 1),
      );

      expect(blockedByIllegalActiveRoster(franchise), isTrue);
    });

    test('never blocks a legal roster, preseason or regular season', () {
      for (final index in [0, 1]) {
        final franchise = _franchiseWithRoster(
          legalRoster(),
          seasonProgress: _twoDayProgress(nextGameDayIndex: index),
        );

        expect(
          blockedByIllegalActiveRoster(franchise),
          isFalse,
          reason: 'nextGameDayIndex $index',
        );
      }
    });

    test('is false once the season is fully played out -- nothing left '
        'to block', () {
      final franchise = _franchiseWithRoster(
        illegalRoster(),
        seasonProgress: _twoDayProgress(nextGameDayIndex: 2),
      );

      expect(blockedByIllegalActiveRoster(franchise), isFalse);
    });
  });
}
