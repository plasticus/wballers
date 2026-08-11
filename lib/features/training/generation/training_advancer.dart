import 'dart:math';

import '../../../core/ratings/rating_scale.dart';
import '../../coach/domain/coach_stats.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
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
// Cut from the original 3.0 (2026-08-10, TODO.md item 1: "aging curve too
// punishing in-season" -- a real GM complaint, not a hypothetical one).
// The original scale, over a full season's ~18-21 training-eligible weeks
// (`lastFullyCompletedWeek` only fires on weeks with games -- preseason +
// 17 regular-season weeks, plus up to 3 postseason weeks for a team that
// goes all the way), worked out to roughly -22 to -50 total rating points
// for a veteran across the 30-34 age bands -- an entire season's worth of
// decline concentrated into dozens of small, alarming weekly dips. 0.5
// keeps the same age-curve shape (`_ageCurveFactor`'s bands are the GM's
// own confirmed shape, untouched here) but brings the in-season total down
// to roughly -4 to -8 over a season -- felt, not brutal. The rest of a
// veteran's yearly decline now happens as a one-time lump at season's end
// instead (`_kOffSeasonDeclineScale`, below) -- see `resolveSeasonEndAging`.
const _kDeclineScale = 0.5;
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
// The one-time off-season lump's own scale (`resolveSeasonEndAging`) --
// deliberately much bigger than `_kDeclineScale` since it's applied once a
// season, not once a week. Reuses `_ageCurveFactor`'s same decline bands
// (30-31 at -0.4, 32-34 at -0.8), so 30-31 loses ~5 total and 32-34 loses
// ~10 -- on top of the softer in-season total, a 32-34-year-old's full
// season (in-season + off-season) now lands around -16 to -18, well
// under the old system's -43 to -50, with most of it landing as one
// clean "the off-season caught up with her" event rather than trickling
// out week by week.
const _kOffSeasonDeclineScale = 12.5;
const _kBroadFocusShare = 0.8; // how much of a broad focus's delta goes
// to its own 4 fields, vs. trickling to the other 8.
const _kSpecificFocusShare = 0.7; // how much of a specific-rating focus's
// delta goes to that one field, vs. trickling to the other 11.

/// Seed offset for [runTraining]'s [Random] stream, combined with
/// [Franchise.seasonSeed] and the week being resolved (e.g.
/// `Random(franchise.seasonSeed + kTrainingAdvanceSeedOffset + week)`) --
/// same "reseed per resolution unit, don't carry a stream forward"
/// pattern as `kSeasonAdvanceSeedOffset`/`kPostseasonAdvanceSeedOffset`,
/// so a given week's training result is reproducible across a
/// save/reload, and [Franchise.seasonSeed] rather than
/// [Franchise.simulationSeed] directly so a second season's week 1
/// doesn't reseed identically to the first's. Distinct from
/// `kTrainingCoachSeedOffset`, which only seeds one-time coach generation
/// at franchise creation.
const kTrainingAdvanceSeedOffset = 8;

/// Seed offset for [resolveSeasonEndAging]'s [Random] stream -- offset 9
/// was the one gap left in the existing seed-offset numbering (coach=0,
/// roster=1, league draw=2, league AI rosters=3, season schedule=4,
/// game-day advancement=5, postseason=6, training coaches=7, training
/// advancement=8, market previews=10-11, free-agent pool=12), reused here
/// rather than tacking a new number on the end.
const kSeasonEndAgingSeedOffset = 9;

