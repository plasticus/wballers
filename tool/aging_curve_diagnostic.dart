// ignore_for_file: avoid_print
//
// Growth-curve data study (0D_Season_2_Roadmap.md follow-up, 2026-08-12
// direct GM ask): "I feel disappointed looking at my end of season
// report... I think of a 99 potential rookie, comes into the league at
// 70 OVR. That's great. If they go +5 each season... 6 seasons before
// they reach peak... I think we need to hit peak around 26... let's get
// some data on it and not go based on vibes."
//
// This is a standalone diagnostic script, run explicitly via
// `flutter test tool/aging_curve_diagnostic.dart` (needs `flutter test`,
// not `dart run` -- the real `Franchise`/`Team` domain pulls in `dart:ui`
// transitively for `Team`'s colors, which only Flutter's own tooling can
// resolve). Deliberately outside `test/` so the ordinary `flutter test`
// sweep never picks it up -- it's a one-off data pull, not a
// pass/fail-forever regression test. Not shipped app code. It:
//
//   1. Drives the REAL, shipped growth/decline pipeline (`runTraining`,
//      `resolveSeasonEndAging`, `advancePlayerTenure` --
//      `training_advancer.dart`/`season_tenure_advancer.dart`, all public
//      functions) through a synthetic career, many seasons long, for a
//      handful of representative player profiles -- genuine simulation
//      output, not hand-waving. Each profile is run across many
//      trials (different `Random` seeds) and averaged, since the real
//      pipeline's per-field rounding is stochastic.
//   2. Cross-checks that against a deterministic closed-form
//      reimplementation of the exact same formula (`_ageCurveFactor`/
//      `_totalWeeklyDelta`/`_declinedPlayer` in `training_advancer.dart`
//      -- private to that file, so the constants are copied here,
//      credited inline) -- confirms the two agree before trusting the
//      closed-form model for anything.
//   3. Uses that validated closed-form model to run a few *alternative*
//      age-curve proposals (moving peak earlier, adding a steeper
//      veteran cliff) for direct comparison against the current system.
//
// Output: JSON to stdout -- one object per named series, each a list of
// {age, overall} points -- meant to be piped to a file and charted.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/season_tenure_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_focus.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/generation/training_advancer.dart';

const _focalId = 'focal';

/// A fresh, minimally-valid `Franchise` -- real onboarding factory, so
/// every invariant `Franchise`'s own asserts care about (team/league/
/// roster shape) is satisfied for free. Rebuilt from scratch per trial
/// so no state leaks between trials/scenarios.
Franchise _baseFranchise(int simulationSeed) {
  return createExpansionFranchise(
    gmName: 'Diagnostic',
    clubName: 'Comets',
    homeCity: 'Springfield, IL',
    conference: Conference.atlantic,
    replacedTeamAbbreviation: 'BOS',
    colors: kStarterPalettes.first,
    emoji: '🏀',
    simulationSeed: simulationSeed,
  );
}

Player _focalPlayer({
  required int age,
  required int overall,
  required int potential,
}) {
  return Player(
    id: _focalId,
    name: 'Focal Player',
    age: age,
    yearsOfService: max(0, age - 22),
    hometown: 'Fictional City',
    primaryPosition: Position.pointGuard,
    handedness: Handedness.right,
    biography: '',
    heightInches: 70,
    archetype: kArchetypesByPosition[Position.pointGuard]!.first,
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
  );
}

/// One synthetic season's schedule: [weeksPerSeason] weeks, one game day
/// each (training only cares about weekly totals, not real fixture
/// structure -- see `_minutesInWeekRange`), every one a plain
/// regular-season game so nothing All-Star/Cup-specific kicks in.
SeasonSchedule _syntheticSchedule(int weeksPerSeason) {
  return SeasonSchedule(
    games: [
      for (var week = 1; week <= weeksPerSeason; week++)
        ScheduledGame(
          week: week,
          day: GameDay.sunday,
          homeTeamAbbreviation: 'AAA',
          awayTeamAbbreviation: 'BBB',
          type: GameType.regularSeason,
        ),
    ],
  );
}

