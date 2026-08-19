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
// keeps the same shape of curve `_ageCurveFactor` applies (its own band
// *values* were re-picked later, see `_kOffSeasonGrowthScale`'s doc
// comment below -- this scale still applies to whatever the curve
// currently returns) but brings the in-season total down to roughly -4
// to -8 over a season -- felt, not brutal. The rest of a
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
// A bye week (the schedule packer doesn't guarantee a team a game every
// week, and a Continental Cup elimination round only includes surviving
// teams -- `season_schedule_generator.dart`) used to credit real 0
// minutes, which fully stalled growth for the week since growth is
// minutes-gated (`_totalWeeklyDelta`'s `minutesFactor`) while decline
// isn't. A direct GM ask (2026-08-15): "players should all train like
// they played 30 minutes" on a day the team doesn't play, rather than
// silently losing the week. 30, not `_kFullWeekMinutes` (50) -- a
// deliberately modest "still got some run in practice" credit, not a
// full game's worth.
const _kAssumedByeWeekMinutes = 30.0;
// A developmental-slot player never suits up for a real game at all
// (`franchise_rosters.dart`'s `_activePlayers` filter) -- her real
// minutes are always 0, which used to fully zero out growth's
// minutes-gated term regardless of `_kDevelopmentalSlotMultiplier`
// below (1.4 x 0 is still 0, so that multiplier was dead code in
// practice, not just a smaller bonus than intended). Fixed the same
// way `_kAssumedByeWeekMinutes` fixed the identical problem for a bye
// week: credit assumed practice minutes instead of the always-zero
// real ones. 40 (2026-08-19, a direct GM spec, after discussing the
// engine's actual minutes scale): roughly a real bench rotation
// player's per-game workload across a normal 2-games week, deliberately
// short of `_kFullWeekMinutes` (50, a heavy-usage starter's week) --
// "better than [bench] slot #10," genuinely good growth, but a real
// prospect still develops faster actually starting. The GM's own
// framing for why this is a real tradeoff, not a strictly-better
// option: only `kMaxDevelopmentalRosterSpots` (2) exist, so eventually
// a real prospect has to earn her way into the lineup instead.
const _kAssumedDevelopmentalWeekMinutes = 40.0;
// The one-time off-season lump's own scale (`resolveSeasonEndAging`) --
// deliberately much bigger than `_kDeclineScale` since it's applied once a
// season, not once a week. Whatever `_ageCurveFactor` returns for a given
// decline age gets multiplied by this once, at season's end, on top of
// that same age's softer in-season weekly total -- most of a veteran's
// yearly decline lands as one clean "the off-season caught up with her"
// event rather than trickling out week by week. (Original calibration
// note, now superseded by the growth-curve study's re-picked bands below:
// the old 30-31/32-34 bands worked out to roughly -5/-10 here.)
const _kOffSeasonDeclineScale = 12.5;
// Growth-curve study, part 1 (2026-08-12, `tool/aging_curve_diagnostic.dart`,
// https://claude.ai/code/artifact/31656bc8-19db-4724-85be-0fed26e98f63): the
// GM re-picked `_ageCurveFactor`'s own bands (below) after seeing real
// simulated career data, not vibes -- peak was landing at 29, not the 26
// the GM expected, and the 30-34 decline read as too gentle (a player
// stayed a legitimate rotation piece deep into her 30s, and the "declined
// 10+ from peak" retirement rule didn't fire until 37, a year before
// mandatory retirement at 38). The new bands move peak to 27 at the *same*
// peak overall and the retirement trigger to 35, at zero cost to how good
// a player gets.
//
// Growth-curve study, parts 2-3 (same session, same diagnostic file): with
// the new curve locked in, the next ask -- "even the best current case
// only reaches 87 OVR for a 70/99 rookie... this game needs a few players
// in the upper 90s" -- surfaced that `gapFactor`'s old linear falloff
// (below, in [_totalWeeklyDelta]) meant growth nearly stalled once a
// player was 10-15 points off her potential, long before the age curve's
// own growth window closed. 4 additive levers, all validated in the
// diagnostic before landing here, close that gap without letting every
// rookie become a superstar by accident:
const _kRookieSurgeMultiplier = 1.35; // growth lever 1: a true rookie's
// first 2 pro seasons grow faster than a same-age veteran's -- keyed to
// [Player.yearsOfService], not age, so a late bloomer still gets it and a
// veteran in her 4th season at the same age band doesn't.
const _kRookieSeasons = 2;
const _kGapConcavityExponent = 0.75; // growth lever 2: `gapFactor` becomes
// concave (exponent < 1) instead of linear -- still hits exactly 0 once a
// player is genuinely at her potential (nothing here lets her exceed it,
// beyond the unconditional `_kJitterFloor` nudge below), but keeps
// meaningful growth alive through the last stretch instead of
// asymptotically stalling out short of it.
const _kOffSeasonGrowthScale = 8.0; // growth lever 3: mirrors
// `_kOffSeasonDeclineScale` above, but for the growth side -- a real
// off-season training block, not just in-season reps. The diagnostic's
// 100-rookie population study is what surfaced that even a
// fully-invested prospect was landing 1-2 points short of ever actually
// closing her gap without this.
const _kBreakoutChanceSlotted = 0.06; // growth lever 4: once a season,
// independent of everything else, a small chance of a big one-season
// growth spike -- "she figures something out nobody expected this
// summer." Deliberately more likely for a player who *isn't* one of the 3
// individually-coached slots (the GM's own framing: "sometimes players
// that don't get that individual coaching should have a chance of
// sneaking up on you") -- the already-favored 3 don't need the extra
// lottery ticket as much. Rolled once per season, not per week -- see
// [_isBreakoutSeason].
const _kBreakoutChanceUnslotted = 0.10;
const _kBreakoutMultiplier = 3.0;
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