/// Seed offset for [resolveAiTeamSeasonTraining]'s [Random] stream --
/// next free number after `draft_generator.dart`'s
/// `kDraftOrderSeedOffset` (13).
const kAiTeamTrainingSeedOffset = 14;

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
/// Scope, deliberately: only [Franchise.roster] trains here, live,
/// week by week -- the 19 AI teams' rosters train too, just not through
/// this function; see [resolveAiTeamSeasonTraining] for why their whole
/// season resolves as one lump instead. `RosterStatus.reserveInactive`
/// players are skipped entirely (not part of team training activities);
/// active and developmental players both train, with the developmental
/// slot applying its own multiplier.
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

    final (newPlayer, actualDeltas) = _applyFieldValues(player, newFieldValues);
    newRoster.add(
      RosterMembership(player: newPlayer, status: membership.status),
    );

    if (actualDeltas.isNotEmpty) {
      results.add(
        PlayerGrowthResult(
          playerId: player.id,
          fieldDeltas: actualDeltas,
          overallBefore: player.ratings.overall,
          overallAfter: newPlayer.ratings.overall,
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

/// Applies [newFieldValues] (already-clamped new values, e.g. from
/// [_newFieldValuesFor]) to [player], returning the updated player and
/// the actual per-field deltas that resulted -- shared by [runTraining]'s
/// weekly loop and [resolveSeasonEndAging]'s lump pass, which otherwise
/// duplicated this exact "apply the map, diff against the original,
/// hand back both" dance.
(Player, Map<PlayerRatingField, int>) _applyFieldValues(
  Player player,
  Map<PlayerRatingField, int> newFieldValues,
) {
  var newRatings = player.ratings;
  for (final entry in newFieldValues.entries) {
    newRatings = newRatings.copyWithField(entry.key, entry.value);
  }
  final newPlayer = player.copyWithRatings(newRatings);
  final actualDeltas = {
    for (final entry in newFieldValues.entries)
      entry.key: entry.value - player.ratings.valueOf(entry.key),
  }..removeWhere((_, delta) => delta == 0);
  return (newPlayer, actualDeltas);
}

/// What one season-end aging resolution produced: the updated [Franchise]
/// (roster with the lump decline applied) and the [results] themselves,
/// for a caller that wants to show or aggregate them without re-deriving
/// anything -- same shape as [TrainingAdvance], deliberately not reusing
/// [TrainingReport] itself (that type means "one schedule week's worth of
/// minutes-and-coaching training," and this isn't that -- see
/// [resolveSeasonEndAging]'s own doc comment).
class SeasonEndAgingAdvance {
  const SeasonEndAgingAdvance({required this.franchise, required this.results});

  final Franchise franchise;
  final List<PlayerGrowthResult> results;
}

/// Applies a one-time "off-season" decline lump to every aging veteran on
/// [franchise]'s roster -- the other half of `_kDeclineScale`'s softened
/// in-season weekly decay (TODO.md item 1: "smaller week-to-week veteran
/// decay during the season, with more of the decline concentrated in the
/// off-season instead"). Meant to be called exactly once, right when a
/// season's postseason bracket finishes
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`,
/// which already guards against re-resolving an already-played
/// postseason) -- there's no real multi-season flow yet
/// (`0B_Planned.md`), so "the off-season" is, for now, just that one
/// moment a season wraps up, not an actual calendar phase a GM plays
/// through.
///
/// Same scope as [runTraining]: [RosterStatus.reserveInactive] players
/// are skipped entirely, and only [_ageCurveFactor] matters -- no
/// gap-to-potential, minutes, or coach-quality inputs, since those are
/// growth-side concepts that don't apply here, same reasoning
/// [_totalWeeklyDelta]'s own doc comment gives for why weekly decline
/// itself is minutes-gate-free. Growing/plateaued players
/// ([_ageCurveFactor] `>= 0`) get nothing here -- this is specifically
/// the veteran-decay half of the yearly budget, not a second growth pass.
SeasonEndAgingAdvance resolveSeasonEndAging(
  Random random,
  Franchise franchise,
) {
  final newRoster = <RosterMembership>[];
  final results = <PlayerGrowthResult>[];

  for (final membership in franchise.roster) {
    if (membership.status == RosterStatus.reserveInactive) {
      newRoster.add(membership);
      continue;
    }

    final player = membership.player;
    final ageFactor = _ageCurveFactor(player.age);
    if (ageFactor >= 0) {
      newRoster.add(membership);
      continue;
    }

    var totalDelta = ageFactor * _kOffSeasonDeclineScale;
    if (player.traits.contains(Trait.gymRat)) {
      totalDelta *= _kGymRatDeclineSoftening;
    }

    final perField = _distributeAcrossFields(totalDelta, null);
    final newFieldValues = <PlayerRatingField, int>{};
    for (final field in PlayerRatingField.values) {
      final raw = perField[field] ?? 0.0;
      if (raw == 0.0) continue;
      final delta = _roundStochastic(random, raw);
      if (delta == 0) continue;
      final current = player.ratings.valueOf(field);
      final clamped = (current + delta).clamp(kMinRating, kMaxRating);
      if (clamped != current) newFieldValues[field] = clamped;
    }

    if (newFieldValues.isEmpty) {
      newRoster.add(membership);
      continue;
    }

    final (newPlayer, actualDeltas) = _applyFieldValues(player, newFieldValues);
    newRoster.add(
      RosterMembership(player: newPlayer, status: membership.status),
    );
    if (actualDeltas.isNotEmpty) {
      results.add(
        PlayerGrowthResult(
          playerId: player.id,
          fieldDeltas: actualDeltas,
          overallBefore: player.ratings.overall,
          overallAfter: newPlayer.ratings.overall,
        ),
      );
    }
  }

  return SeasonEndAgingAdvance(
    franchise: franchise.copyWithSeasonEndAging(
      newRoster: newRoster,
      newResults: results,
    ),
    results: results,
  );
}

/// The updated [League] a full season's worth of AI-team training
/// produces -- see [resolveAiTeamSeasonTraining]. Deliberately no
/// per-player [PlayerGrowthResult] list alongside it, unlike
/// [TrainingAdvance]/[SeasonEndAgingAdvance] -- nothing surfaces this to
/// the GM (there's no mail item, report, or Dashboard card for a roster
/// they don't manage), so there's nothing that needs one.
class AiTeamTrainingAdvance {
  const AiTeamTrainingAdvance({required this.league});

  final League league;
}

/// Resolves an entire season's worth of training for every AI team in
/// [franchise]'s league, all in one lump -- a direct GM design call
/// (2026-08-10, TODO.md item 8, resolving the fairness question the item
/// itself raised: every AI roster sitting static all season while only
/// the GM's own team trains): "I'd like for all AI training to occur at
/// the end of the season, after the players[' own training resolves],
/// in one big lump. Do similar numbers as they'd get week to week,
/// just... all at the end." Meant to be called exactly once per season,
/// right alongside [resolveSeasonEndAging] -- same call site
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`),
/// same idempotency guard.
///
/// "Similar numbers as they'd get week to week" rules out the tempting
/// shortcut of summing a whole season's minutes into one combined delta
/// -- [_kMinutesFactorCap] caps a single delta's minutes credit at 1.3x
/// one week's worth no matter how many real weeks it spans, so a
/// mega-week calculation would badly *undercount* growth relative to
/// what actually resolving week by week produces. Instead, this replays
/// [_newFieldValuesFor] once per distinct scheduled week (preseason
/// through the postseason, whatever [franchise.seasonProgress] actually
/// has played games for) -- the exact same formula [runTraining] uses
/// for the GM's own roster, with that week's own minutes only, letting
/// each week's growth compound into the next exactly like a real season
/// would. The only real difference from the GM's own path is *when* the
/// result becomes visible (all at once, at the end) rather than *how*
/// it's computed.
///
/// AI teams have no [TrainingPlan]/individual coach slots to read (no GM
/// exists to set one) and no generated head coach of their own --
/// [AiTeamRoster] only ever carried identity + roster, nothing like
/// [Franchise.coach]. Every AI player trains under
/// [TrainingFocus.balanced] at a flat [CoachStats.neutral] development
/// rating (50, [_totalWeeklyDelta]'s exact "no boost, no penalty"
/// midpoint) -- the same fallback the GM's own roster already gets for
/// any player nobody individually assigned, just without a head coach to
/// vary it team to team. `RosterStatus.reserveInactive` players are
/// skipped, same as [runTraining]/[resolveSeasonEndAging].
AiTeamTrainingAdvance resolveAiTeamSeasonTraining(
  Random random,
  Franchise franchise,
) {
  final playedGames = franchise.seasonProgress.playedGames;
  final weeks = {for (final played in playedGames) played.game.week}.toList()
    ..sort();

  const focus = IndividualTrainingFocus.broad(TrainingFocus.balanced);

  final newAiTeams = <AiTeamRoster>[];
  for (final aiTeam in franchise.league.aiTeams) {
    var roster = aiTeam.roster;
    for (final week in weeks) {
      final minutesThisWeek = _minutesInWeekRange(
        playedGames,
        fromWeekInclusive: week,
        toWeekInclusive: week,
      );

      final newRoster = <RosterMembership>[];
      for (final membership in roster) {
        if (membership.status == RosterStatus.reserveInactive) {
          newRoster.add(membership);
          continue;
        }
        final player = membership.player;
        final newFieldValues = _newFieldValuesFor(
          random,
          player: player,
          minutesThisWeek: minutesThisWeek[player.id] ?? 0,
          focus: focus,
          coachDevelopmentRating: CoachStats.neutral.development,
          isDevelopmentalSlot: membership.status == RosterStatus.developmental,
          isIndividuallySlotted: false,
        );
        if (newFieldValues.isEmpty) {
          newRoster.add(membership);
          continue;
        }
        final (newPlayer, _) = _applyFieldValues(player, newFieldValues);
        newRoster.add(
          RosterMembership(player: newPlayer, status: membership.status),
        );
      }
      roster = newRoster;
    }
    newAiTeams.add(AiTeamRoster(team: aiTeam.team, roster: roster));
  }

  return AiTeamTrainingAdvance(league: League(aiTeams: newAiTeams));
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

/// Which focus applies to [playerId]: whichever training coach slot has
/// them assigned, or -- if no coach has them -- the team-wide
/// [TrainingPlan.teamFocus]. Coach *quality* is always the head coach's
/// own `CoachStats.development`, individually-slotted or not -- the 3
/// training coaches carry no rating of their own to use instead
/// (`TrainingCoach`'s own doc comment: a direct GM design call, "they
/// should all simply be an extension of the head coach's capabilities").
/// The third element is whether [playerId] landed one of the 3
/// individual slots at all -- [_totalWeeklyDelta] applies
/// [_kIndividualAttentionMultiplier] only when it did, entirely
/// independent of coach quality.
(IndividualTrainingFocus, int, bool) _effectiveFocusAndCoach(
  Franchise franchise,
  String playerId,
) {
  final headCoachDevelopment = franchise.coach.stats.development;
  final slots = franchise.trainingPlan.coachSlots;
  for (var i = 0; i < slots.length; i++) {
    if (slots[i].playerId == playerId) {
      return (slots[i].focus!, headCoachDevelopment, true);
    }
  }
  return (
    IndividualTrainingFocus.broad(franchise.trainingPlan.teamFocus),
    headCoachDevelopment,
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
