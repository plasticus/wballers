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
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_focus.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/generation/training_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/league_test_helpers.dart';

/// The raw sum of every field-level delta a training cycle produced --
/// unlike [PlayerGrowthResult.overallDelta] (which rounds a 12-field
/// average and can hide a real single-field change), this always
/// reflects exactly what got applied to the roster.
int _totalFieldDelta(TrainingReport report) {
  return report.results.fold(
    0,
    (sum, result) => sum + result.fieldDeltas.values.fold(0, (a, b) => a + b),
  );
}

/// [runTraining]'s field-level changes are stochastically rounded
/// (`_roundStochastic`), so a single unlucky seed can legitimately
/// produce zero change even when the expected delta is solidly nonzero.
/// Retries across a handful of seeds so these tests assert on the
/// formula's real behavior rather than one draw's luck -- the odds of
/// every seed missing are astronomically small whenever the underlying
/// expected delta is meaningfully nonzero.
TrainingAdvance _runUntilNonEmpty(Franchise franchise) {
  for (var seed = 1; seed <= 20; seed++) {
    final advance = runTraining(Random(seed), franchise)!;
    if (advance.report.results.isNotEmpty) return advance;
  }
  fail('expected a nonzero training result within 20 seeds');
}

Player _player({
  required String id,
  int age = 25,
  int overall = 50,
  int potential = 50,
  Set<Trait> traits = const {},
}) {
  return Player(
    id: id,
    name: id,
    age: age,
    yearsOfService: 3,
    hometown: 'Testville',
    primaryPosition: Position.smallForward,
    handedness: Handedness.right,
    biography: '',
    ratings: PlayerRatings(
      speed: overall,
      agility: overall,
      strength: overall,
      stamina: overall,
      ballControl: overall,
      passing: overall,
      interiorOffense: overall,
      perimeterOffense: overall,
      perimeterDefense: overall,
      interiorDefense: overall,
      disruption: overall,
      blocking: overall,
      potential: potential,
    ),
    heightInches: 70,
    archetype: kArchetypesByPosition[Position.smallForward]!.first,
    traits: traits,
  );
}

/// One dummy regular-season game at [week], on its own, so the whole
/// week is trivially "complete" the moment this game day is marked
/// played -- what actually simulated it doesn't matter to `runTraining`,
/// only `PlayedGame.minutesByPlayerId` and the fixture's `week` do.
ScheduledGame _dummyGame(int week) {
  return ScheduledGame(
    week: week,
    day: GameDay.sunday,
    homeTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    awayTeamAbbreviation: 'ZZZ',
    type: GameType.regularSeason,
  );
}

/// A minimal, valid [Franchise] with full control over the roster,
/// what week is "ready" for training, and each player's recorded
/// minutes -- [nextGameDayIndex] is always 1 (this one dummy game day is
/// the whole schedule, so it's always fully played), which is what makes
/// [week] always the completed one `lastFullyCompletedWeek` reports.
Franchise _franchiseWith({
  required List<RosterMembership> roster,
  required int week,
  required Map<String, double> minutesByPlayerId,
  int nextTrainingWeek = 1,
  TrainingPlan? trainingPlan,
  List<TrainingCoach>? trainingCoaches,
  int coachDevelopment = 50,
}) {
  final game = _dummyGame(week);
  return Franchise(
    id: 'test-franchise',
    gmName: 'Test GM',
    team: kLeagueTeamPool.first,
    coach: Coach(
      name: 'Head Coach',
      stats: CoachStats(
        offense: 50,
        defense: 50,
        development: coachDevelopment,
        motivation: 50,
        management: 50,
      ),
      archetype: CoachArchetype.steadyHand,
    ),
    roster: roster,
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ),
    seasonProgress: SeasonProgress(
      schedule: SeasonSchedule(games: [game]),
      playedGames: [
        PlayedGame(
          game: game,
          homeScore: 80,
          awayScore: 70,
          minutesByPlayerId: minutesByPlayerId,
        ),
      ],
      nextGameDayIndex: 1,
    ),
    trainingCoaches:
        trainingCoaches ??
        const [
          TrainingCoach(name: 'Coach A'),
          TrainingCoach(name: 'Coach B'),
          TrainingCoach(name: 'Coach C'),
        ],
    trainingPlan: trainingPlan ?? TrainingPlan.initial(),
    nextTrainingWeek: nextTrainingWeek,
  );
}

