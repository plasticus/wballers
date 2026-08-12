// ignore_for_file: avoid_print
//
// Draft-class caliber study (2026-08-12 direct GM follow-up, right after
// the growth-curve levers shipped): "we'll need to revisit what players
// show up in the draft, and model like 1000 of them, to see where they
// land, and if our incoming draftees are of the caliber I want to see,
// and making sure we don't have way too many 90+ prospects every
// season. Maybe the current system will work fine, I'd just like to see
// a model."
//
// Run via `flutter test tool/draft_class_diagnostic.dart` (same
// `dart:ui`-via-Flutter-tooling reasoning as `aging_curve_diagnostic.dart`
// -- not shipped app code, deliberately outside `test/`). It:
//
//   1. Generates ~15 REAL draft classes via the actual shipped
//      `generateDraftClass` (`draft_generator.dart`) -- ~1050 real
//      prospects total, each with their real generated overall/potential,
//      not a synthetic assumption. Reports the raw talent shape the game
//      actually produces at generation time, before any growth at all.
//   2. Runs the ~60/70 realistically-draftable prospects per class (best
//      `draftProspectValue` first, same ranking the real draft uses)
//      through a full career under the growth-curve study's now-SHIPPED
//      formula (`training_advancer.dart`'s moderate curve + 4 growth
//      levers, copied here the same "closed-form, credited inline" way
//      `aging_curve_diagnostic.dart` copies from the same source file --
//      see that file for the original real-vs-closed-form validation,
//      0.18 OVR points, that this model is built on). Investment tier
//      (individually slotted / good-coach team-trained / average) is
//      randomized per prospect, weighted toward the better generation
//      tiers getting more of it -- a team's best prospects are the ones
//      most likely to land a scarce individual slot, not a uniform
//      coin flip across the whole class.
//   3. Reports how many drafted prospects, per class and per season
//      league-wide, actually end up peaking at 90+ OVR once given a full
//      career -- the number this whole study exists to check isn't
//      wildly too high (or too low).
//
// Output: JSON to stdout, meant to be piped to a file and charted.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/draft/domain/draft_prospect.dart';
import 'package:womensbballmgr/features/draft/generation/draft_generator.dart';

// ---------------------------------------------------------------------
// The now-SHIPPED growth formula, copied from `training_advancer.dart`
// the same way `aging_curve_diagnostic.dart` does -- every constant here
// matches that file's real, private value exactly (credited inline).
// ---------------------------------------------------------------------
const _kGrowthScale = 3.2;
const _kGapNormalization = 40.0;
const _kFullWeekMinutes = 50.0;
const _kMinutesFactorCap = 1.3;
const _kDeclineScale = 0.5;
const _kOffSeasonDeclineScale = 12.5;
const _kJitterFloor = 0.15;
const _kFieldCount = 12;
const _kRookieSurgeMultiplier = 1.35;
const _kRookieSeasons = 2;
const _kGapConcavityExponent = 0.75;
const _kOffSeasonGrowthScale = 8.0;
const _kBreakoutChanceSlotted = 0.06;
const _kBreakoutChanceUnslotted = 0.10;
const _kBreakoutMultiplier = 3.0;
const _kIndividualAttentionMultiplier = 1.3;

double _ageCurveFactor(int age) {
  if (age <= 23) return 1.0;
  if (age <= 26) return 0.6;
  if (age <= 27) return 0.2;
  if (age <= 29) return -0.3;
  if (age <= 32) return -0.7;
  return -1.3;
}

double _weeklyDelta({
  required int overall,
  required int potential,
  required int age,
  required int yearsOfService,
  required double minutes,
  required int coachDevelopment,
  required bool individuallySlotted,
  required bool breakoutActive,
}) {
  final ageFactor = _ageCurveFactor(age);
  if (ageFactor < 0) return (ageFactor * _kDeclineScale) / _kFieldCount;

  final gap = (potential - overall).clamp(0, 98).toDouble();
  final gapFactor = pow(
    (gap / _kGapNormalization).clamp(0.0, 1.0),
    _kGapConcavityExponent,
  ).toDouble();
  final minutesFactor = (minutes / _kFullWeekMinutes).clamp(
    0.0,
    _kMinutesFactorCap,
  );
  final coachFactor = coachDevelopment / 50.0;

  var delta =
      ageFactor * gapFactor * minutesFactor * coachFactor * _kGrowthScale;
  if (yearsOfService < _kRookieSeasons) delta *= _kRookieSurgeMultiplier;
  if (individuallySlotted) delta *= _kIndividualAttentionMultiplier;
  if (breakoutActive) delta *= _kBreakoutMultiplier;
  return (delta + _kJitterFloor) / _kFieldCount;
}

double _offSeasonDelta(int age) {
  final ageFactor = _ageCurveFactor(age);
  if (ageFactor < 0) {
    return (ageFactor * _kOffSeasonDeclineScale) / _kFieldCount;
  }
  return (ageFactor * _kOffSeasonGrowthScale) / _kFieldCount;
}

