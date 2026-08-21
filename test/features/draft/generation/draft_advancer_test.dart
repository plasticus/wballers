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
import 'package:womensbballmgr/features/league/domain/team_identity.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
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

    test('carries pickOwnershipOverrides and hasBeenOpened forward through '
        'every pick, across rounds -- a real bug this test would have '
        'caught: DraftInProgress.copyWith replaced a manual field-by-field '
        'reconstruction in _appendPick that silently dropped both after '
        'the very first pick of any draft', () {
      final draftClass = [
        _prospect('p1', 80),
        _prospect('p2', 75),
        _prospect('p3', 70),
        _prospect('p4', 65),
      ];
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB'],
        rounds: 2,
        hasBeenOpened: true,
        pickOwnershipOverrides: const {
          2: {'BBB': 'CCC'},
        },
      );

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: draftClass,
        ownTeamAbbreviation: 'CCC',
      );

      // Round 1 resolves both AAA and BBB automatically (no override for
      // round 1), landing on round 2's BBB slot -- now owned by CCC.
      expect(resolved.picks, hasLength(3));
      expect(resolved.onTheClock, 'CCC');
      expect(resolved.hasBeenOpened, isTrue);
      expect(resolved.pickOwnershipOverrides, draft.pickOwnershipOverrides);
    });
  });

  group('position-lean tiebreak (2026-08-20, `team_identity.dart`\'s '
      'TeamIdentity -- a direct GM ask: "I DON\'T want a team drafting a '
      'PG first every draft... they\'d always have at least one or 2 good '
      'ones on the roster, and if they have a star player, they want it '
      'to be a PG")', () {
    DraftProspect prospectAt(
      String id,
      Position position, {
      required int overall,
    }) {
      final player = playerWithOverall(
        overall,
        id: id,
        name: 'Prospect $id',
        primaryPosition: position,
      );
      return DraftProspect(player: player, college: kColleges.first);
    }

    test('a near-tied prospect at the team\'s own lean position wins over '
        'a slightly-higher-value prospect elsewhere', () {
      final leanPosition = identityFor('AAA').positionLean;
      final otherPosition = Position.values.firstWhere(
        (p) => p != leanPosition,
      );
      // draftProspectValue = overall + potential/2 (potential defaults to
      // overall here, via playerWithOverall) -- 70 -> 105, 72 -> 108, a
      // 3-point gap, comfortably inside kPositionLeanTiebreakTolerance (4).
      final leanProspect = prospectAt('lean', leanPosition, overall: 70);
      final betterElsewhere = prospectAt('better', otherPosition, overall: 72);
      final draft = DraftInProgress(order: const ['AAA', 'ZZZ'], rounds: 1);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [leanProspect, betterElsewhere],
        ownTeamAbbreviation: 'ZZZ',
      );

      expect(resolved.picks.single.prospect.player.id, 'lean');
    });

    test('a genuinely better prospect elsewhere still wins outright once '
        'the gap exceeds the tiebreak tolerance -- never "always draft '
        'the lean position"', () {
      final leanPosition = identityFor('AAA').positionLean;
      final otherPosition = Position.values.firstWhere(
        (p) => p != leanPosition,
      );
      // 60 -> 90, 80 -> 120 -- a 30-point gap, nowhere close to the
      // tolerance band.
      final leanProspect = prospectAt('lean', leanPosition, overall: 60);
      final muchBetterElsewhere = prospectAt(
        'better',
        otherPosition,
        overall: 80,
      );
      final draft = DraftInProgress(order: const ['AAA', 'ZZZ'], rounds: 1);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [leanProspect, muchBetterElsewhere],
        ownTeamAbbreviation: 'ZZZ',
      );

      expect(resolved.picks.single.prospect.player.id, 'better');
    });

    test('no near-tied prospect at the lean position -- best value picked '
        'exactly as before, tiebreak never invents a pick', () {
      final leanPosition = identityFor('AAA').positionLean;
      final otherPosition = Position.values.firstWhere(
        (p) => p != leanPosition,
      );
      final onlyProspect = prospectAt('only', otherPosition, overall: 70);
      final draft = DraftInProgress(order: const ['AAA', 'ZZZ'], rounds: 1);

      final resolved = resolveAiPicksUntilOwnTurn(
        draft: draft,
        draftClass: [onlyProspect],
        ownTeamAbbreviation: 'ZZZ',
      );

      expect(resolved.picks.single.prospect.player.id, 'only');
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
      // A direct GM ask (2026-08-19): "we should see what season, round,
      // and pick they were drafted."
      final draftRecord = finalized.roster.single.player.draftRecord;
      expect(draftRecord?.season, franchise.season);
      expect(draftRecord?.round, 1);
      expect(draftRecord?.pickNumber, 1);
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
      final draftedMembership = updatedAiTeam.roster.firstWhere(
        (m) => m.player.id == 'p1',
      );
      expect(draftedMembership.player.draftRecord?.season, franchise.season);
      expect(draftedMembership.player.draftRecord?.round, 1);
      expect(draftedMembership.player.draftRecord?.pickNumber, 1);
    });

    test('a traded pick genuinely lands the prospect on the acquiring '
        'team\'s roster, not the natal slot team\'s (2026-08-19, real '
        'draft-pick ownership)', () {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final franchise = _franchise(ownTeamAbbreviation: ownAbbreviation);
      final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
      final prospect = _prospect('p1', 80);
      // The slot is AI's own by standings, but its round-1 pick was
      // traded to the GM earlier this season.
      final draft = DraftInProgress(
        order: [aiAbbreviation],
        rounds: 1,
        pickOwnershipOverrides: {
          1: {aiAbbreviation: ownAbbreviation},
        },
      );
      final withDraft = franchise
          .copyWithDraftInProgress(draft)
          .copyWithDraftClass([prospect]);

      // The GM, not the AI team, is really on the clock -- resolving
      // "every AI pick until the own team's turn" stops immediately.
      final resolved = resolveAiPicksUntilOwnTurn(
        draft: withDraft.draftInProgress!,
        draftClass: withDraft.draftClass,
        ownTeamAbbreviation: ownAbbreviation,
      );
      expect(resolved.onTheClock, ownAbbreviation);
      expect(resolved.picks, isEmpty);

      final afterOwnPick = makeOwnPick(
        draft: resolved,
        draftClass: withDraft.draftClass,
        ownTeamAbbreviation: ownAbbreviation,
        selected: prospect,
      );
      expect(afterOwnPick.picks.single.teamAbbreviation, ownAbbreviation);

      final finalized = finalizeDraft(
        Random(1),
        withDraft.copyWithDraftInProgress(afterOwnPick),
      );

      // The prospect landed on the GM's own roster, not the AI
      // team's -- the traded pick's ownership was honored for real.
      expect(finalized.roster.any((m) => m.player.id == 'p1'), isTrue);
      expect(
        finalized.league.aiTeams.first.roster.any((m) => m.player.id == 'p1'),
        isFalse,
      );
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
