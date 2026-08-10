import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
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
      'player active, all else equal', () {
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

    test('a growing or plateaued player gets nothing -- this is the '
        'veteran-decline half only', () {
      final young = _player(id: 'p1', age: 22, overall: 45, potential: 90);
      final plateaued = _player(id: 'p2', age: 28, overall: 60, potential: 60);
      final franchise = _franchiseWith(
        roster: [
          RosterMembership(player: young, status: RosterStatus.active),
          RosterMembership(player: plateaued, status: RosterStatus.active),
        ],
        week: 2,
        minutesByPlayerId: const {},
      );

      final advance = resolveSeasonEndAging(Random(1), franchise);

      expect(advance.results, isEmpty);
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
}
