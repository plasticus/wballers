import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/draft/domain/draft_pick.dart';
import 'package:womensbballmgr/features/draft/domain/draft_prospect.dart';
import 'package:womensbballmgr/features/draft/generation/draft_advancer.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/college.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

DraftProspect _prospect(String id, int overall, {int potential = 60}) {
  final player = playerWithOverall(overall, id: id, name: 'Prospect $id');
  return DraftProspect(
    player: player.copyWithRatings(
      player.ratings.copyWith(potential: potential),
    ),
    college: kColleges.first,
  );
}

Franchise _franchise({required String ownTeamAbbreviation}) {
  final league = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final ownTeam = kLeagueTeamPool.firstWhere(
    (t) => t.abbreviation == ownTeamAbbreviation,
  );
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: ownTeam,
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
      schedule: const SeasonSchedule(games: []),
      playedGames: const [],
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
  group('resolveAiPicksUntilOwnTurn', () {
    test('resolves every AI pick, stopping the instant the own team is on '
        'the clock', () {
      final draftClass = [
        _prospect('p1', 80),
        _prospect('p2', 75),
        _prospect('p3', 70),
        _prospect('p4', 65),
      ];
      final draft = DraftInProgress(
        order: const ['AAA', 'OWN', 'BBB'],
        rounds: 1,
      );

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'OWN',
      );

      expect(resolved.picks, hasLength(1));
      expect(resolved.picks.single.teamAbbreviation, 'AAA');
      expect(resolved.picks.single.prospect.player.id, 'p1');
      expect(resolved.onTheClock, 'OWN');
    });

    test('resolves straight through to completion if the own team never '
        'comes up (already fully passed for this round)', () {
      final draftClass = [_prospect('p1', 80), _prospect('p2', 75)];
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB'],
        rounds: 1,
        picks: const [],
      );

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'ZZZ',
      );

      expect(resolved.isComplete, isTrue);
      expect(resolved.picks.map((p) => p.prospect.player.id), ['p1', 'p2']);
    });

    test('is deterministic and picks the best value (overall + potential/2) '
        'available, not just best overall', () {
      final low = _prospect('low', 60, potential: 90);
      final high = _prospect('high', 65, potential: 60);
      final draft = DraftInProgress(order: const ['AAA', 'BBB'], rounds: 1);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [low, high],
        ownTeamAbbreviation: 'ZZZ',
      );

      // low: 60 + 45 = 105, high: 65 + 30 = 95 -- low should go first.
      expect(resolved.picks.first.prospect.player.id, 'low');
    });

    test('applies a Hidden Gems bonus (hidden_gem.dart) using the '
        'picking team\'s own coach Management, not any other team\'s', () {
      final prospect = _prospect('p1', 60);
      final before = prospect.player.ratings.skillPoints;
      final draft = DraftInProgress(order: const ['AAA', 'ZZZ'], rounds: 3);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [prospect],
        ownTeamAbbreviation: 'ZZZ',
        managementByAbbreviation: const {'AAA': 79, 'BBB': 1},
      );

      final landed = resolved.picks.single.prospect.player.ratings.skillPoints;
      expect(landed, before + 12); // round 1, Management 79 -> +12
    });

    test('a team missing from managementByAbbreviation gets no bonus at '
        'all, not a crash', () {
      final prospect = _prospect('p1', 60);
      final before = prospect.player.ratings.skillPoints;
      final draft = DraftInProgress(order: const ['AAA', 'ZZZ'], rounds: 1);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [prospect],
        ownTeamAbbreviation: 'ZZZ',
        // AAA deliberately absent.
      );

      final landed = resolved.picks.single.prospect.player.ratings.skillPoints;
      expect(landed, before);
    });
  });

  group('makeOwnPick', () {
    test('records the GM pick at the current slot', () {
      final draftClass = [_prospect('p1', 80), _prospect('p2', 70)];
      final draft = DraftInProgress(order: const ['OWN', 'BBB'], rounds: 1);

      final updated = makeOwnPick(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'OWN',
        selected: draftClass[1],
      );

      expect(updated.picks, hasLength(1));
      expect(updated.picks.single.teamAbbreviation, 'OWN');
      expect(updated.picks.single.prospect.player.id, 'p2');
      expect(updated.onTheClock, 'BBB');
    });

    test('throws when it is not actually the own team\'s turn', () {
      final draftClass = [_prospect('p1', 80)];
      final draft = DraftInProgress(order: const ['AAA', 'OWN'], rounds: 1);

      expect(
        () => makeOwnPick(
          draft: draft,
          draftClass: draftClass,
          ownTeamAbbreviation: 'OWN',
          selected: draftClass.first,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws when the selected prospect was already drafted', () {
      final p1 = _prospect('p1', 80);
      final p2 = _prospect('p2', 70);
      final draft = DraftInProgress(
        order: const ['AAA', 'OWN'],
        rounds: 1,
        picks: [
          DraftPick(
            round: 1,
            pickNumber: 1,
            teamAbbreviation: 'AAA',
            prospect: p1,
          ),
        ],
      );

      expect(
        () => makeOwnPick(
          draft: draft,
          draftClass: [p1, p2],
          ownTeamAbbreviation: 'OWN',
          selected: p1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('applies a Hidden Gems bonus using ownCoachManagement', () {
      final draftClass = [_prospect('p1', 60)];
      final before = draftClass.single.player.ratings.skillPoints;
      final draft = DraftInProgress(order: const ['OWN', 'BBB'], rounds: 3);

      final updated = makeOwnPick(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'OWN',
        selected: draftClass.single,
        ownCoachManagement: 79,
      );

      final landed = updated.picks.single.prospect.player.ratings.skillPoints;
      expect(landed, before + 12); // round 1, Management 79 -> +12
    });

    test('ownCoachManagement omitted (default 0) applies no bonus at all', () {
      final draftClass = [_prospect('p1', 60)];
      final before = draftClass.single.player.ratings.skillPoints;
      final draft = DraftInProgress(order: const ['OWN', 'BBB'], rounds: 1);

      final updated = makeOwnPick(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'OWN',
        selected: draftClass.single,
      );

      final landed = updated.picks.single.prospect.player.ratings.skillPoints;
      expect(landed, before);
    });
  });

  group('finalizeDraft', () {
    test('lands the own team\'s picks on Franchise.roster and clears both '
        'draftInProgress and draftClass', () {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final franchise = _franchise(ownTeamAbbreviation: ownAbbreviation);
      final prospect = _prospect('p1', 80);
      final draft = DraftInProgress(
        order: [ownAbbreviation],
        rounds: 1,
        picks: [
          DraftPick(
            round: 1,
            pickNumber: 1,
            teamAbbreviation: ownAbbreviation,
            prospect: prospect,
          ),
        ],
      );
      final withDraft = franchise
          .copyWithDraftInProgress(draft)
          .copyWithDraftClass([prospect]);

      final finalized = finalizeDraft(Random(1), withDraft);

      expect(finalized.roster, hasLength(1));
      expect(finalized.roster.single.player.id, 'p1');
      expect(finalized.roster.single.status, RosterStatus.active);
      expect(finalized.roster.single.player.jerseyNumber, isNotNull);
      expect(finalized.draftInProgress, isNull);
      expect(finalized.draftClass, isEmpty);
    });

    test('lands an AI team\'s pick on that team\'s league roster', () {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final franchise = _franchise(ownTeamAbbreviation: ownAbbreviation);
      final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
      final prospect = _prospect('p1', 80);
      final draft = DraftInProgress(
        order: [aiAbbreviation],
        rounds: 1,
        picks: [
          DraftPick(
            round: 1,
            pickNumber: 1,
            teamAbbreviation: aiAbbreviation,
            prospect: prospect,
          ),
        ],
      );
      final withDraft = franchise
          .copyWithDraftInProgress(draft)
          .copyWithDraftClass([prospect]);
      final beforeCount = franchise.league.aiTeams.first.roster.length;

      final finalized = finalizeDraft(Random(1), withDraft);

      final updatedAiTeam = finalized.league.aiTeams.first;
      expect(updatedAiTeam.roster, hasLength(beforeCount + 1));
      expect(updatedAiTeam.roster.any((m) => m.player.id == 'p1'), isTrue);
      expect(finalized.roster, isEmpty);
    });

    test('throws when the draft still has outstanding picks', () {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final franchise = _franchise(ownTeamAbbreviation: ownAbbreviation);
      final draft = DraftInProgress(order: [ownAbbreviation, 'BBB'], rounds: 1);
      final withDraft = franchise.copyWithDraftInProgress(draft);

      expect(
        () => finalizeDraft(Random(1), withDraft),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
