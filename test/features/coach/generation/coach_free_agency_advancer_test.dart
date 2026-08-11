import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/coach/generation/coach_free_agency_advancer.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

/// A minimal regular-season [PlayedGame] between [winner] and [loser] --
/// only the win/loss result matters to `currentStandings`, so the score
/// is an arbitrary fixed blowout rather than anything realistic.
PlayedGame _playedGame({required String winner, required String loser}) {
  return PlayedGame(
    game: ScheduledGame(
      week: 2,
      day: GameDay.sunday,
      homeTeamAbbreviation: winner,
      awayTeamAbbreviation: loser,
      type: GameType.regularSeason,
    ),
    homeScore: 80,
    awayScore: 60,
  );
}

/// A franchise fixture with a real 19-team [League] (via [testLeague])
/// and [season] set as given. Every team in [badAbbreviations] loses once
/// to a single dedicated "sink" team (an otherwise-unused AI team), so
/// they always rank at the very bottom of the standings (0.0 win%).
/// Padded with extra loser teams (also beaten by the same sink) up to
/// [kCoachFiringCandidateCount] total, so a short [badAbbreviations] list
/// still comfortably fills the bottom-5 candidate window without a real
/// "good" team's record ever needing to be considered -- every one of
/// those padding teams' coaches is kept safely inside its grace period by
/// [_withCoachHiredSeasons]' `defaultHiredSeason`, so only the teams a
/// test actually cares about can ever end up fired.
Franchise _franchiseWith({
  required int season,
  required List<String> badAbbreviations,
}) {
  final baseLeague = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final allAbbreviations = baseLeague.aiTeams
      .map((t) => t.team.abbreviation)
      .toList();
  final sink = allAbbreviations.last;
  final paddingPool = allAbbreviations
      .where((a) => a != sink && !badAbbreviations.contains(a))
      .toList();
  final paddingNeeded = (kCoachFiringCandidateCount - badAbbreviations.length)
      .clamp(0, paddingPool.length);
  final losers = [...badAbbreviations, ...paddingPool.take(paddingNeeded)];

  final playedGames = [
    for (final loser in losers) _playedGame(winner: sink, loser: loser),
  ];

  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: [
      RosterMembership(
        player: playerWithOverall(70),
        status: RosterStatus.active,
      ),
    ],
    simulationSeed: 1,
    season: season,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: baseLeague,
    seasonProgress: SeasonProgress(
      schedule: testSeasonProgress(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ownTeam: kLeagueTeamPool.first,
      ).schedule,
      playedGames: playedGames,
      nextGameDayIndex: 0,
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

/// Sets every AI team's `coachHiredSeason` -- [hiredSeasonByAbbreviation]
/// for the specific teams a test is controlling, [defaultHiredSeason] for
/// every other team (every padding/sink team from [_franchiseWith], kept
/// at the *current* season so they're always safely inside their grace
/// period and can never be an unintended firing).
Franchise _withCoachHiredSeasons(
  Franchise franchise,
  Map<String, int> hiredSeasonByAbbreviation, {
  required int defaultHiredSeason,
}) {
  return franchise.copyWithLeague(
    League(
      aiTeams: [
        for (final aiTeam in franchise.league.aiTeams)
          aiTeam.copyWithCoach(
            newCoach: aiTeam.coach,
            hiredSeason:
                hiredSeasonByAbbreviation[aiTeam.team.abbreviation] ??
                defaultHiredSeason,
          ),
      ],
    ),
  );
}

void main() {
  group('resolveCoachFreeAgency (2026-08-11, TODO.md: coach free agency in '
      'the off-season)', () {
    test('fires exactly the worst-record AI teams past their grace period, '
        'and leaves every other team untouched', () {
      final badTeams = [
        for (final aiTeam in testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ).aiTeams.take(kCoachFiringCandidateCount))
          aiTeam.team.abbreviation,
      ];
      final base = _withCoachHiredSeasons(
        _franchiseWith(season: 3, badAbbreviations: badTeams),
        {for (final team in badTeams) team: 0},
        defaultHiredSeason: 3, // every other team hired this season
      );

      final advance = resolveCoachFreeAgency(Random(1), base);

      expect(advance.firedTeamAbbreviations, badTeams.toSet());
      // The fired teams' replacement coach was "hired" this same
      // season -- the discriminating check is `firedTeamAbbreviations`
      // above, since every other (untouched) team was also set to
      // season 3 as its `defaultHiredSeason`.
      for (final aiTeam in advance.league.aiTeams) {
        expect(aiTeam.coachHiredSeason, 3);
      }
    });

    test('a coach still inside the grace period is never fired, even with '
        'the league\'s worst record', () {
      final badTeams = [
        testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ).aiTeams.first.team.abbreviation,
      ];
      // Hired the same season that's ending -- 0 seasons of tenure,
      // well inside the 2-season grace period.
      final base = _withCoachHiredSeasons(
        _franchiseWith(season: 1, badAbbreviations: badTeams),
        {badTeams.first: 1},
        defaultHiredSeason: 1,
      );

      final advance = resolveCoachFreeAgency(Random(1), base);

      expect(advance.firedTeamAbbreviations, isEmpty);
      expect(
        advance.league.aiTeams
            .firstWhere((t) => t.team.abbreviation == badTeams.first)
            .coachHiredSeason,
        1,
      );
    });

    test('a coach exactly at the grace-period boundary is eligible', () {
      final badTeams = [
        testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ).aiTeams.first.team.abbreviation,
      ];
      final base = _withCoachHiredSeasons(
        _franchiseWith(season: 2, badAbbreviations: badTeams),
        {badTeams.first: 0}, // season 2 - 0 == kCoachGracePeriodSeasons
        defaultHiredSeason: 2, // every padding team stays protected
      );

      final advance = resolveCoachFreeAgency(Random(1), base);

      expect(advance.firedTeamAbbreviations, badTeams.toSet());
    });

    test('is deterministic for the same random stream', () {
      final badTeams = [
        for (final aiTeam in testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ).aiTeams.take(kCoachFiringCandidateCount))
          aiTeam.team.abbreviation,
      ];
      final base = _withCoachHiredSeasons(
        _franchiseWith(season: 5, badAbbreviations: badTeams),
        {for (final team in badTeams) team: 0},
        defaultHiredSeason: 5,
      );

      final a = resolveCoachFreeAgency(Random(42), base);
      final b = resolveCoachFreeAgency(Random(42), base);

      for (var i = 0; i < a.league.aiTeams.length; i++) {
        expect(a.league.aiTeams[i].coach.name, b.league.aiTeams[i].coach.name);
        expect(
          a.league.aiTeams[i].coach.archetype,
          b.league.aiTeams[i].coach.archetype,
        );
      }
    });

    test('never touches the GM\'s own club', () {
      final base = _franchiseWith(season: 5, badAbbreviations: const []);

      final advance = resolveCoachFreeAgency(Random(1), base);

      expect(
        advance.league.aiTeams.any(
          (t) => t.team.abbreviation == base.team.abbreviation,
        ),
        isFalse,
      );
    });
  });
}
