import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../../player/domain/trait.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/domain/played_game.dart';
import '../../season/domain/season_progress.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_focus.dart';
import '../domain/training_plan.dart';
import '../domain/training_report.dart';

// Tuning constants. Rough first pass, calibrated to land in the
// neighborhood the GM confirmed felt right (not diagnostic-verified the
// way the match engine's pacing was) rather than derived from anything
// more rigorous -- easy to retune in one place once real playthroughs
// say otherwise.
const _kFullWeekMinutes = 50.0; // a real heavy-usage starter's weekly
// average against the match engine's actual output -- not the naive
// "2 games x 35 minutes" ceiling, which real per-game rotation curves
// rarely hit.
const _kMinutesFactorCap = 1.3; // heavy minutes cap slightly above "full".
const _kGapNormalization = 40.0; // gap-to-potential that reads as "wide open".
const _kGrowthScale = 3.2;
const _kDeclineScale = 3.0;
const _kDevelopmentalSlotMultiplier = 1.4;
// A player in one of the 3 individually-coached slots gets this on top of
// whatever the assigned coach's own quality already contributes -- real,
// deliberate extra growth for the one-on-one attention itself, not just
// "maybe that coach happens to roll higher than the head coach." Combined
// with gap-to-potential already rewarding a wide-open player more, a
// high-potential prospect in one of these 3 slots "double dips": her own
// big gap grows the delta, and the individual slot multiplies it again.
// Growth-side only -- declining vets aren't who these slots are for.
const _kIndividualAttentionMultiplier = 1.3;
const _kHighPotentialMultiplier = 1.3;
const _kLowPotentialMultiplier = 0.7;
const _kHighlyCoachableMultiplier = 1.4;
const _kStubbornMultiplier = 0.6;
const _kGymRatGrowthFloor = 0.3; // unconditional, independent of coach.
const _kGymRatDeclineSoftening = 0.5; // "ages more gracefully".
const _kJitterFloor = 0.15; // keeps an at-potential player from a hard 0.
const _kBroadFocusShare = 0.8; // how much of a broad focus's delta goes
// to its own 4 fields, vs. trickling to the other 8.
const _kSpecificFocusShare = 0.7; // how much of a specific-rating focus's
// delta goes to that one field, vs. trickling to the other 11.

/// Seed offset for [runTraining]'s [Random] stream, combined with
/// [Franchise.simulationSeed] and the week being resolved (e.g.
/// `Random(simulationSeed + kTrainingAdvanceSeedOffset + week)`) --
/// same "reseed per resolution unit, don't carry a stream forward"
/// pattern as `kSeasonAdvanceSeedOffset`/`kPostseasonAdvanceSeedOffset`,
/// so a given week's training result is reproducible across a
/// save/reload. Distinct from `kTrainingCoachSeedOffset`, which only
/// seeds one-time coach generation at franchise creation.
const kTrainingAdvanceSeedOffset = 8;

/// What one weekly training cycle produced: the updated [Franchise]
/// (roster with new ratings, `nextTrainingWeek` advanced, the new report
/// appended to history) and the [TrainingReport] itself, for a caller
/// that wants to show it once without re-deriving it from the franchise.
class TrainingAdvance {
  const TrainingAdvance({required this.franchise, required this.report});

  final Franchise franchise;
  final TrainingReport report;
}