/// Seed offset for [resolveAiTeamSeasonEndAging]'s [Random] stream -- a
/// separate stream from [kSeasonEndAgingSeedOffset] (the GM's own roster)
/// entirely, not just a different offset on the same one, so a save's own
/// veteran-decline rolls can never shift because of what the AI-team pass
/// happened to roll. Next free number after
/// `coach_free_agency_advancer.dart`'s `kCoachFreeAgencySeedOffset` (16).
const kAiTeamSeasonEndAgingSeedOffset = 17;

/// Seed offset for [_isBreakoutSeason]'s per-player, per-season roll --
/// next free number after [kAiTeamSeasonEndAgingSeedOffset] (17).
/// Deliberately *not* combined with the per-week [Random] stream every
/// other seed offset in this file reseeds ([kTrainingAdvanceSeedOffset]
/// et al.) -- a breakout is a once-a-season thing, and [runTraining] gets
/// called once per newly-completed week, sometimes several times across
/// one season. Seeding straight off [Franchise.seasonSeed] plus a stable
/// hash of the player's own id (see [_isBreakoutSeason]) instead gives
/// the same answer for the same player all season long, no matter which
/// week is being resolved when it's asked.
const kBreakoutSeedOffset = 18;

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
/// slot applying its own multiplier and its own assumed practice-minutes
/// credit (`_kAssumedDevelopmentalWeekMinutes`) -- until 2026-08-19 the
/// multiplier alone was dead code in practice, since it only ever
/// multiplied the always-zero real-minutes term a player who never
/// suits up naturally produces.
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
    teamAbbreviation: franchise.team.abbreviation,
    rosterPlayerIds: [for (final m in franchise.roster) m.player.id],
    developmentalPlayerIds: {
      for (final m in franchise.roster)
        if (m.status == RosterStatus.developmental) m.player.id,
    },
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
    final isBreakoutSeason = _isBreakoutSeason(
      seasonSeed: franchise.seasonSeed,
      playerId: player.id,
      individuallySlotted: isIndividuallySlotted,
    );

    final newFieldValues = _newFieldValuesFor(
      random,
      player: player,
      minutesThisWeek: minutesThisWeek,
      focus: focus,
      coachDevelopmentRating: coachDevelopmentRating,
      isDevelopmentalSlot: membership.status == RosterStatus.developmental,
      isIndividuallySlotted: isIndividuallySlotted,
      isBreakoutSeason: isBreakoutSeason,
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

  final report = TrainingReport(
    fromWeek: franchise.nextTrainingWeek,
    week: week,
    results: results,
  );
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
/// (roster with the lump decline-or-growth applied) and the [results]
/// themselves,
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

/// Computes this off-season's lump for one [player] -- the shared core
/// [resolveSeasonEndAging] (the GM's own roster) and
/// [resolveAiTeamSeasonEndAging] (every AI roster) both apply. One-time
/// per season, on top of whatever [runTraining]'s weekly cycles already
/// did: a decline lump for an aging veteran ([_ageCurveFactor] `< 0`,
/// `_kOffSeasonDeclineScale`), or growth lever 3's off-season training
/// lump for a still-growing player (`_kOffSeasonGrowthScale`'s own doc
/// comment) -- never both, since [_ageCurveFactor] can't be both signs at
/// once. Returns [player] unchanged (and an empty delta map) when every
/// rolled delta happens to round to zero.
(Player, Map<PlayerRatingField, int>) _seasonEndAdjustedPlayer(
  Random random,
  Player player,
) {
  final ageFactor = _ageCurveFactor(player.age);
  double totalDelta;
  if (ageFactor < 0) {
    totalDelta = ageFactor * _kOffSeasonDeclineScale;
    if (player.traits.contains(Trait.gymRat)) {
      totalDelta *= _kGymRatDeclineSoftening;
    }
  } else {
    totalDelta = ageFactor * _kOffSeasonGrowthScale;
  }
  if (totalDelta == 0) return (player, const {});

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

  if (newFieldValues.isEmpty) return (player, const {});
  return _applyFieldValues(player, newFieldValues);
}

/// Applies a one-time "off-season" lump to every player on [franchise]'s
/// roster -- a decline lump for an aging veteran (the other half of
/// `_kDeclineScale`'s softened in-season weekly decay, TODO.md item 1:
/// "smaller week-to-week veteran decay during the season, with more of
/// the decline concentrated in the off-season instead") or growth lever
/// 3's off-season training lump for a still-growing one
/// (`_kOffSeasonGrowthScale`'s own doc comment). Meant to be called
/// exactly once, right when a season's postseason bracket finishes
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`,
/// which already guards against re-resolving an already-played
/// postseason) -- there's no real multi-season flow yet
/// (`0B_Planned.md`), so "the off-season" is, for now, just that one
/// moment a season wraps up, not an actual calendar phase a GM plays
/// through.
///
/// Same scope as [runTraining]: [RosterStatus.reserveInactive] players
/// are skipped entirely -- no gap-to-potential, minutes, or coach-quality
/// inputs on the decline side, same reasoning [_totalWeeklyDelta]'s own
/// doc comment gives for why weekly decline itself is minutes-gate-free
/// (the growth-side lump also skips those -- flat per the age curve
/// alone, not gap-scaled, same as [_seasonEndAdjustedPlayer]'s own doc
/// comment). The actual per-player math is [_seasonEndAdjustedPlayer]'s.
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
    final (newPlayer, actualDeltas) = _seasonEndAdjustedPlayer(random, player);
    if (actualDeltas.isEmpty) {
      newRoster.add(membership);
      continue;
    }

    newRoster.add(
      RosterMembership(player: newPlayer, status: membership.status),
    );
    results.add(
      PlayerGrowthResult(
        playerId: player.id,
        fieldDeltas: actualDeltas,
        overallBefore: player.ratings.overall,
        overallAfter: newPlayer.ratings.overall,
      ),
    );
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
        teamAbbreviation: aiTeam.team.abbreviation,
        rosterPlayerIds: [for (final m in roster) m.player.id],
        developmentalPlayerIds: {
          for (final m in roster)
            if (m.status == RosterStatus.developmental) m.player.id,
        },
      );

      final newRoster = <RosterMembership>[];
      for (final membership in roster) {
        if (membership.status == RosterStatus.reserveInactive) {
          newRoster.add(membership);
          continue;
        }
        final player = membership.player;
        final isBreakoutSeason = _isBreakoutSeason(
          seasonSeed: franchise.seasonSeed,
          playerId: player.id,
          individuallySlotted: false,
        );
        final newFieldValues = _newFieldValuesFor(
          random,
          player: player,
          minutesThisWeek: minutesThisWeek[player.id] ?? 0,
          focus: focus,
          coachDevelopmentRating: CoachStats.neutral.development,
          isDevelopmentalSlot: membership.status == RosterStatus.developmental,
          isIndividuallySlotted: false,
          isBreakoutSeason: isBreakoutSeason,
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
    newAiTeams.add(aiTeam.copyWithRoster(roster));
  }

  return AiTeamTrainingAdvance(league: League(aiTeams: newAiTeams));
}

/// The updated [League] a full season's worth of AI-team off-season
/// lumps (decline or growth) produces -- see [resolveAiTeamSeasonEndAging].
/// No per-player
/// [PlayerGrowthResult] list, same reasoning [AiTeamTrainingAdvance]'s
/// own doc comment gives -- nothing surfaces this to the GM.
class AiTeamAgingAdvance {
  const AiTeamAgingAdvance({required this.league});

  final League league;
}

/// Applies [resolveSeasonEndAging]'s same one-time off-season decline
/// lump to every AI team's roster, not just the GM's own --
/// `0D_Season_2_Roadmap.md`'s Aging & roster churn stage (2026-08-11):
/// AI veterans got `resolveAiTeamSeasonTraining`'s growth already but
/// never this decline half, so an AI roster's older players could only
/// ever get better, never worse. Meant to be called exactly once per
/// season, alongside every other season-end resolution -- same call site
/// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`),
/// same idempotency guard. [_seasonEndAdjustedPlayer] is the shared
/// per-player math (decline lump for a veteran, growth lever 3's
/// off-season lump for a still-growing player); [RosterStatus.reserveInactive]
/// players are skipped, same scope as [resolveSeasonEndAging].
AiTeamAgingAdvance resolveAiTeamSeasonEndAging(
  Random random,
  Franchise franchise,
) {
  final newAiTeams = <AiTeamRoster>[];
  for (final aiTeam in franchise.league.aiTeams) {
    final newRoster = <RosterMembership>[];
    for (final membership in aiTeam.roster) {
      if (membership.status == RosterStatus.reserveInactive) {
        newRoster.add(membership);
        continue;
      }
      final (newPlayer, actualDeltas) = _seasonEndAdjustedPlayer(
        random,
        membership.player,
      );
      newRoster.add(
        actualDeltas.isEmpty
            ? membership
            : RosterMembership(player: newPlayer, status: membership.status),
      );
    }
    newAiTeams.add(aiTeam.copyWithRoster(newRoster));
  }
  return AiTeamAgingAdvance(league: League(aiTeams: newAiTeams));
}