void main() {
  test('returns null when no week is fully complete yet', () {
    final franchise =
        _franchiseWith(
          roster: [],
          week: 2,
          minutesByPlayerId: const {},
        ).copyWithSeasonProgress(
          SeasonProgress(
            schedule: SeasonSchedule(games: [_dummyGame(2)]),
            playedGames: const [],
            nextGameDayIndex: 0, // nothing played yet
          ),
        );

    expect(runTraining(Random(1), franchise), isNull);
  });

  test('returns null once the completed week is already behind '
      'nextTrainingWeek', () {
    final franchise = _franchiseWith(
      roster: [],
      week: 2,
      minutesByPlayerId: const {},
      nextTrainingWeek: 3, // already trained through week 2
    );

    expect(runTraining(Random(1), franchise), isNull);
  });

  test('reserve/inactive players never change', () {
    final player = _player(id: 'p1', age: 20, overall: 40, potential: 90);
    final franchise = _franchiseWith(
      roster: [
        RosterMembership(player: player, status: RosterStatus.reserveInactive),
      ],
      week: 2,
      minutesByPlayerId: {'p1': 200},
    );

    final advance = runTraining(Random(1), franchise)!;

    expect(advance.franchise.roster.single.player.ratings.overall, 40);
    expect(advance.report.results, isEmpty);
  });

  test('a young player with a wide gap to potential and real minutes '
      'grows', () {
    final player = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: {'p1': 200}, // well above a "full" week
    );

    final advance = _runUntilNonEmpty(franchise);

    expect(advance.report.results, hasLength(1));
    expect(advance.report.results.single.playerId, 'p1');
    expect(_totalFieldDelta(advance.report), greaterThan(0));
  });

  test('an old player declines even with zero minutes -- decline is not '
      'minutes-gated', () {
    final player = _player(id: 'p1', age: 34, overall: 60, potential: 60);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: const {}, // didn't play at all
    );

    final advance = _runUntilNonEmpty(franchise);

    expect(_totalFieldDelta(advance.report), lessThan(0));
  });

  test('a young player with zero minutes barely grows -- growth is '
      'minutes-gated', () {
    final withMinutes = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final withoutMinutes = _player(
      id: 'p1',
      age: 21,
      overall: 45,
      potential: 90,
    );

    // Same seed for both -- isolates the effect of minutes alone, since
    // any stochastic-rounding luck applies identically to each draw.
    final withMinutesAdvance = runTraining(
      Random(1),
      _franchiseWith(
        roster: [
          RosterMembership(player: withMinutes, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: {'p1': 200},
      ),
    )!;
    final withoutMinutesAdvance = runTraining(
      Random(1),
      _franchiseWith(
        roster: [
          RosterMembership(player: withoutMinutes, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      ),
    )!;

    expect(
      _totalFieldDelta(withMinutesAdvance.report),
      greaterThan(_totalFieldDelta(withoutMinutesAdvance.report)),
    );
  });

  test('a bye week (the team had no game at all) credits assumed '
      'minutes, growing more than a real game the player just didn\'t '
      'play in (2026-08-15, a direct GM ask: "players should all train '
      'like they played 30 minutes")', () {
    final onBye = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final realZero = _player(id: 'p1', age: 21, overall: 45, potential: 90);

    // Same shape as `_franchiseWith`'s own dummy game, except neither
    // side is the GM's own team -- a real bye, not just a real game this
    // player rode the bench for.
    final byeGame = ScheduledGame(
      week: 2,
      day: GameDay.sunday,
      homeTeamAbbreviation: 'ZZZ',
      awayTeamAbbreviation: 'YYY',
      type: GameType.regularSeason,
    );
    final byeFranchise =
        _franchiseWith(
          roster: [
            RosterMembership(player: onBye, status: RosterStatus.active),
          ],
          week: 2,
          minutesByPlayerId: const {},
        ).copyWithSeasonProgress(
          SeasonProgress(
            schedule: SeasonSchedule(games: [byeGame]),
            playedGames: [
              PlayedGame(game: byeGame, homeScore: 80, awayScore: 70),
            ],
            nextGameDayIndex: 1,
          ),
        );
    final realZeroFranchise = _franchiseWith(
      roster: [RosterMembership(player: realZero, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: const {}, // the team played; this player just didn't.
    );

    // A single seed can land on an all-zero stochastic-rounding draw even
    // at a solidly positive expected delta (same reasoning
    // `_runUntilNonEmpty`'s own doc comment gives) -- summed across many
    // seeds instead, same pattern the individual-slot test above uses.
    var byeTotal = 0;
    var realZeroTotal = 0;
    for (var seed = 0; seed < 50; seed++) {
      byeTotal += _totalFieldDelta(
        runTraining(Random(seed), byeFranchise)!.report,
      );
      realZeroTotal += _totalFieldDelta(
        runTraining(Random(seed), realZeroFranchise)!.report,
      );
    }

    expect(byeTotal, greaterThan(realZeroTotal));
  });

  test('a player already at potential barely moves', () {
    final player = _player(id: 'p1', age: 21, overall: 70, potential: 70);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: {'p1': 200},
    );

    final advance = runTraining(Random(1), franchise)!;

    final after = advance.franchise.roster.single.player.ratings.overall;
    expect((after - 70).abs(), lessThanOrEqualTo(1));
  });

  test('the developmental slot grows a player faster than the same '
      'player active, all else equal, when both somehow get identical '
      'real minutes (isolates the multiplier alone -- see the next test '
      'for the realistic case, where a developmental player never '
      'actually gets real minutes at all)', () {
    Player buildPlayer() =>
        _player(id: 'p1', age: 21, overall: 45, potential: 90);

    final activeAdvance = runTraining(
      Random(5),
      _franchiseWith(
        roster: [
          RosterMembership(player: buildPlayer(), status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: {'p1': 200},
      ),
    )!;
    final developmentalAdvance = runTraining(
      Random(5),
      _franchiseWith(
        roster: [
          RosterMembership(
            player: buildPlayer(),
            status: RosterStatus.developmental,
          ),
        ],
        week: 2,
        minutesByPlayerId: {'p1': 200},
      ),
    )!;

    // Both scenarios draw from a fresh `Random(5)` in the same call order
    // (12 field-level rolls, no other randomness in between), so the
    // developmental multiplier's strictly higher per-field threshold makes
    // its hit set a superset of the active scenario's -- this is a real
    // inequality, not a probabilistic one.
    final activeDelta = _totalFieldDelta(activeAdvance.report);
    final developmentalDelta = _totalFieldDelta(developmentalAdvance.report);
    expect(developmentalDelta, greaterThanOrEqualTo(activeDelta));
  });

  test('a developmental-slot player who never suits up for a real game '
      '(the actual, only way this ever happens in a real save -- '
      '`franchise_rosters.dart` excludes her from every game roster) '
      'still trains meaningfully, not just the bare jitter floor an '
      'honest 0 real minutes used to produce (2026-08-19, a direct GM '
      'spec: "~40/week is perfect... better than having them in slot '
      '#10, but costly")', () {
    Player buildPlayer() =>
        _player(id: 'p1', age: 21, overall: 45, potential: 90);

    // Same seed, same week, same dummy game (the team itself played --
    // this isn't a bye) -- the only difference is roster status, and
    // whether 'p1' has a real minutes entry at all. An active player
    // with no entry is a real benched scenario (already covered by "a
    // young player with zero minutes barely grows," above); a
    // developmental player with no entry is the *only* scenario that
    // ever actually happens for her in a real game.
    final activeNoMinutes = runTraining(
      Random(3),
      _franchiseWith(
        roster: [
          RosterMembership(player: buildPlayer(), status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      ),
    )!;
    final developmentalNoMinutes = runTraining(
      Random(3),
      _franchiseWith(
        roster: [
          RosterMembership(
            player: buildPlayer(),
            status: RosterStatus.developmental,
          ),
        ],
        week: 2,
        minutesByPlayerId: const {},
      ),
    )!;

    final activeDelta = _totalFieldDelta(activeNoMinutes.report);
    final developmentalDelta = _totalFieldDelta(developmentalNoMinutes.report);
    expect(developmentalDelta, greaterThan(activeDelta));
  });

  test('an individually-coached slot grows a player faster than the same '
      'player on the team-wide plan, on average, even with identical coach '
      'quality -- "double dipping" a high-potential prospect in one of the '
      '3 slots is genuinely worth it, not just a coincidence of which coach '
      'rolled higher', () {
    Player buildPlayer() =>
        _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final individualPlan = TrainingPlan(
      teamFocus: TrainingFocus.balanced,
      coachSlots: [
        TrainingCoachSlot(
          playerId: 'p1',
          focus: const IndividualTrainingFocus.broad(TrainingFocus.balanced),
        ),
        const TrainingCoachSlot(),
        const TrainingCoachSlot(),
      ],
    );

    // Every coach (head and all 3 individual slots) rates exactly 50 --
    // coach quality is held equal, so the only thing that can differ
    // between these two scenarios, on average, is the
    // individual-attention multiplier itself. A single seed's result
    // can land on the same side of a stochastic-rounding boundary by
    // chance, so this compares totals across many seeds instead.
    var teamWideTotal = 0;
    var individualTotal = 0;
    for (var seed = 0; seed < 100; seed++) {
      final teamWideAdvance = runTraining(
        Random(seed),
        _franchiseWith(
          roster: [
            RosterMembership(
              player: buildPlayer(),
              status: RosterStatus.active,
            ),
          ],
          week: 2,
          minutesByPlayerId: {'p1': 200},
        ),
      )!;
      final individualAdvance = runTraining(
        Random(seed),
        _franchiseWith(
          roster: [
            RosterMembership(
              player: buildPlayer(),
              status: RosterStatus.active,
            ),
          ],
          week: 2,
          minutesByPlayerId: {'p1': 200},
          trainingPlan: individualPlan,
        ),
      )!;
      teamWideTotal += _totalFieldDelta(teamWideAdvance.report);
      individualTotal += _totalFieldDelta(individualAdvance.report);
    }

    expect(individualTotal, greaterThan(teamWideTotal));
  });

  test('an individually-assigned coach slot overrides the team-wide focus, '
      'but training-coach identity no longer affects quality at all -- '
      'that always comes from the head coach (TODO.md item 7: "they should '
      'all simply be an extension of the head coach\'s capabilities")', () {
    final player = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    Franchise franchiseWith(List<TrainingCoach> coaches) => _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: {'p1': 200},
      coachDevelopment: 90,
      trainingPlan: TrainingPlan(
        teamFocus: TrainingFocus.balanced,
        coachSlots: [
          TrainingCoachSlot(
            playerId: 'p1',
            focus: const IndividualTrainingFocus.broad(TrainingFocus.offense),
          ),
          const TrainingCoachSlot(),
          const TrainingCoachSlot(),
        ],
      ),
      trainingCoaches: coaches,
    );

    final advanceA = runTraining(
      Random(3),
      franchiseWith(const [
        TrainingCoach(name: 'Coach A'),
        TrainingCoach(name: 'Idle B'),
        TrainingCoach(name: 'Idle C'),
      ]),
    )!;
    final advanceB = runTraining(
      Random(3),
      franchiseWith(const [
        TrainingCoach(name: 'A Totally Different Name'),
        TrainingCoach(name: 'Idle B'),
        TrainingCoach(name: 'Idle C'),
      ]),
    )!;

    // The focus override still routes growth toward offense fields.
    final offenseFieldsChanged = advanceA.report.results.single.fieldDeltas.keys
        .where(kOffenseFields.contains);
    expect(offenseFieldsChanged, isNotEmpty);

    // Same seed, same head coach, same everything except which name
    // sits in slot 0 -- identical result proves coach identity itself
    // has no effect on quality anymore.
    expect(
      advanceA.report.results.single.fieldDeltas,
      advanceB.report.results.single.fieldDeltas,
    );
  });

  test('report only lists players who actually changed', () {
    final changing = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final unchanging = _player(id: 'p2', age: 27, overall: 50, potential: 50);
    final franchise = _franchiseWith(
      roster: [
        RosterMembership(player: changing, status: RosterStatus.active),
        RosterMembership(player: unchanging, status: RosterStatus.active),
      ],
      week: 2,
      minutesByPlayerId: {'p1': 200, 'p2': 0},
    );

    final advance = runTraining(Random(1), franchise)!;

    expect(
      advance.report.results.map((r) => r.playerId),
      isNot(contains('p2')),
    );
  });

  test('a training cycle that jumps several real weeks at once (an '
      'off-season gap, or any stretch nothing called runTraining in '
      'between) reports the whole range it actually covers, not just the '
      'ending week -- a real bug, live on-device (2026-08-19, a direct GM '
      'report): "simulated the off-season, and only for one training '
      'report (week24)... maybe give me an off-season training report '
      'that covers weeks 20 through 24"', () {
    final player = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 24,
      nextTrainingWeek: 20, // nothing trained since week 19
      minutesByPlayerId: {'p1': 200},
    );

    final advance = runTraining(Random(1), franchise)!;

    expect(advance.report.fromWeek, 20);
    expect(advance.report.week, 24);
    expect(advance.report.weekRangeLabel, 'Weeks 20-24');
  });

  test('an ordinary single-week cycle still just reports that one week', () {
    final player = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 5,
      nextTrainingWeek: 5,
      minutesByPlayerId: {'p1': 200},
    );

    final advance = runTraining(Random(1), franchise)!;

    expect(advance.report.fromWeek, 5);
    expect(advance.report.week, 5);
    expect(advance.report.weekRangeLabel, 'Week 5');
  });

  test('advancing nextTrainingWeek makes the same week not re-trainable', () {
    final player = _player(id: 'p1', age: 21, overall: 45, potential: 90);
    final franchise = _franchiseWith(
      roster: [RosterMembership(player: player, status: RosterStatus.active)],
      week: 2,
      minutesByPlayerId: {'p1': 200},
    );

    final advance = runTraining(Random(1), franchise)!;

    expect(advance.franchise.nextTrainingWeek, 3);
    expect(runTraining(Random(1), advance.franchise), isNull);
  });

  group('resolveSeasonEndAging (TODO.md item 1: off-season lump)', () {
    test('reserve/inactive players never change', () {
      final player = _player(id: 'p1', age: 34, overall: 60, potential: 60);
      final franchise = _franchiseWith(
        roster: [
          RosterMembership(
            player: player,
            status: RosterStatus.reserveInactive,
          ),
        ],
        week: 2,
        minutesByPlayerId: const {},
      );

      final advance = resolveSeasonEndAging(Random(1), franchise);

      expect(advance.franchise.roster.single.player.ratings.overall, 60);
      expect(advance.results, isEmpty);
    });

    test('a growing player gets an off-season growth lump too (growth '
        'lever 3, growth-curve study part 2 -- not gap-gated, so even a '
        'player already at her own potential still gets it)', () {
      final young = _player(id: 'p1', age: 22, overall: 45, potential: 90);
      final atPotential = _player(
        id: 'p2',
        age: 22,
        overall: 60,
        potential: 60,
      );
      final franchise = _franchiseWith(
        roster: [
          RosterMembership(player: young, status: RosterStatus.active),
          RosterMembership(player: atPotential, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      );

      final advance = resolveSeasonEndAging(Random(1), franchise);

      expect(advance.results, hasLength(2));
      for (final result in advance.results) {
        final total = result.fieldDeltas.values.fold(0, (a, b) => a + b);
        expect(total, greaterThan(0));
      }
    });

    test('a declining-age player (28+, past the single plateau year at '
        '27) gets nothing from the growth-side lump', () {
      final decliningAge = _player(
        id: 'p1',
        age: 28,
        overall: 60,
        potential: 60,
      );
      final franchise = _franchiseWith(
        roster: [
          RosterMembership(player: decliningAge, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      );

      final advance = resolveSeasonEndAging(Random(1), franchise);

      // Still declines (this age's ageFactor is negative), just via the
      // decline half, not the growth half -- covered by the "an old
      // veteran declines" test below for the actual magnitude.
      expect(
        advance.franchise.roster.single.player.ratings.overall,
        lessThanOrEqualTo(60),
      );
    });

    test('an old veteran declines via the one-time lump, even with zero '
        'minutes -- same "aging happens regardless of minutes" rule as '
        'weekly decline', () {
      final player = _player(id: 'p1', age: 34, overall: 70, potential: 70);
      final franchise = _franchiseWith(
        roster: [RosterMembership(player: player, status: RosterStatus.active)],
        week: 2,
        minutesByPlayerId: const {},
      );

      var advance = resolveSeasonEndAging(Random(1), franchise);
      for (var seed = 2; advance.results.isEmpty && seed <= 20; seed++) {
        advance = resolveSeasonEndAging(Random(seed), franchise);
      }

      expect(advance.results, hasLength(1));
      final total = advance.results.single.fieldDeltas.values.fold(
        0,
        (a, b) => a + b,
      );
      expect(total, lessThan(0));
    });

    test('the one-time lump moves a veteran meaningfully more than a '
        'single week of the softened in-season decline does', () {
      final forLump = _player(id: 'p1', age: 34, overall: 70, potential: 70);
      final forWeek = _player(id: 'p1', age: 34, overall: 70, potential: 70);
      final franchise = _franchiseWith(
        roster: [
          RosterMembership(player: forWeek, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      );

      var weeklyTotal = 0;
      var lumpTotal = 0;
      const sampleSize = 100;
      for (var seed = 0; seed < sampleSize; seed++) {
        final weekly = runTraining(Random(seed), franchise)!;
        weeklyTotal += _totalFieldDelta(weekly.report);

        final lump = resolveSeasonEndAging(
          Random(seed),
          _franchiseWith(
            roster: [
              RosterMembership(player: forLump, status: RosterStatus.active),
            ],
            week: 2,
            minutesByPlayerId: const {},
          ),
        );
        lumpTotal += lump.results.fold(
          0,
          (sum, r) => sum + r.fieldDeltas.values.fold(0, (a, b) => a + b),
        );
      }

      // Both are negative (decline); the lump's magnitude should clearly
      // outweigh one week's.
      expect(lumpTotal.abs(), greaterThan(weeklyTotal.abs()));
    });

    test('the gymRat trait softens the lump, same as it softens weekly '
        'decline', () {
      final plain = _player(id: 'p1', age: 34, overall: 70, potential: 70);
      final gymRat = _player(
        id: 'p1',
        age: 34,
        overall: 70,
        potential: 70,
        traits: {Trait.gymRat},
      );

      var plainTotal = 0;
      var gymRatTotal = 0;
      const sampleSize = 100;
      for (var seed = 0; seed < sampleSize; seed++) {
        final plainAdvance = resolveSeasonEndAging(
          Random(seed),
          _franchiseWith(
            roster: [
              RosterMembership(player: plain, status: RosterStatus.active),
            ],
            week: 2,
            minutesByPlayerId: const {},
          ),
        );
        final gymRatAdvance = resolveSeasonEndAging(
          Random(seed),
          _franchiseWith(
            roster: [
              RosterMembership(player: gymRat, status: RosterStatus.active),
            ],
            week: 2,
            minutesByPlayerId: const {},
          ),
        );
        plainTotal += plainAdvance.results.fold(
          0,
          (sum, r) => sum + r.fieldDeltas.values.fold(0, (a, b) => a + b),
        );
        gymRatTotal += gymRatAdvance.results.fold(
          0,
          (sum, r) => sum + r.fieldDeltas.values.fold(0, (a, b) => a + b),
        );
      }

      expect(gymRatTotal.abs(), lessThan(plainTotal.abs()));
    });

    test('the returned franchise carries the roster change through '
        'copyWithSeasonEndAging', () {
      final player = _player(id: 'p1', age: 34, overall: 70, potential: 70);
      final franchise = _franchiseWith(
        roster: [RosterMembership(player: player, status: RosterStatus.active)],
        week: 2,
        minutesByPlayerId: const {},
      );

      var advance = resolveSeasonEndAging(Random(1), franchise);
      for (var seed = 2; advance.results.isEmpty && seed <= 20; seed++) {
        advance = resolveSeasonEndAging(Random(seed), franchise);
      }

      expect(advance.franchise.seasonEndAgingResults, advance.results);
      expect(
        advance.franchise.roster.single.player.ratings.overall,
        lessThan(70),
      );
    });
  });

  group('resolveAiTeamSeasonTraining (TODO.md item 8: AI teams train too, '
      'all at once at season end)', () {
    /// A franchise whose league has exactly one controlled AI team
    /// ([controlledRoster], at [targetTeam]) -- the other 18 come
    /// straight from [testLeague] untouched, satisfying [League]'s own
    /// "exactly 19 AI teams" assert without this test needing to build
    /// all 19 by hand.
    // The controlled team's real abbreviation -- `weekGame` needs this as
    // its home side so a played game actually counts as *this* team
    // playing (not an unrelated bye -- see `_kAssumedByeWeekMinutes`'s
    // doc comment in `training_advancer.dart`). Stable across calls:
    // `generateLeague` is deterministic for a given seed +
    // replacedTeamAbbreviation, the same two values every call here uses.
    final controlledTeamAbbreviation = testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    ).aiTeams.first.team.abbreviation;

    Franchise franchiseWithAiTeam({
      required List<RosterMembership> controlledRoster,
      required List<PlayedGame> playedGames,
    }) {
      final baseLeague = testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      );
      final league = League(
        aiTeams: [
          baseLeague.aiTeams.first.copyWithRoster(controlledRoster),
          ...baseLeague.aiTeams.skip(1),
        ],
      );
      return Franchise(
        id: 'test-franchise',
        gmName: 'Test GM',
        team: kLeagueTeamPool[1],
        coach: const Coach(
          name: 'Head Coach',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: const [],
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        league: league,
        seasonProgress: SeasonProgress(
          schedule: SeasonSchedule(
            games: [for (final g in playedGames) g.game],
          ),
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

    /// The raw sum of all 12 current-ability fields -- unlike
    /// `PlayerRatings.overall` (a rounded 12-field average), this always
    /// reflects real growth even when it's concentrated in just one or
    /// two fields, too small on its own to move the rounded overall by a
    /// whole point.
    int totalRatingFields(PlayerRatings r) =>
        r.speed +
        r.agility +
        r.strength +
        r.stamina +
        r.ballControl +
        r.passing +
        r.interiorOffense +
        r.perimeterOffense +
        r.perimeterDefense +
        r.interiorDefense +
        r.disruption +
        r.blocking;

    PlayedGame weekGame(int week, Map<String, double> minutesByPlayerId) {
      return PlayedGame(
        game: ScheduledGame(
          week: week,
          day: GameDay.sunday,
          homeTeamAbbreviation: controlledTeamAbbreviation,
          awayTeamAbbreviation: 'BBB',
          type: GameType.regularSeason,
        ),
        homeScore: 80,
        awayScore: 70,
        minutesByPlayerId: minutesByPlayerId,
      );
    }

    test('AI rosters actually change -- a young, wide-gap-to-potential '
        'player with real minutes grows', () {
      final player = _player(id: 'ai1', age: 21, overall: 50, potential: 95);
      final franchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: player, status: RosterStatus.active),
        ],
        playedGames: [
          weekGame(1, {'ai1': 40}),
          weekGame(2, {'ai1': 40}),
          weekGame(3, {'ai1': 40}),
        ],
      );

      final advance = resolveAiTeamSeasonTraining(Random(1), franchise);
      final grownPlayer = advance.league.aiTeams.first.roster.single.player;

      // Real growth can land as a single point on one field without
      // moving the rounded `overall` at all -- see `totalRatingFields`'s
      // own doc comment.
      expect(
        totalRatingFields(grownPlayer.ratings),
        greaterThan(totalRatingFields(player.ratings)),
      );
    });

    test('an AI player gets assumed-minutes bye credit for a week the '
        'league played but her own team didn\'t (2026-08-15, a direct GM '
        'ask: "players should all train like they played 30 minutes")', () {
      final onBye = _player(id: 'ai1', age: 21, overall: 50, potential: 95);
      final realZero = _player(id: 'ai1', age: 21, overall: 50, potential: 95);

      // Week 1: two other teams play -- the controlled team has no game
      // at all, a real bye, not just a real game this player didn't
      // dress for.
      final byeWeekFranchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: onBye, status: RosterStatus.active),
        ],
        playedGames: [
          PlayedGame(
            game: const ScheduledGame(
              week: 1,
              day: GameDay.sunday,
              homeTeamAbbreviation: 'BBB',
              awayTeamAbbreviation: 'CCC',
              type: GameType.regularSeason,
            ),
            homeScore: 80,
            awayScore: 70,
          ),
        ],
      );
      // Week 1: the controlled team plays, but this player gets 0 minutes.
      final realZeroFranchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: realZero, status: RosterStatus.active),
        ],
        playedGames: [weekGame(1, const {})],
      );

      // Same "sum across many seeds" reasoning as the individual-slot
      // test above -- a single seed can land on an all-zero
      // stochastic-rounding draw even at a solidly positive expected
      // delta.
      var byeTotal = 0;
      var realZeroTotal = 0;
      for (var seed = 0; seed < 50; seed++) {
        final byeAdvance = resolveAiTeamSeasonTraining(
          Random(seed),
          byeWeekFranchise,
        );
        final realZeroAdvance = resolveAiTeamSeasonTraining(
          Random(seed),
          realZeroFranchise,
        );
        byeTotal += totalRatingFields(
          byeAdvance.league.aiTeams.first.roster.single.player.ratings,
        );
        realZeroTotal += totalRatingFields(
          realZeroAdvance.league.aiTeams.first.roster.single.player.ratings,
        );
      }

      expect(byeTotal, greaterThan(realZeroTotal));
    });

    test('reserve/inactive AI players never change', () {
      final player = _player(id: 'ai1', age: 21, overall: 50, potential: 95);
      final franchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(
            player: player,
            status: RosterStatus.reserveInactive,
          ),
        ],
        playedGames: [
          weekGame(1, {'ai1': 40}),
        ],
      );

      final advance = resolveAiTeamSeasonTraining(Random(1), franchise);
      final untouchedPlayer = advance.league.aiTeams.first.roster.single.player;

      expect(untouchedPlayer.ratings.overall, 50);
    });

    test('every other AI team trains too, without changing who\'s on which '
        'roster -- same 19 teams, same order, same players', () {
      final player = _player(id: 'ai1', age: 21, overall: 50, potential: 95);
      final franchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: player, status: RosterStatus.active),
        ],
        playedGames: [
          weekGame(1, {'ai1': 40}),
        ],
      );

      final advance = resolveAiTeamSeasonTraining(Random(1), franchise);

      expect(advance.league.aiTeams.length, 19);
      for (var i = 0; i < advance.league.aiTeams.length; i++) {
        // Team identity and roster composition are untouched -- only
        // ratings can move, never who's on the team or in what order.
        // (The team at index 0 is this test's own controlled team, which
        // trains too, exactly like the other 18 -- that's the whole
        // point of this feature, not something to assert against here.)
        expect(
          advance.league.aiTeams[i].team.abbreviation,
          franchise.league.aiTeams[i].team.abbreviation,
        );
        final beforeIds = franchise.league.aiTeams[i].roster
            .map((m) => m.player.id)
            .toList();
        final afterIds = advance.league.aiTeams[i].roster
            .map((m) => m.player.id)
            .toList();
        expect(afterIds, beforeIds);
      }
    });

    test('the same seed produces the same result', () {
      final player = _player(id: 'ai1', age: 21, overall: 50, potential: 95);
      final franchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: player, status: RosterStatus.active),
        ],
        playedGames: [
          weekGame(1, {'ai1': 40}),
          weekGame(2, {'ai1': 40}),
        ],
      );

      final a = resolveAiTeamSeasonTraining(Random(5), franchise);
      final b = resolveAiTeamSeasonTraining(Random(5), franchise);

      expect(
        a.league.aiTeams.first.roster.single.player.ratings.overall,
        b.league.aiTeams.first.roster.single.player.ratings.overall,
      );
    });

    test('replaying the formula per real week produces more growth than '
        'collapsing the same total minutes into one combined delta -- '
        '"similar numbers as they\'d get week to week," not a '
        'mega-week that undercounts growth via the minutes-factor cap', () {
      final player = _player(id: 'ai1', age: 21, overall: 50, potential: 95);

      // Per-week: 6 separate weeks of 40 minutes each, resolved the way
      // resolveAiTeamSeasonTraining actually does it.
      final perWeekFranchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: player, status: RosterStatus.active),
        ],
        playedGames: [
          for (var w = 1; w <= 6; w++) weekGame(w, {'ai1': 40}),
        ],
      );
      final perWeekAdvance = resolveAiTeamSeasonTraining(
        Random(1),
        perWeekFranchise,
      );
      final perWeekTotal = totalRatingFields(
        perWeekAdvance.league.aiTeams.first.roster.single.player.ratings,
      );

      // Mega-week: the exact same 240 total minutes, but all recorded on
      // a single week -- one combined delta, capped by
      // _kMinutesFactorCap regardless of how much real time that spans.
      final megaWeekFranchise = franchiseWithAiTeam(
        controlledRoster: [
          RosterMembership(player: player, status: RosterStatus.active),
        ],
        playedGames: [
          weekGame(1, {'ai1': 240}),
        ],
      );
      final megaWeekAdvance = resolveAiTeamSeasonTraining(
        Random(1),
        megaWeekFranchise,
      );
      final megaWeekTotal = totalRatingFields(
        megaWeekAdvance.league.aiTeams.first.roster.single.player.ratings,
      );

      expect(perWeekTotal, greaterThan(megaWeekTotal));
    });
  });

  group('resolveAiTeamSeasonEndAging (2026-08-11, 0D_Season_2_Roadmap.md: '
      'Aging & roster churn -- AI veterans decline too, not just the GM\'s '
      'own)', () {
    /// Same "one controlled AI team, the other 18 straight from
    /// [testLeague]" shape as [franchiseWithAiTeam] above -- no played
    /// games needed here, since [resolveAiTeamSeasonEndAging] (like
    /// [resolveSeasonEndAging]) is minutes-gate-free.
    Franchise franchiseWithAiRoster(List<RosterMembership> roster) {
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
      return Franchise(
        id: 'test-franchise',
        gmName: 'Test GM',
        team: kLeagueTeamPool[1],
        coach: const Coach(
          name: 'Head Coach',
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

    test('an old AI veteran declines via the one-time lump, even with '
        'zero minutes', () {
      final player = _player(id: 'ai1', age: 34, overall: 70, potential: 70);
      final franchise = franchiseWithAiRoster([
        RosterMembership(player: player, status: RosterStatus.active),
      ]);

      Player declined() => resolveAiTeamSeasonEndAging(
        Random(1),
        franchise,
      ).league.aiTeams.first.roster.single.player;

      var result = declined();
      for (var seed = 2; result.ratings.overall >= 70 && seed <= 20; seed++) {
        result = resolveAiTeamSeasonEndAging(
          Random(seed),
          franchise,
        ).league.aiTeams.first.roster.single.player;
      }

      expect(result.ratings.overall, lessThan(70));
    });

    test('a growing AI player gets the off-season growth lump too '
        '(growth lever 3)', () {
      final young = _player(id: 'ai1', age: 22, overall: 45, potential: 90);
      final franchise = franchiseWithAiRoster([
        RosterMembership(player: young, status: RosterStatus.active),
      ]);

      final advance = resolveAiTeamSeasonEndAging(Random(1), franchise);

      expect(
        advance.league.aiTeams.first.roster.single.player.ratings.overall,
        greaterThan(45),
      );
    });

    test('reserve/inactive AI players never change', () {
      final player = _player(id: 'ai1', age: 34, overall: 70, potential: 70);
      final franchise = franchiseWithAiRoster([
        RosterMembership(player: player, status: RosterStatus.reserveInactive),
      ]);

      final advance = resolveAiTeamSeasonEndAging(Random(1), franchise);

      expect(
        advance.league.aiTeams.first.roster.single.player.ratings.overall,
        70,
      );
    });

    test('every other AI team is untouched -- same 19 teams, same order, '
        'same players', () {
      final player = _player(id: 'ai1', age: 34, overall: 70, potential: 70);
      final franchise = franchiseWithAiRoster([
        RosterMembership(player: player, status: RosterStatus.active),
      ]);

      final advance = resolveAiTeamSeasonEndAging(Random(1), franchise);

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
}