/// Resolves training for whatever week just became eligible
/// (`lastFullyCompletedWeek`), or returns `null` if no new week is ready
/// yet -- callers should treat `null` as "nothing to do," not an error.
///
/// Scope, deliberately: only [Franchise.roster] trains here -- the other
/// 19 AI teams' rosters don't age or improve through this system yet.
/// Real follow-up work, not a silent gap; see `0A_Completed.md`.
/// `RosterStatus.reserveInactive` players are skipped entirely (not part
/// of team training activities); active and developmental players both
/// train, with the developmental slot applying its own multiplier.
///
/// The growth/decline math itself (age curve, gap-to-potential, minutes,
/// coach quality, traits, training focus) lives in this file's private
/// helpers -- see the doc comments on [_totalWeeklyDelta] and
/// [_distributeAcrossFields] for the shape of it. `PlayerRatings.potential`
/// itself never moves here -- the decided design allows for that (trades,
/// minutes trends, earned-identity moments), but those all depend on
/// systems (trades, nicknames) that don't exist yet.
TrainingAdvance? runTraining(Random random, Franchise franchise) {
  final week = lastFullyCompletedWeek(franchise.seasonProgress);
  if (week == null || week < franchise.nextTrainingWeek) return null;

  final minutesByPlayerId = _minutesInWeekRange(
    franchise.seasonProgress.playedGames,
    fromWeekInclusive: franchise.nextTrainingWeek,
    toWeekInclusive: week,
  );

  final newRoster = <RosterMembership>[];
  final results = <PlayerGrowthResult>[];

  for (final membership in franchise.roster) {
    if (membership.status == RosterStatus.reserveInactive) {
      newRoster.add(membership);
      continue;
    }

    final player = membership.player;
    final minutesThisWeek = minutesByPlayerId[player.id] ?? 0;
    final (focus, coachDevelopmentRating, isIndividuallySlotted) =
        _effectiveFocusAndCoach(franchise, player.id);

    final newFieldValues = _newFieldValuesFor(
      random,
      player: player,
      minutesThisWeek: minutesThisWeek,
      focus: focus,
      coachDevelopmentRating: coachDevelopmentRating,
      isDevelopmentalSlot: membership.status == RosterStatus.developmental,
      isIndividuallySlotted: isIndividuallySlotted,
    );

    if (newFieldValues.isEmpty) {
      newRoster.add(membership);
      continue;
    }

    var newRatings = player.ratings;
    for (final entry in newFieldValues.entries) {
      newRatings = newRatings.copyWithField(entry.key, entry.value);
    }
    final newPlayer = player.copyWithRatings(newRatings);
    newRoster.add(
      RosterMembership(player: newPlayer, status: membership.status),
    );

    final actualDeltas = {
      for (final entry in newFieldValues.entries)
        entry.key: entry.value - player.ratings.valueOf(entry.key),
    }..removeWhere((_, delta) => delta == 0);
    if (actualDeltas.isNotEmpty) {
      results.add(
        PlayerGrowthResult(
          playerId: player.id,
          fieldDeltas: actualDeltas,
          overallBefore: player.ratings.overall,
          overallAfter: newRatings.overall,
        ),
      );
    }
  }

  final report = TrainingReport(week: week, results: results);
  final updatedFranchise = franchise.copyWithTrainingResult(
    newRoster: newRoster,
    newNextTrainingWeek: week + 1,
    newReport: report,
  );
  return TrainingAdvance(franchise: updatedFranchise, report: report);
}