/// Sums [PlayedGame.minutesByPlayerId] across every game in
/// [fromWeekInclusive, toWeekInclusive] -- the "reps" a player got during
/// the week(s) this training cycle covers. Player IDs outside
/// [Franchise.roster] just accumulate unused entries here; the caller
/// only ever looks up its own roster's ids.
///
/// Any week in range where the league played games but [teamAbbreviation]
/// itself didn't (a bye -- see [_kAssumedByeWeekMinutes]'s own doc
/// comment) credits every *non*-developmental id in [rosterPlayerIds]
/// [_kAssumedByeWeekMinutes], on top of whatever real minutes they
/// separately earned elsewhere in the range -- a team can't be "on bye"
/// for part of a multi-week range and have real minutes for the rest, so
/// this only ever adds to, never overrides, the real sum above.
///
/// [developmentalPlayerIds] (a subset of [rosterPlayerIds]) instead get
/// [_kAssumedDevelopmentalWeekMinutes] every league-training-eligible
/// week in range, bye or not -- see that constant's own doc comment for
/// why a developmental player's *real* minutes are always exactly 0
/// regardless (she never suits up either way), and never both credits
/// in the same week (developmental status, where it applies, always
/// wins over the plain bye credit -- a developmental player isn't
/// "extra" on top of ordinary bye-week practice, she trains this way
/// every week she's slotted).
Map<String, double> _minutesInWeekRange(
  List<PlayedGame> playedGames, {
  required int fromWeekInclusive,
  required int toWeekInclusive,
  required String teamAbbreviation,
  required Iterable<String> rosterPlayerIds,
  required Set<String> developmentalPlayerIds,
}) {
  final totals = <String, double>{};
  final leagueWeeksWithGames = <int>{};
  final weeksTeamPlayed = <int>{};
  for (final played in playedGames) {
    if (played.game.week < fromWeekInclusive ||
        played.game.week > toWeekInclusive) {
      continue;
    }
    leagueWeeksWithGames.add(played.game.week);
    if (played.game.homeTeamAbbreviation == teamAbbreviation ||
        played.game.awayTeamAbbreviation == teamAbbreviation) {
      weeksTeamPlayed.add(played.game.week);
    }
    for (final entry in played.minutesByPlayerId.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
  }

  for (var week = fromWeekInclusive; week <= toWeekInclusive; week++) {
    if (!leagueWeeksWithGames.contains(week)) continue;
    final isBye = !weeksTeamPlayed.contains(week);
    for (final playerId in rosterPlayerIds) {
      if (developmentalPlayerIds.contains(playerId)) {
        totals[playerId] =
            (totals[playerId] ?? 0) + _kAssumedDevelopmentalWeekMinutes;
      } else if (isBye) {
        totals[playerId] = (totals[playerId] ?? 0) + _kAssumedByeWeekMinutes;
      }
    }
  }

  return totals;
}

/// A stable, cross-run-deterministic hash of a player id string -- used
/// to seed [_isBreakoutSeason] instead of Dart's built-in `String.hashCode`
/// (not a documented-stable algorithm across Dart/Flutter versions, and
/// this codebase's own seeded-generation invariants all lean on exact
/// reproducibility -- see every `kXSeedOffset`'s own doc comment).
int _stableStringHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = (31 * hash + codeUnit) & 0x7fffffff;
  }
  return hash;
}