/// Runs [franchise] through one synthetic season -- [weeksPerSeason]
/// weeks of real `runTraining` calls (the focal player logged at
/// [weeklyMinutes] every week, same as `_minutesInWeekRange` would sum
/// from a real week's games) followed by one real `resolveSeasonEndAging`
/// call, then `advancePlayerTenure` -- exactly the shipped call order
/// (`season_tenure_advancer.dart`'s own doc comment: age increments
/// *after* every other season-end resolution reads the age the player
/// played the season at).
///
/// Uses the real `copyWithNewSeason` (not a bare `copyWithSeasonProgress`)
/// to reset for the new season -- critically, that's what resets
/// `nextTrainingWeek` back to 1. Missing that reset was a real bug this
/// script had at first: `runTraining` guards on `week < nextTrainingWeek`
/// (`training_advancer.dart`), so every season after the first silently
/// trained zero weeks, flatlining the whole trajectory from age 23
/// onward -- caught by this script's own real-vs-closed-form validation
/// check disagreeing wildly, not by inspection.
Franchise _runOneRealSeason(
  Random random,
  Franchise franchise, {
  required int weeksPerSeason,
  required double weeklyMinutes,
}) {
  final schedule = _syntheticSchedule(weeksPerSeason);
  var current = franchise.copyWithNewSeason(
    newSeason: franchise.season + 1,
    newSeasonProgress: SeasonProgress(
      schedule: schedule,
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
  );

  for (var week = 1; week <= weeksPerSeason; week++) {
    final played = [
      ...current.seasonProgress.playedGames,
      PlayedGame(
        game: schedule.games[week - 1],
        homeScore: 100,
        awayScore: 90,
        minutesByPlayerId: {_focalId: weeklyMinutes},
      ),
    ];
    current = current.copyWithSeasonProgress(
      SeasonProgress(
        schedule: schedule,
        playedGames: played,
        nextGameDayIndex: week,
      ),
    );
    final advance = runTraining(random, current);
    if (advance != null) current = advance.franchise;
  }

  final agingAdvance = resolveSeasonEndAging(random, current);
  current = agingAdvance.franchise;
  return advancePlayerTenure(current);
}

int _overallOf(Franchise franchise) {
  return franchise.roster
      .firstWhere((m) => m.player.id == _focalId)
      .player
      .ratings
      .overall;
}

int _ageOf(Franchise franchise) {
  return franchise.roster.firstWhere((m) => m.player.id == _focalId).player.age;
}

/// Drives the REAL shipped pipeline across [trials] independent
/// `Random` streams, averaging each age's overall -- the stochastic
/// per-field rounding (`_roundStochastic`) means any single trial is
/// noisy, but its expectation is exact (see `_roundStochastic`'s own
/// doc comment: unbiased), so averaging enough trials converges on the
/// same curve the closed-form model computes directly.
Map<int, double> simulateCareerReal({
  required int startAge,
  required int startOverall,
  required int potential,
  required int maxAge,
  required double weeklyMinutes,
  required int weeksPerSeason,
  required int headCoachDevelopment,
  required bool individualSlot,
  int trials = 60,
}) {
  final sums = <int, double>{};
  final counts = <int, int>{};

  for (var trial = 0; trial < trials; trial++) {
    final random = Random(trial * 7919 + 13);
    // Franchise-creation seed is fixed (not varied per trial): `BOS`
    // isn't guaranteed to be in every seed's random 20-team league draw
    // (`league_draw.dart`), and simulationSeed 1 is the one every other
    // test fixture in this codebase already confirms works. Per-trial
    // randomness lives entirely in [random] below instead.
    var franchise = _baseFranchise(1);
    final focal = _focalPlayer(
      age: startAge,
      overall: startOverall,
      potential: potential,
    );
    final newRoster = [
      RosterMembership(player: focal, status: RosterStatus.active),
      ...franchise.roster.skip(1),
    ];
    franchise = franchise
        .copyWithRoster(newRoster)
        .copyWithCoach(
          Coach(
            name: 'Diagnostic Coach',
            stats: CoachStats(
              offense: 50,
              defense: 50,
              development: headCoachDevelopment,
              motivation: 50,
              management: 50,
            ),
            archetype: CoachArchetype.steadyHand,
          ),
        );
    if (individualSlot) {
      franchise = franchise.copyWithTrainingPlan(
        TrainingPlan.initial().copyWithCoachSlot(
          0,
          const TrainingCoachSlot(
            playerId: _focalId,
            focus: IndividualTrainingFocus.broad(TrainingFocus.balanced),
          ),
        ),
      );
    }

    // Deliberately no pre-loop seeding of `sums[startAge]` -- the loop's
    // own first iteration already labels the age-`startAge` bucket with
    // the value *after* that age's season resolves (this function's own
    // "played at" convention), which is what belongs there. Seeding it
    // with the *pre-season* starting value here too would silently
    // average two different things (entering-the-season vs.
    // finishing-it) into the same bucket -- a real bug this script had
    // at first, caught by the validation check's diff nearly 10x-ing
    // between one run and the next for no code-logic reason.
    var age = startAge;
    while (age < maxAge) {
      // Label with the age they actually *played that season at* (the
      // standard sports-analytics age-curve convention -- "their rating
      // during their age-27 season"), not the age they turn immediately
      // after it, which `advancePlayerTenure` (inside
      // `_runOneRealSeason`) already applies internally.
      final playedAtAge = age;
      franchise = _runOneRealSeason(
        random,
        franchise,
        weeksPerSeason: weeksPerSeason,
        weeklyMinutes: weeklyMinutes,
      );
      age = _ageOf(franchise);
      final overall = _overallOf(franchise);
      sums[playedAtAge] = (sums[playedAtAge] ?? 0) + overall;
      counts[playedAtAge] = (counts[playedAtAge] ?? 0) + 1;
    }
  }

  return {for (final age in sums.keys) age: sums[age]! / counts[age]!};
}

// ---------------------------------------------------------------------
// Closed-form model -- validated against simulateCareerReal below before
// being trusted for the alternate-curve scenarios. Constants copied
// directly from `training_advancer.dart` (private to that file):
// _kGrowthScale, _kGapNormalization, _kFullWeekMinutes,
// _kMinutesFactorCap, _kDeclineScale, _kOffSeasonDeclineScale,
// _kJitterFloor, and _ageCurveFactor's own band values.
// ---------------------------------------------------------------------
const _kGrowthScale = 3.2;
const _kGapNormalization = 40.0;
const _kFullWeekMinutes = 50.0;
const _kMinutesFactorCap = 1.3;
const _kDeclineScale = 0.5;
const _kOffSeasonDeclineScale = 12.5;
const _kJitterFloor = 0.15;
// `_totalWeeklyDelta`/`_declinedPlayer` compute a *total, summed-across-
// all-12-fields* delta, then `_distributeAcrossFields` splits it (evenly,
// for a balanced focus/decline) across all 12 `PlayerRatingField`s.
// `PlayerRatings.overall` is the unweighted *average* of those same 12
// fields, so the change in `overall` any given week is the total delta
// divided by 12, not the total delta itself -- missing this the first
// time through produced a wildly-too-fast closed-form curve (caught by
// this script's own real-vs-closed-form validation check, off by ~68 OVR
// points, before it was fixed).
const _kFieldCount = 12;

typedef AgeCurve = double Function(int age);

double currentAgeCurve(int age) {
  if (age <= 23) return 1.0;
  if (age <= 26) return 0.6;
  if (age <= 29) return 0.0;
  if (age <= 31) return -0.4;
  return -0.8;
}

/// Alternative #1, "moderate": plateau shrinks from 3 years (27-29) to 1
/// (27), decline starts a year earlier and a little steeper, cliff
/// proper by 33.
double moderateCurve(int age) {
  if (age <= 23) return 1.0;
  if (age <= 26) return 0.6;
  if (age <= 27) return 0.2;
  if (age <= 29) return -0.3;
  if (age <= 32) return -0.7;
  return -1.3;
}

/// Alternative #2, "aggressive": plateau ends 2 years earlier still
/// (peak reads around 25-26 instead of 27-29), and the late-career cliff
/// is both earlier and considerably steeper -- the GM's own ask ("bigger
/// cliff at age... 34? 32?").
double earlierPeakSteeperCliffCurve(int age) {
  if (age <= 22) return 1.0;
  if (age <= 25) return 0.6;
  if (age <= 27) return 0.0;
  if (age <= 29) return -0.5;
  if (age <= 31) return -1.1;
  return -1.8;
}

/// The change in *overall* (not total field-points -- see
/// [_kFieldCount]'s doc comment) for one week.
double _weeklyDelta({
  required int overall,
  required int potential,
  required int age,
  required double minutes,
  required int coachDevelopment,
  required AgeCurve curve,
}) {
  final ageFactor = curve(age);
  if (ageFactor < 0) return (ageFactor * _kDeclineScale) / _kFieldCount;

  final gap = (potential - overall).clamp(0, 98).toDouble();
  final gapFactor = (gap / _kGapNormalization).clamp(0.0, 1.0);
  final minutesFactor = (minutes / _kFullWeekMinutes).clamp(
    0.0,
    _kMinutesFactorCap,
  );
  final coachFactor = coachDevelopment / 50.0;
  final totalDelta =
      ageFactor * gapFactor * minutesFactor * coachFactor * _kGrowthScale;
  return (totalDelta + _kJitterFloor) / _kFieldCount;
}

/// The change in *overall* for the once-a-season off-season lump.
double _offSeasonDelta(int age, AgeCurve curve) {
  final ageFactor = curve(age);
  if (ageFactor >= 0) return 0;
  return (ageFactor * _kOffSeasonDeclineScale) / _kFieldCount;
}

Map<int, double> simulateCareerClosedForm({
  required int startAge,
  required int startOverall,
  required int potential,
  required int maxAge,
  required double weeklyMinutes,
  required int weeksPerSeason,
  required int headCoachDevelopment,
  required AgeCurve curve,
}) {
  // No pre-loop seeding at `startAge` -- same reasoning
  // `simulateCareerReal` documents: the loop's own first iteration
  // labels `startAge` with the value *after* that age's season, which is
  // what belongs there (harmless here either way, since a `Map` write
  // overwrites rather than accumulates -- but kept consistent with the
  // real-pipeline version on principle).
  final points = <int, double>{};
  var overall = startOverall.toDouble();
  var age = startAge;

  while (age < maxAge) {
    for (var week = 0; week < weeksPerSeason; week++) {
      final delta = _weeklyDelta(
        overall: overall.round().clamp(1, 99),
        potential: potential,
        age: age,
        minutes: weeklyMinutes,
        coachDevelopment: headCoachDevelopment,
        curve: curve,
      );
      overall = (overall + delta).clamp(1, 99);
    }
    overall = (overall + _offSeasonDelta(age, curve)).clamp(1, 99);
    // Labeled with the age just played (same convention
    // `simulateCareerReal` uses -- see its own doc comment), not the age
    // `advancePlayerTenure`-equivalent increment below produces.
    points[age] = overall;
    age += 1;
  }
  return points;
}

int _peakAge(Map<int, double> series) {
  var bestAge = series.keys.first;
  var bestValue = series[bestAge]!;
  for (final entry in series.entries) {
    if (entry.value > bestValue) {
      bestValue = entry.value;
      bestAge = entry.key;
    }
  }
  return bestAge;
}

/// The first age at which this series has fallen [kRetirementDeclineFromPeak]
/// (10, `retirement_advancer.dart`) or more below its own peak-so-far --
/// i.e. the age `evaluateRetirementEligibility`'s `declinedFromPeak`
/// trigger would actually fire, real retirement rule, real threshold.
/// `null` if it never happens by [maxAge].
int? _retirementTriggerAge(Map<int, double> series, int maxAge) {
  const declineFromPeakThreshold = 10; // kRetirementDeclineFromPeak
  final ages = series.keys.toList()..sort();
  var peakSoFar = series[ages.first]!;
  for (final age in ages) {
    peakSoFar = max(peakSoFar, series[age]!);
    if (peakSoFar - series[age]! >= declineFromPeakThreshold) return age;
  }
  return null;
}

void main() {
  test('generate aging-curve diagnostic data', _run);
}

void _run() {
  const startAge = 22;
  const startOverall = 70;
  const potential = 99;
  const maxAge = 40;
  const weeksPerSeason = 19; // preseason(1) + regular season(17) + all-star(1)
  const neutralCoach = 50;

  // --- Validation: real pipeline vs. closed-form, same inputs -----------
  final realBaseline = simulateCareerReal(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: neutralCoach,
    individualSlot: false,
    trials: 80,
  );
  final closedFormBaseline = simulateCareerClosedForm(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: neutralCoach,
    curve: currentAgeCurve,
  );
  final maxAbsDiff = [
    for (final age in realBaseline.keys)
      (realBaseline[age]! - (closedFormBaseline[age] ?? realBaseline[age]!))
          .abs(),
  ].reduce(max);
  print(
    '# Validation: real vs. closed-form baseline, max abs diff = '
    '${maxAbsDiff.toStringAsFixed(2)} OVR points across ages '
    '$startAge-$maxAge (80 trials averaged).',
  );

  // --- Headline scenarios (real pipeline) --------------------------------
  final starterNoCoaching = realBaseline; // already computed above
  final starterWithIndividualCoaching = simulateCareerReal(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: 75,
    individualSlot: true,
    trials: 80,
  );
  final rotationPlayer = simulateCareerReal(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: 25,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: neutralCoach,
    individualSlot: false,
    trials: 80,
  );
  final deepPlayoffRun = simulateCareerReal(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: 22, // +3 postseason weeks every year
    headCoachDevelopment: neutralCoach,
    individualSlot: false,
    trials: 80,
  );

  // --- Proposed alternative curves (closed-form, validated model) -------
  final moderateProposed = simulateCareerClosedForm(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: neutralCoach,
    curve: moderateCurve,
  );
  final moderateProposedWithCoaching = simulateCareerClosedForm(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: 75,
    curve: moderateCurve,
  );
  final aggressiveProposed = simulateCareerClosedForm(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: neutralCoach,
    curve: earlierPeakSteeperCliffCurve,
  );
  final aggressiveProposedWithCoaching = simulateCareerClosedForm(
    startAge: startAge,
    startOverall: startOverall,
    potential: potential,
    maxAge: maxAge,
    weeklyMinutes: _kFullWeekMinutes,
    weeksPerSeason: weeksPerSeason,
    headCoachDevelopment: 75,
    curve: earlierPeakSteeperCliffCurve,
  );

  final series = <String, Map<int, double>>{
    'Current system -- starter, no individual coaching': starterNoCoaching,
    'Current system -- starter, WITH individual coaching (dev 75)':
        starterWithIndividualCoaching,
    'Current system -- rotation player (25 min/wk)': rotationPlayer,
    'Current system -- deep playoff run every year (+3 wk/season)':
        deepPlayoffRun,
    'Moderate proposal -- starter, no individual coaching': moderateProposed,
    'Moderate proposal -- starter, WITH individual coaching (dev 75)':
        moderateProposedWithCoaching,
    'Aggressive proposal -- starter, no individual coaching':
        aggressiveProposed,
    'Aggressive proposal -- starter, WITH individual coaching (dev 75)':
        aggressiveProposedWithCoaching,
  };

  final summary = {
    for (final entry in series.entries)
      entry.key: {
        'peakAge': _peakAge(entry.value),
        'peakOverall': entry.value[_peakAge(entry.value)]!.round(),
        'age30': entry.value[30]?.round(),
        'age34': entry.value[34]?.round(),
        'age38': entry.value[38]?.round(),
        'declinedFromPeakRetirementTriggerAge': _retirementTriggerAge(
          entry.value,
          maxAge,
        ),
      },
  };

  final output = {
    'validation': {
      'maxAbsDiffOverallPoints': double.parse(maxAbsDiff.toStringAsFixed(2)),
    },
    'summary': summary,
    'series': {
      for (final entry in series.entries)
        entry.key: [
          for (final age in entry.value.keys.toList()..sort())
            {
              'age': age,
              'overall': double.parse(entry.value[age]!.toStringAsFixed(2)),
            },
        ],
    },
  };

  print(const JsonEncoder.withIndent('  ').convert(output));
}