/// Sums [PlayedGame.minutesByPlayerId] across every game in
/// [fromWeekInclusive, toWeekInclusive] -- the "reps" a player got during
/// the week(s) this training cycle covers. Player IDs outside
/// [Franchise.roster] just accumulate unused entries here; the caller
/// only ever looks up its own roster's ids.
Map<String, double> _minutesInWeekRange(
  List<PlayedGame> playedGames, {
  required int fromWeekInclusive,
  required int toWeekInclusive,
}) {
  final totals = <String, double>{};
  for (final played in playedGames) {
    if (played.game.week < fromWeekInclusive ||
        played.game.week > toWeekInclusive) {
      continue;
    }
    for (final entry in played.minutesByPlayerId.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
  }
  return totals;
}

/// Which focus and coach quality apply to [playerId]: whichever training
/// coach slot has them assigned (that coach's own `developmentRating`),
/// or -- if no coach has them -- the team-wide [TrainingPlan.teamFocus]
/// and the head coach's `CoachStats.development`. The third element is
/// whether [playerId] landed one of the 3 individual slots at all --
/// [_totalWeeklyDelta] applies [_kIndividualAttentionMultiplier] only
/// when it did.
(IndividualTrainingFocus, int, bool) _effectiveFocusAndCoach(
  Franchise franchise,
  String playerId,
) {
  final slots = franchise.trainingPlan.coachSlots;
  for (var i = 0; i < slots.length; i++) {
    if (slots[i].playerId == playerId) {
      return (
        slots[i].focus!,
        franchise.trainingCoaches[i].developmentRating,
        true,
      );
    }
  }
  return (
    IndividualTrainingFocus.broad(franchise.trainingPlan.teamFocus),
    franchise.coach.stats.development,
    false,
  );
}

/// The new (already clamped to [kMinRating]-[kMaxRating]) *value* -- not
/// a delta -- for each field that actually changed this week, ready to
/// hand straight to [PlayerRatings.copyWithField]. Empty if nothing
/// moved. (The caller derives the delta itself, for the report, by
/// diffing against the player's current value.)
Map<PlayerRatingField, int> _newFieldValuesFor(
  Random random, {
  required Player player,
  required double minutesThisWeek,
  required IndividualTrainingFocus focus,
  required int coachDevelopmentRating,
  required bool isDevelopmentalSlot,
  required bool isIndividuallySlotted,
}) {
  final totalDelta = _totalWeeklyDelta(
    player: player,
    minutesThisWeek: minutesThisWeek,
    coachDevelopmentRating: coachDevelopmentRating,
    isDevelopmentalSlot: isDevelopmentalSlot,
    isIndividuallySlotted: isIndividuallySlotted,
  );
  final isDecline = totalDelta < 0;
  final perField = _distributeAcrossFields(
    totalDelta,
    isDecline ? null : focus,
  );

  final newValues = <PlayerRatingField, int>{};
  for (final field in PlayerRatingField.values) {
    final raw = perField[field] ?? 0.0;
    if (raw == 0.0) continue;
    final delta = _roundStochastic(random, raw);
    if (delta == 0) continue;
    final current = player.ratings.valueOf(field);
    final clamped = (current + delta).clamp(kMinRating, kMaxRating);
    if (clamped != current) newValues[field] = clamped;
  }
  return newValues;
}

/// The age curve: 20-23 grows fastest, tapering through 26-27, plateau
/// 27-29, decline starting ~30-32 and steepening through 34 -- the exact
/// bands the GM confirmed. Positive = growth-side multiplier, negative =
/// decline-side, both consumed by [_totalWeeklyDelta].
double _ageCurveFactor(int age) {
  if (age <= 23) return 1.0;
  if (age <= 26) return 0.6;
  if (age <= 29) return 0.0;
  if (age <= 31) return -0.4;
  return -0.8;
}

/// The total field-points this player's ratings move by this week,
/// before being split across individual fields
/// ([_distributeAcrossFields]) -- positive for growth, negative for
/// decline. On the growth side: gap-to-potential (more room = more
/// growth -- the GM's favorite piece of this model), minutes played
/// (reps -- the honest reason a barely-used bench player doesn't
/// develop, and why missed games from injury cost growth for free,
/// without a separate injury-specific case), coach quality (whichever
/// coach is actually working with this player), and traits. Decline is
/// simpler and deliberately not minutes-gated -- aging happens whether
/// you play or not -- and applies the same regardless of who's kept
/// around for locker-room value (no veteran exemptions, the GM's
/// explicit call).
double _totalWeeklyDelta({
  required Player player,
  required double minutesThisWeek,
  required int coachDevelopmentRating,
  required bool isDevelopmentalSlot,
  required bool isIndividuallySlotted,
}) {
  final ageFactor = _ageCurveFactor(player.age);
  final traits = player.traits;

  if (ageFactor < 0) {
    var delta = ageFactor * _kDeclineScale;
    if (traits.contains(Trait.gymRat)) delta *= _kGymRatDeclineSoftening;
    return delta;
  }

  final gap = (player.ratings.potential - player.ratings.overall).clamp(
    0,
    kMaxRating - kMinRating,
  );
  final gapFactor = (gap / _kGapNormalization).clamp(0.0, 1.0);
  final minutesFactor = (minutesThisWeek / _kFullWeekMinutes).clamp(
    0.0,
    _kMinutesFactorCap,
  );

  var coachEffectMultiplier = 1.0;
  if (traits.contains(Trait.highlyCoachable)) {
    coachEffectMultiplier *= _kHighlyCoachableMultiplier;
  }
  if (traits.contains(Trait.stubborn)) {
    coachEffectMultiplier *= _kStubbornMultiplier;
  }
  final coachFactor = coachDevelopmentRating / 50.0;
  final effectiveCoachFactor =
      1.0 + (coachFactor - 1.0) * coachEffectMultiplier;

  var traitMultiplier = 1.0;
  if (traits.contains(Trait.highPotential)) {
    traitMultiplier *= _kHighPotentialMultiplier;
  }
  if (traits.contains(Trait.lowPotential)) {
    traitMultiplier *= _kLowPotentialMultiplier;
  }

  var delta =
      ageFactor *
      gapFactor *
      minutesFactor *
      effectiveCoachFactor *
      traitMultiplier *
      _kGrowthScale;
  if (isDevelopmentalSlot) delta *= _kDevelopmentalSlotMultiplier;
  // Real, deliberate extra growth for one-on-one attention -- combined
  // with gapFactor already rewarding a wide-open player more, a
  // high-potential prospect in one of the 3 individual slots double dips.
  if (isIndividuallySlotted) delta *= _kIndividualAttentionMultiplier;
  if (traits.contains(Trait.gymRat)) delta += _kGymRatGrowthFloor;
  return delta + _kJitterFloor;
}

/// Splits [totalDelta] across the 12 fields according to [focus] -- `null`
/// (always true for decline, `_newFieldValuesFor`'s caller) means an even
/// spread, since aging isn't about what you trained. A broad focus
/// (offense/defense/physical) sends most of the delta to its own 4
/// fields with a trickle to the rest; balanced spreads evenly like
/// decline does; a specific-rating focus concentrates most of it on one
/// field.
Map<PlayerRatingField, double> _distributeAcrossFields(
  double totalDelta,
  IndividualTrainingFocus? focus,
) {
  if (focus == null || focus.broadFocus == TrainingFocus.balanced) {
    return {
      for (final field in PlayerRatingField.values)
        field: totalDelta / PlayerRatingField.values.length,
    };
  }

  if (focus.isSpecific) {
    final target = focus.specificRating!;
    final others = PlayerRatingField.values.where((f) => f != target);
    final result = <PlayerRatingField, double>{
      target: totalDelta * _kSpecificFocusShare,
    };
    final remainder = totalDelta * (1 - _kSpecificFocusShare) / others.length;
    for (final field in others) {
      result[field] = remainder;
    }
    return result;
  }

  final focusedFields = switch (focus.broadFocus!) {
    TrainingFocus.offense => kOffenseFields,
    TrainingFocus.defense => kDefenseFields,
    TrainingFocus.physical => kPhysicalFields,
    TrainingFocus.balanced => throw StateError('handled above'),
  };
  final otherFields = PlayerRatingField.values.where(
    (f) => !focusedFields.contains(f),
  );
  final result = <PlayerRatingField, double>{};
  final focusedShare = totalDelta * _kBroadFocusShare / focusedFields.length;
  final otherShare = totalDelta * (1 - _kBroadFocusShare) / otherFields.length;
  for (final field in focusedFields) {
    result[field] = focusedShare;
  }
  for (final field in otherFields) {
    result[field] = otherShare;
  }
  return result;
}

/// Rounds [value] to an integer stochastically rather than always
/// rounding down/to-nearest -- a weekly delta of e.g. 0.3 becomes +1
/// about 30% of the time and 0 the rest, so small week-to-week growth
/// isn't silently lost to rounding while still landing on the right
/// total over many weeks. Handles negative values (decline) the same
/// way, symmetrically.
int _roundStochastic(Random random, double value) {
  final sign = value < 0 ? -1 : 1;
  final magnitude = value.abs();
  final wholePart = magnitude.floor();
  final fractionalPart = magnitude - wholePart;
  final extra = random.nextDouble() < fractionalPart ? 1 : 0;
  return sign * (wholePart + extra);
}