/// Whether [playerId] rolled a breakout for the *current* season --
/// growth lever 4, see `_kBreakoutChanceSlotted`'s doc comment. Seeded
/// off [Franchise.seasonSeed] plus [kBreakoutSeedOffset] plus a stable
/// hash of the player's own id, deliberately *not* the per-week [Random]
/// stream [runTraining]/[resolveAiTeamSeasonTraining] otherwise use --
/// this needs to answer the same way for the same player all season,
/// regardless of which week is being resolved when it's asked (see
/// [kBreakoutSeedOffset]'s own doc comment for why).
bool _isBreakoutSeason({
  required int seasonSeed,
  required String playerId,
  required bool individuallySlotted,
}) {
  final roll = Random(
    seasonSeed + kBreakoutSeedOffset + _stableStringHash(playerId),
  ).nextDouble();
  final chance = individuallySlotted
      ? _kBreakoutChanceSlotted
      : _kBreakoutChanceUnslotted;
  return roll < chance;
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
  required bool isBreakoutSeason,
}) {
  final totalDelta = _totalWeeklyDelta(
    player: player,
    minutesThisWeek: minutesThisWeek,
    coachDevelopmentRating: coachDevelopmentRating,
    isDevelopmentalSlot: isDevelopmentalSlot,
    isIndividuallySlotted: isIndividuallySlotted,
    isBreakoutSeason: isBreakoutSeason,
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

/// The age curve: 20-23 grows fastest, tapering through 24-26, a single
/// plateau year at 27, decline starting at 28 and steepening through 33+
/// -- the "moderate" proposal from the growth-curve diagnostic's part 1
/// (see `_kOffSeasonGrowthScale`'s own doc comment above for the full
/// story), replacing the original 27-29 3-year plateau and gentler
/// 30-34 decline. Positive = growth-side multiplier, negative =
/// decline-side, both consumed by [_totalWeeklyDelta]; never exactly 0
/// under these bands (the old plateau's `0.0` band is gone -- a player is
/// always either still growing or already declining, if only a little).
double _ageCurveFactor(int age) {
  if (age <= 23) return 1.0;
  if (age <= 26) return 0.6;
  if (age <= 27) return 0.2;
  if (age <= 29) return -0.3;
  if (age <= 32) return -0.7;
  return -1.3;
}

/// The total field-points this player's ratings move by this week,
/// before being split across individual fields
/// ([_distributeAcrossFields]) -- positive for growth, negative for
/// decline. On the growth side: gap-to-potential (more room = more
/// growth -- the GM's favorite piece of this model), minutes played
/// (reps -- the honest reason a barely-used bench player doesn't
/// develop, and why missed games from injury cost growth for free,
/// without a separate injury-specific case), coach quality (whichever
/// coach is actually working with this player), and traits, plus the 4
/// growth-curve-study levers stacked on top (rookie surge, concave
/// gap-to-potential falloff, individual-attention and breakout
/// multipliers -- see `_kRookieSurgeMultiplier`'s doc comment for the
/// full origin story). Decline is simpler and deliberately not
/// minutes-gated -- aging happens whether you play or not -- and applies
/// the same regardless of who's kept around for locker-room value (no
/// veteran exemptions, the GM's explicit call).
double _totalWeeklyDelta({
  required Player player,
  required double minutesThisWeek,
  required int coachDevelopmentRating,
  required bool isDevelopmentalSlot,
  required bool isIndividuallySlotted,
  required bool isBreakoutSeason,
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
  // Concave (exponent < 1), not linear -- see `_kGapConcavityExponent`'s
  // own doc comment: keeps meaningful growth alive through the last
  // 10-15 points instead of asymptotically stalling short of potential.
  final gapFactor = pow(
    (gap / _kGapNormalization).clamp(0.0, 1.0),
    _kGapConcavityExponent,
  ).toDouble();
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
  // Growth lever 1: a true rookie's first 2 pro seasons outgrow a
  // same-age veteran's -- see `_kRookieSurgeMultiplier`'s own doc
  // comment.
  if (player.yearsOfService < _kRookieSeasons) {
    delta *= _kRookieSurgeMultiplier;
  }
  // Growth lever 4: this season's breakout roll, if any -- see
  // `_kBreakoutChanceSlotted`'s own doc comment and [_isBreakoutSeason].
  if (isBreakoutSeason) delta *= _kBreakoutMultiplier;
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