/// One drafted prospect's full career, from her real generated
/// (age, overall, potential) through mandatory retirement (38) -- single
/// stochastic trial per player (population-scale study, same reasoning
/// `aging_curve_diagnostic.dart`'s own population study gives: variance
/// comes from population heterogeneity, not from re-trialing one profile).
Map<int, double> _simulateDraftedCareer({
  required Random random,
  required int startAge,
  required int startOverall,
  required int potential,
  required double weeklyMinutes,
  required int weeksPerSeason,
  required int coachDevelopment,
  required bool individuallySlotted,
}) {
  const maxAge = 38; // kMandatoryRetirementAge, retirement_advancer.dart
  final points = <int, double>{};
  var overall = startOverall.toDouble();
  var age = startAge;

  while (age < maxAge) {
    final yearsOfService = age - startAge;
    final breakoutChance = individuallySlotted
        ? _kBreakoutChanceSlotted
        : _kBreakoutChanceUnslotted;
    final breakoutActive = random.nextDouble() < breakoutChance;
    for (var week = 0; week < weeksPerSeason; week++) {
      final delta = _weeklyDelta(
        overall: overall.round().clamp(1, 99),
        potential: potential,
        age: age,
        yearsOfService: yearsOfService,
        minutes: weeklyMinutes,
        coachDevelopment: coachDevelopment,
        individuallySlotted: individuallySlotted,
        breakoutActive: breakoutActive,
      );
      overall = (overall + delta).clamp(1, 99);
    }
    overall = (overall + _offSeasonDelta(age)).clamp(1, 99);
    points[age] = overall;
    age += 1;
  }
  return points;
}

double _peakOf(Map<int, double> career) =>
    career.values.reduce((a, b) => a > b ? a : b);

/// One of the 3 investment tiers a drafted prospect can land in, same
/// shape `aging_curve_diagnostic.dart`'s population study established --
/// here the *probability* of landing each tier is weighted by the
/// prospect's own generation quality tier (below), not uniform: a team's
/// best prospects are the ones most likely to get a scarce individual
/// slot.
enum _InvestmentTier { invested, goodCoachTeamTrained, average }

(int coachDevelopment, double weeklyMinutes, _InvestmentTier tier)
_rollInvestment(Random random, _DraftTier draftTier) {
  final thresholds = switch (draftTier) {
    _DraftTier.elite => (invested: 0.55, goodCoach: 0.90), // rest average
    _DraftTier.solid => (invested: 0.15, goodCoach: 0.50),
    _DraftTier.fringe => (invested: 0.02, goodCoach: 0.15),
  };
  final roll = random.nextDouble();
  if (roll < thresholds.invested) {
    return (
      70 + random.nextInt(21),
      42 + random.nextInt(9).toDouble(),
      _InvestmentTier.invested,
    );
  }
  if (roll < thresholds.goodCoach) {
    return (
      60 + random.nextInt(26),
      25 + random.nextInt(21).toDouble(),
      _InvestmentTier.goodCoachTeamTrained,
    );
  }
  return (
    40 + random.nextInt(26),
    10 + random.nextInt(31).toDouble(),
    _InvestmentTier.average,
  );
}

/// Mirrors `draft_generator.dart`'s own private `_qualityTierFor` shape
/// (2 elite, 12 solid, the rest fringe) -- generation index within a
/// class, not a re-derivation of the actual private quality centers.
enum _DraftTier { elite, solid, fringe }

_DraftTier _draftTierForIndex(int index) {
  if (index < 2) return _DraftTier.elite;
  if (index < 14) return _DraftTier.solid;
  return _DraftTier.fringe;
}

void main() {
  test('generate draft-class diagnostic data', _run);
}

