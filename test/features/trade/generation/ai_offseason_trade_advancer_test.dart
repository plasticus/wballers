import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/ai_team_roster.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/trade/generation/ai_offseason_trade_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../roster/domain/roster_test_helpers.dart';

List<RosterMembership> _activeAt(Position position, List<int> overalls) {
  return [
    for (final overall in overalls)
      RosterMembership(
        player: playerWithOverall(
          overall,
          primaryPosition: position,
          id:
              'p-${position.name}-$overall-${identityHashCode(overalls)}-'
              '${overalls.indexOf(overall)}',
        ),
        status: RosterStatus.active,
      ),
  ];
}

/// A fully hand-built franchise -- 19 real [kLeagueTeamPool] identities
/// ([League]'s own fixed count), the first `rosters.length` given real,
/// controlled rosters and the rest empty filler (no active players at
/// all, so [resolveAiOffseasonTrades] can never find a surplus on them --
/// safe, inert padding). Deliberately not [testLeague]'s real 19-team
/// draw, so nothing outside [rosters] can ever coincidentally supply a
/// complementary trade partner and make a test about *which* teams
/// do/don't trade flaky.
Franchise _franchiseWithAiRosters(List<List<RosterMembership>> rosters) {
  final aiTeams = [
    for (var i = 0; i < 19; i++)
      AiTeamRoster(
        // Index 0/1 are reserved for the GM's own team/replaced slot
        // below -- every AI team starts at 2.
        team: kLeagueTeamPool[i + 2],
        roster: i < rosters.length ? rosters[i] : const [],
        coach: const Coach(
          name: 'AI Coach',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
      ),
  ];
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
    league: League(aiTeams: aiTeams),
    seasonProgress: const SeasonProgress(
      schedule: SeasonSchedule(games: []),
      playedGames: [],
      nextGameDayIndex: 0,
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
  group('resolveAiOffseasonTrades (2026-08-19, a direct GM ask: "make a few '
      'AI trades happen in the off-season... 1:1... at least 2 players '
      'from every position... Max gap of 36")', () {
    test('executes a complementary 1:1 swap -- each side\'s weakest '
        'player at its own surplus position, within the gap cap', () {
      final franchise = _franchiseWithAiRosters([
        // Surplus PG (3), needs SG (1).
        [
          ..._activeAt(Position.pointGuard, [55, 50, 60]),
          ..._activeAt(Position.shootingGuard, [58]),
        ],
        // Surplus SG (3), needs PG (1).
        [
          ..._activeAt(Position.shootingGuard, [55, 52, 65]),
          ..._activeAt(Position.pointGuard, [58]),
        ],
      ]);
      final teamA = franchise.league.aiTeams[0].team.abbreviation;
      final teamB = franchise.league.aiTeams[1].team.abbreviation;

      final advance = resolveAiOffseasonTrades(Random(1), franchise);

      expect(advance.tradedTeamAbbreviations, {teamA, teamB});
      final updatedA = advance.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == teamA,
      );
      final updatedB = advance.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == teamB,
      );
      // A's weakest PG (overall 50) left; A now has a real SG (52)
      // from B's weakest.
      expect(
        updatedA.roster.any((m) => m.player.ratings.overall == 50),
        isFalse,
      );
      expect(
        updatedA.roster.any(
          (m) =>
              m.player.primaryPosition == Position.shootingGuard &&
              m.player.ratings.overall == 52,
        ),
        isTrue,
      );
      // B's weakest SG (overall 52) left; B now has A's weakest PG
      // (50).
      expect(
        updatedB.roster.any((m) => m.player.ratings.overall == 52),
        isFalse,
      );
      expect(
        updatedB.roster.any(
          (m) =>
              m.player.primaryPosition == Position.pointGuard &&
              m.player.ratings.overall == 50,
        ),
        isTrue,
      );
      // Roster sizes never change -- 1:1 only.
      expect(updatedA.roster, hasLength(4));
      expect(updatedB.roster, hasLength(4));
    });

    test(
      'never trades when the resulting gap exceeds kAiOffseasonTradeMaxGap',
      () {
        final franchise = _franchiseWithAiRosters([
          [
            ..._activeAt(Position.pointGuard, [70, 50, 71]),
            ..._activeAt(Position.shootingGuard, [58]),
          ],
          [
            ..._activeAt(Position.shootingGuard, [20, 21, 65]),
            ..._activeAt(Position.pointGuard, [58]),
          ],
        ]);
        final teamA = franchise.league.aiTeams[0].team.abbreviation;
        final teamB = franchise.league.aiTeams[1].team.abbreviation;
        // Weakest PG on A (50, 600 pts) vs weakest SG on B (20, 240 pts)
        // -- a 360-point gap, nowhere close to clearing 36.

        final advance = resolveAiOffseasonTrades(Random(1), franchise);

        expect(advance.tradedTeamAbbreviations, isNot(contains(teamA)));
        expect(advance.tradedTeamAbbreviations, isNot(contains(teamB)));
        final updatedA = advance.league.aiTeams.firstWhere(
          (t) => t.team.abbreviation == teamA,
        );
        expect(
          updatedA.roster.map((m) => m.player.id).toSet(),
          franchise.league.aiTeams[0].roster.map((m) => m.player.id).toSet(),
        );
      },
    );

    test('each team trades at most once -- with 2 identically-shaped teams '
        'both wanting the same partner, only one of them actually gets it', () {
      final franchise = _franchiseWithAiRosters([
        [
          ..._activeAt(Position.pointGuard, [55, 50, 60]),
          ..._activeAt(Position.shootingGuard, [58]),
        ],
        // The only SG-surplus team -- 0 and 2 both want it, but it
        // can only actually trade with one of them.
        [
          ..._activeAt(Position.shootingGuard, [55, 52, 65]),
          ..._activeAt(Position.pointGuard, [58]),
        ],
        // Same shape as team 0.
        [
          ..._activeAt(Position.pointGuard, [53, 54, 61]),
          ..._activeAt(Position.shootingGuard, [58]),
        ],
      ]);
      final teamAbbreviations = [
        for (final aiTeam in franchise.league.aiTeams.take(3))
          aiTeam.team.abbreviation,
      ];

      final advance = resolveAiOffseasonTrades(Random(1), franchise);

      // Exactly 2 of the 3 controlled teams traded -- team 1 (the
      // only SG-surplus team) must be one of them, since it's the
      // only team either 0 or 2 could possibly pair with.
      final tradedAmongControlled = teamAbbreviations
          .where(advance.tradedTeamAbbreviations.contains)
          .toSet();
      expect(tradedAmongControlled, hasLength(2));
      expect(advance.tradedTeamAbbreviations, contains(teamAbbreviations[1]));

      // Whichever of team 0/team 2 didn't get picked keeps its exact
      // original roster -- untouched, not partially modified.
      final untradedIndex =
          advance.tradedTeamAbbreviations.contains(teamAbbreviations[0])
          ? 2
          : 0;
      final untradedAbbreviation = teamAbbreviations[untradedIndex];
      final updatedUntraded = advance.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == untradedAbbreviation,
      );
      expect(
        updatedUntraded.roster.map((m) => m.player.id).toSet(),
        franchise.league.aiTeams[untradedIndex].roster
            .map((m) => m.player.id)
            .toSet(),
      );
    });

    test('is deterministic for the same random seed', () {
      final franchise = _franchiseWithAiRosters([
        [
          ..._activeAt(Position.pointGuard, [55, 50, 60]),
          ..._activeAt(Position.shootingGuard, [58]),
        ],
        [
          ..._activeAt(Position.shootingGuard, [55, 52, 65]),
          ..._activeAt(Position.pointGuard, [58]),
        ],
      ]);

      final a = resolveAiOffseasonTrades(Random(7), franchise);
      final b = resolveAiOffseasonTrades(Random(7), franchise);

      expect(a.tradedTeamAbbreviations, b.tradedTeamAbbreviations);
      for (var i = 0; i < a.league.aiTeams.length; i++) {
        expect(
          a.league.aiTeams[i].roster.map((m) => m.player.id).toList(),
          b.league.aiTeams[i].roster.map((m) => m.player.id).toList(),
        );
      }
    });

    test('never touches developmental/reserve players -- active roster '
        'only, matching every other season-end AI system', () {
      final benchPlayer = RosterMembership(
        player: playerWithOverall(
          10,
          primaryPosition: Position.pointGuard,
          id: 'bench-pg',
        ),
        status: RosterStatus.developmental,
      );
      final franchise = _franchiseWithAiRosters([
        [
          ..._activeAt(Position.pointGuard, [55, 50, 60]),
          ..._activeAt(Position.shootingGuard, [58]),
          benchPlayer,
        ],
        [
          ..._activeAt(Position.shootingGuard, [55, 52, 65]),
          ..._activeAt(Position.pointGuard, [58]),
        ],
      ]);
      final teamA = franchise.league.aiTeams[0].team.abbreviation;

      final advance = resolveAiOffseasonTrades(Random(1), franchise);

      final updatedA = advance.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == teamA,
      );
      expect(updatedA.roster.any((m) => m.player.id == 'bench-pg'), isTrue);
    });
  });
}