void _run() {
  const classCount = 15; // ~15 * 70 = 1050 prospects, "like 1000" per ask
  const weeksPerSeason = 19;

  final allProspects = <DraftProspect>[];
  final tierByProspectIndex = <int, _DraftTier>{}; // index into allProspects
  for (var classIndex = 0; classIndex < classCount; classIndex++) {
    final classRandom = Random(classIndex * 92821 + 5);
    final draftClass = generateDraftClass(classRandom);
    for (var i = 0; i < draftClass.length; i++) {
      tierByProspectIndex[allProspects.length] = _draftTierForIndex(i);
      allProspects.add(draftClass[i]);
    }
  }

  // --- Raw generation-time shape, before any growth at all ------------
  final rawPotentials = [
    for (final p in allProspects) p.player.ratings.potential,
  ];
  final rawOveralls = [for (final p in allProspects) p.player.ratings.overall];
  int countAtLeast(List<int> values, int threshold) =>
      values.where((v) => v >= threshold).length;

  final eliteProspects = [
    for (var i = 0; i < allProspects.length; i++)
      if (tierByProspectIndex[i] == _DraftTier.elite) allProspects[i],
  ];

  final rawShape = {
    'totalProspectsGenerated': allProspects.length,
    'classCount': classCount,
    'avgOverall': double.parse(
      (rawOveralls.reduce((a, b) => a + b) / rawOveralls.length)
          .toStringAsFixed(1),
    ),
    'avgPotential': double.parse(
      (rawPotentials.reduce((a, b) => a + b) / rawPotentials.length)
          .toStringAsFixed(1),
    ),
    'pctPotential90Plus': double.parse(
      (100 * countAtLeast(rawPotentials, 90) / rawPotentials.length)
          .toStringAsFixed(1),
    ),
    'pctPotential95Plus': double.parse(
      (100 * countAtLeast(rawPotentials, 95) / rawPotentials.length)
          .toStringAsFixed(1),
    ),
    'potential99Count': rawPotentials.where((p) => p >= 99).length,
    'avgEliteProspectOverall': double.parse(
      (eliteProspects
                  .map((p) => p.player.ratings.overall)
                  .reduce((a, b) => a + b) /
              eliteProspects.length)
          .toStringAsFixed(1),
    ),
    'avgEliteProspectPotential': double.parse(
      (eliteProspects
                  .map((p) => p.player.ratings.potential)
                  .reduce((a, b) => a + b) /
              eliteProspects.length)
          .toStringAsFixed(1),
    ),
    'eliteProspectsPerClass': eliteProspects.length / classCount,
  };

  // --- Grown outcome: only the realistically-drafted ~60/70 per class,
  // best draftProspectValue first, same ranking the real draft uses. ---
  final drafted = <MapEntry<int, DraftProspect>>[];
  for (var classIndex = 0; classIndex < classCount; classIndex++) {
    final start = classIndex * (allProspects.length ~/ classCount);
    final classProspects =
        <MapEntry<int, DraftProspect>>[
          for (
            var i = start;
            i < start + (allProspects.length ~/ classCount);
            i++
          )
            MapEntry(i, allProspects[i]),
        ]..sort(
          (a, b) => draftProspectValue(
            b.value,
          ).compareTo(draftProspectValue(a.value)),
        );
    drafted.addAll(classProspects.take(60)); // 20 teams x 3 rounds
  }

  final results = <Map<String, Object?>>[];
  for (final entry in drafted) {
    final index = entry.key;
    final prospect = entry.value;
    final player = prospect.player;
    final draftTier = tierByProspectIndex[index]!;
    final random = Random(index * 65867 + 31);
    final (coachDevelopment, weeklyMinutes, investmentTier) = _rollInvestment(
      random,
      draftTier,
    );

    final career = _simulateDraftedCareer(
      random: random,
      startAge: player.age,
      startOverall: player.ratings.overall,
      potential: player.ratings.potential,
      weeklyMinutes: weeklyMinutes,
      weeksPerSeason: weeksPerSeason,
      coachDevelopment: coachDevelopment,
      individuallySlotted: investmentTier == _InvestmentTier.invested,
    );
    final peak = _peakOf(career);

    results.add({
      'draftTier': draftTier.name,
      'investmentTier': investmentTier.name,
      'startAge': player.age,
      'startOverall': player.ratings.overall,
      'potential': player.ratings.potential,
      'peakOverall': double.parse(peak.toStringAsFixed(1)),
      'reached90': peak >= 90,
      'reached95': peak >= 95,
    });
  }

  Map<String, Object?> tierSummary(_DraftTier tier) {
    final inTier = results.where((r) => r['draftTier'] == tier.name).toList();
    if (inTier.isEmpty) return {};
    final peaks = inTier.map((r) => r['peakOverall']! as double).toList();
    return {
      'count': inTier.length,
      'avgPeakOverall': double.parse(
        (peaks.reduce((a, b) => a + b) / peaks.length).toStringAsFixed(1),
      ),
      'pctReached90': double.parse(
        (100 *
                inTier.where((r) => r['reached90']! as bool).length /
                inTier.length)
            .toStringAsFixed(1),
      ),
      'pctReached95': double.parse(
        (100 *
                inTier.where((r) => r['reached95']! as bool).length /
                inTier.length)
            .toStringAsFixed(1),
      ),
    };
  }

  final total90Plus = results.where((r) => r['reached90']! as bool).length;
  final total95Plus = results.where((r) => r['reached95']! as bool).length;

  final output = {
    'rawGenerationShape': rawShape,
    'grownOutcome': {
      'totalDraftedSimulated': results.length,
      'classCount': classCount,
      'total90PlusPeakOutcomes': total90Plus,
      'total95PlusPeakOutcomes': total95Plus,
      'ninetyPlusPerClass': double.parse(
        (total90Plus / classCount).toStringAsFixed(2),
      ),
      'ninetyFivePlusPerClass': double.parse(
        (total95Plus / classCount).toStringAsFixed(2),
      ),
      'tierSummary': {
        for (final tier in _DraftTier.values) tier.name: tierSummary(tier),
      },
    },
    'players': results,
  };

  print('---DRAFT-CLASS-JSON-START---');
  print(const JsonEncoder.withIndent('  ').convert(output));
  print('---DRAFT-CLASS-JSON-END---');
}
