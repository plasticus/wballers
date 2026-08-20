import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../matchup/domain/coaching_option.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/player.dart';
import '../domain/match_event.dart';
import '../domain/match_result.dart';
import 'fatigue.dart';
import 'possession_engine.dart';
import 'substitution_policy.dart';
import 'tip_off_resolver.dart';

/// WNBA quarter length, in seconds (10 minutes).
const _quarterSeconds = 600.0;
const _quarterCount = 4;

/// WNBA overtime period length, in seconds (5 minutes).
const _overtimeSeconds = 300.0;

/// Team fouls in a quarter at which the opposing team goes into the bonus
/// (2 free throws on any subsequent non-shooting foul that quarter).
const _teamFoulBonusThreshold = 5;

/// Personal fouls at which a player fouls out and must be substituted.
const _personalFoulOutLimit = 6;

/// The extra Q4-only coaching break -- "one more in Q4 if the game is
/// within 7 points... at the 2:00 mark" (`TODO.md` item 8, the recorded
/// design-doc number). On top of the 3 ordinary end-of-quarter breaks.
const _lateGameBreakClockSeconds = 120.0;
const _lateGameBreakMargin = 7;

/// How often on-court lineups get re-picked, in simulated seconds. Locking
/// lineups only at quarter boundaries (600s) meant nobody with a target
/// under a full quarter's worth of minutes (the bottom of the bench,
/// 4-8 target minutes) could ever be "due" -- a throwaway full-game sanity
/// check confirmed those players sat the whole game. Rechecking every 2
/// minutes gives even a 4-minute target a real chance to be the most
/// due at some point in the quarter.
const _substitutionCheckSeconds = 120.0;

Player _tallest(List<Player> players) =>
    players.reduce((a, b) => a.heightInches >= b.heightInches ? a : b);

/// The id of whoever in [roster] rates highest by `PlayerRatings.overall`
/// -- [DefensiveTactic.faceGuardStar]'s target, always computed off the
/// *opposing* team's roster. Null-safe on an empty roster (never actually
/// empty for a real 12-player game, but cheap to guard).
String? _bestPlayerId(List<Player> roster) {
  if (roster.isEmpty) return null;
  return roster
      .reduce((a, b) => a.ratings.overall >= b.ratings.overall ? a : b)
      .id;
}

/// Simulates one full game between [homeRoster] and [awayRoster] (each the
/// full 12-player active roster) -- quarters, a running score, fouls
/// (personal and team, with bonus free throws), and automatic
/// substitutions driven by target minutes. [homeTargetMinutes]/
/// [awayTargetMinutes] are optional -- when omitted, each side falls back
/// to [targetMinutesFor]'s automatic overall-based ranking (the AI-team
/// default); a caller with a real ranking to use instead (the GM's own
/// bench order, via [targetMinutesForOrderedRoster]) passes it directly
/// rather than letting this function re-derive one. Deterministic for a
/// given [random] stream.
///
/// A thin wrapper around [_GameSimulation] -- see that class's own doc
/// comment for why the actual quarter-by-quarter logic lives there
/// instead of inline here (2026-08-18, `TODO.md` item 8's live-game
/// architecture work). This function's own signature and behavior are
/// completely unchanged by that split -- every one of its ~35 existing
/// callers keeps working exactly as before. [simulateMatchLive] (bottom
/// of this file) is the real, awaitable sibling for the one game an
/// actual human ever watches live.
///
/// Simplifications, all deliberate and worth revisiting later:
/// - **Lineups re-pick every `_substitutionCheckSeconds`** (plus
///   immediately on a foul-out) rather than modeling exact live
///   substitution timing. Coarser than real coaching, which reacts to
///   specific dead-ball moments, but converges toward each player's
///   target minutes reasonably well. Can produce choppier in/out patterns
///   than a real coach would -- the greedy "most behind schedule" rule has
///   no stickiness once a player's minutes catch up.
/// - **Quarters end after whichever possession is in progress completes**,
///   not mid-action -- a quarter can run a little past its nominal 600
///   seconds rather than truncating a possession exactly at the buzzer.
/// - **Quarter-start possession strictly alternates** (home, away, home,
///   away, keyed off who won the opening tip) rather than modeling the
///   real alternating-possession arrow precisely -- extended the same way
///   into overtime periods.
/// - **Overtime is as many 5-minute periods as it takes** to break a tie
///   (real WNBA/NBA length) -- a season simulator needs a winner out of
///   every game, so a tied game after Q4 doesn't just end tied.
///   [MatchResult.homeScoreByQuarter]/`awayScoreByQuarter` can run longer
///   than 4 entries when this happens.
/// - **Energy/fatigue** (`fatigue.dart`, `0B_Planned.md`'s stamina
///   appendix, 2026-08-17, built and wired in for real) -- every rostered
///   player's energy drains while on court and recovers while benched
///   (plus a flat bump at halftime), surfaced on [MatchResult.finalEnergy]
///   and validated against real rosters via `tool/fatigue_diagnostic.dart`
///   both before and after a real-game-driven retune. The resulting
///   [fatigueBonusFor] penalty is summed into every rating contest a
///   fatigued player touches in `possession_engine.dart` (passing,
///   shooting, free throws, blocking, rebounding, on both ends of the
///   floor) via that file's `_fatigueBonus` helper, the same accumulator
///   slot `OffenseShapeBonus`/`DefenseTacticBonus`/`coachQualityBonus`
///   already share. Substitutions still don't react to it, though --
///   `pickOnCourt`/`targetMinutesFor` are driven purely by target minutes
///   and foul-outs, confirmed as the intended design rather than a gap
///   (2026-08-20, a direct GM check-in: "the coach mostly targets minutes
///   rather than trying to bench high-fatigue players, and I'm good with
///   that").
/// - **Blowout pace rubber-banding** (TODO.md item 5): whichever team is
///   ahead by `kBlowoutPaceMargin` or more slows its own possessions down
///   (`possession_engine.dart`'s `simulatePossession` `offenseMargin`
///   param) -- longer possessions eat clock for both teams, capping how
///   many total possessions (and therefore points) are left for the
///   margin to keep growing on. Pacing only -- no rating or shot-quality
///   change for either team.
/// - **Home team advantage** (TODO.md item 11): every home-team player's
///   ratings get a flat `kHomeAdvantageBonus` bump for every contest this
///   game (`possession_engine.dart`), on top of which
///   [Trait.homeCourtHero] adds a further home-only bump and
///   [Trait.roadWarrior] adds an away-only one. [homeRoster] is always
///   the home team here -- there's no neutral-site game.
/// - **Coach quality bonus** (2026-08-20, a direct GM re-confirmation --
///   replaces the earlier opponent-relative "coach matchup" model
///   outright): [homeCoach]/[awayCoach] are optional (`null` skips the
///   bonus entirely for that side, e.g. an exhibition with no real
///   per-team coach assigned) -- each team's own coach's `CoachStats.offense`/
///   `CoachStats.defense`, measured against the flat 50 midpoint
///   ([coachQualityBonus], `possession_engine.dart`), becomes that team's
///   own flat rating bump on its own offense/defense, entirely independent
///   of who they're playing. Computed once here for the whole game (coach
///   stats don't change mid-game) rather than re-derived every possession.
/// - **Offense shape** (2026-08-14, a direct GM ask, following the
///   "Coach's Board" design artifact): fully automatic, no param to set --
///   each side's starting five (the 5 players carrying the most minutes
///   in its resolved target-minutes map, via `startingFiveByMinutes`)
///   determines an `OffenseShape` (`offense_shape.dart`), which becomes
///   that team's flat rating bump whenever they're on offense. Applies to
///   every game this function ever simulates, including postseason,
///   All-Star, and AI-vs-AI regular-season games -- there's no opt-out,
///   since it's read straight off real roster data rather than a GM
///   choice.
/// - **Defensive tactic** (2026-08-14, same ask): [homeDefenseTactic]/
///   [awayDefenseTactic] default to [DefensiveTactic.balanced] --
///   deliberately *not* nullable/coach-style all-or-nothing, since
///   Balanced is a legitimate value on its own (every AI opponent and
///   every non-"today's game" call site just leaves these at their
///   default, which *is* "AI always plays Balanced," with no separate
///   AI-decision logic anywhere). Only the pre-game screen's Play Game
///   flow ever passes something else, for the GM's own team only. Each
///   side's tactic becomes that team's rating bump whenever they're on
///   *defense* (`defensive_tactic.dart`'s `DefenseTacticBonus`) --
///   [DefensiveTactic.faceGuardStar] additionally targets whichever
///   player on the *opposing* roster has the highest
///   `PlayerRatings.overall` (this game's fixed target for the whole
///   game, not re-evaluated possession to possession).
/// - **Quarter-break coaching options** (2026-08-17, catalog + selection
///   logic locked in `0B_Planned.md`'s quarter-break bullet, `TODO.md`
///   item 8): [homeCoachingPicker]/[awayCoachingPicker] are optional --
///   `null` (the default, same "AI always Balanced" posture
///   [homeDefenseTactic]/[awayDefenseTactic] already established) means
///   that side is never offered anything, so no existing caller's
///   behavior changes without opting in. When supplied, a picker is
///   called synchronously at each real break (end of Q1/Q2/Q3, plus the
///   Q4 [_lateGameBreakClockSeconds]-mark stoppage if the game is within
///   [_lateGameBreakMargin]) with an already-drawn 3-option menu
///   (`coaching_option.dart`'s `offerCoachingOptions`) and returns
///   whichever it picks (or `null` to skip). [CoachingOption.fireTheTeamUp]/
///   [CoachingOption.restAPlayer] apply once, immediately; every other
///   pick becomes that side's flat rating/pace/stamina bonus
///   (`coachingBonusFor`) for the rest of its duration -- one quarter, or
///   the remaining ~2 minutes at the late break -- via
///   `possession_engine.dart`'s `offenseCoachingBonus`/
///   `defenseCoachingBonus`. Synchronous here on purpose -- this is the
///   path every AI-vs-AI game and the season simulator run through, and
///   nobody's watching those. [simulateMatchLive] is the real,
///   pause-for-a-human-tap sibling.
MatchResult simulateMatch(
  Random random, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
  Map<Player, int>? homeTargetMinutes,
  Map<Player, int>? awayTargetMinutes,
  Coach? homeCoach,
  Coach? awayCoach,
  DefensiveTactic homeDefenseTactic = DefensiveTactic.balanced,
  DefensiveTactic awayDefenseTactic = DefensiveTactic.balanced,
  CoachingOptionPicker? homeCoachingPicker,
  CoachingOptionPicker? awayCoachingPicker,
}) {
  assert(homeRoster.length == 12, 'homeRoster must have exactly 12 players');
  assert(awayRoster.length == 12, 'awayRoster must have exactly 12 players');

  final sim = _GameSimulation(
    random,
    homeRoster: homeRoster,
    awayRoster: awayRoster,
    homeTargetMinutes: homeTargetMinutes ?? targetMinutesFor(homeRoster),
    awayTargetMinutes: awayTargetMinutes ?? targetMinutesFor(awayRoster),
    homeCoach: homeCoach,
    awayCoach: awayCoach,
    homeDefenseTactic: homeDefenseTactic,
    awayDefenseTactic: awayDefenseTactic,
    homeCoachingPicker: homeCoachingPicker,
    awayCoachingPicker: awayCoachingPicker,
  );
  while (!sim.isComplete) {
    if (sim.quarter > 1) sim.prepareQuarter();
    sim.runPossessions();
    sim.wrapUpQuarter();
  }
  return sim.toMatchResult();
}

/// One handoff from [simulateMatchLive] to its `onSegmentComplete`
/// callback -- [possessions] is this segment's events, grouped (see
/// [simulateMatchLive]'s own doc comment); [quarter] and [isEndOfQuarter]
/// give a translator enough to track a running clock/quarter display
/// without having to infer it from the events themselves.
/// [isEndOfQuarter] is `false` for exactly one case: the Q4 late-game
/// coaching break, which pauses mid-quarter rather than completing it --
/// every other segment (every ordinary quarter, and the final one of the
/// game, however many overtimes it took) completes its quarter.
typedef LiveGameSegment = ({
  List<List<MatchEvent>> possessions,
  int quarter,
  bool isEndOfQuarter,
});

/// The live, human-watched sibling of [simulateMatch] -- the one path in
/// this whole engine that's actually `async` (2026-08-18, `TODO.md` item
/// 8's live-game architecture work). Drives the exact same
/// [_GameSimulation] logic [simulateMatch] uses, quarter by quarter, but
/// stops after each quarter (and the Q4 late-game break, mid-quarter) to
/// hand that segment's possessions to [onSegmentComplete] and await
/// whatever it returns before continuing -- there's nothing time-gated
/// about the simulation itself; every quarter still computes instantly,
/// same as always. A live screen's own implementation of
/// [onSegmentComplete] is where the actual watching experience lives:
/// translate the events into beats and replay them at whatever speed the
/// GM picked, then return.
///
/// Each entry in [onSegmentComplete]'s `possessions` is one possession's
/// worth of events (the tip-off counts as its own single-event
/// "possession") -- grouped, not a flat list, so a translator can tell
/// "the first pass of a new possession" (reads as bringing the ball up)
/// apart from "a later pass in the same one" (reads as ball movement)
/// without having to re-infer possession boundaries after the fact.
///
/// [homeLiveCoachingPicker]/[awayLiveCoachingPicker] mirror
/// [simulateMatch]'s own [CoachingOptionPicker] params, just awaitable --
/// only ever supplied for whichever side is the GM's own team (`TODO.md`
/// item 8's "GM's own scheduled game only" scope); the AI opponent's side
/// stays `null`, same "no picker, no offer" posture [simulateMatch]
/// already established. A picker is only ever actually awaited at a real
/// break (end of Q1/Q2/Q3, or the Q4 late-game stoppage) -- most quarter
/// boundaries in a real game won't offer one to every side, exactly like
/// today.
Future<MatchResult> simulateMatchLive(
  Random random, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
  Map<Player, int>? homeTargetMinutes,
  Map<Player, int>? awayTargetMinutes,
  Coach? homeCoach,
  Coach? awayCoach,
  DefensiveTactic homeDefenseTactic = DefensiveTactic.balanced,
  DefensiveTactic awayDefenseTactic = DefensiveTactic.balanced,
  LiveCoachingPicker? homeLiveCoachingPicker,
  LiveCoachingPicker? awayLiveCoachingPicker,
  required Future<void> Function(LiveGameSegment segment) onSegmentComplete,
}) async {
  assert(homeRoster.length == 12, 'homeRoster must have exactly 12 players');
  assert(awayRoster.length == 12, 'awayRoster must have exactly 12 players');

  final sim = _GameSimulation(
    random,
    homeRoster: homeRoster,
    awayRoster: awayRoster,
    homeTargetMinutes: homeTargetMinutes ?? targetMinutesFor(homeRoster),
    awayTargetMinutes: awayTargetMinutes ?? targetMinutesFor(awayRoster),
    homeCoach: homeCoach,
    awayCoach: awayCoach,
    homeDefenseTactic: homeDefenseTactic,
    awayDefenseTactic: awayDefenseTactic,
    homeLiveCoachingPicker: homeLiveCoachingPicker,
    awayLiveCoachingPicker: awayLiveCoachingPicker,
  );

  var possessionsHandedOff = 0;
  Future<void> flushEvents({required bool isEndOfQuarter}) async {
    final segment = sim.possessions.sublist(possessionsHandedOff);
    possessionsHandedOff = sim.possessions.length;
    await onSegmentComplete((
      possessions: segment,
      quarter: sim.quarter,
      isEndOfQuarter: isEndOfQuarter,
    ));
  }

  while (!sim.isComplete) {
    if (sim.quarter > 1) {
      await sim.prepareQuarterLive();
    }
    sim.startQuarterClock();
    while (true) {
      final pausedForLateBreak = sim.runSegment();
      await flushEvents(isEndOfQuarter: !pausedForLateBreak);
      if (!pausedForLateBreak) break;
      await sim.resolveLateGameBreakLive();
    }
    sim.wrapUpQuarter();
  }
  return sim.toMatchResult();
}

/// The full mutable state and step-by-step logic for one game -- split out
/// of `simulateMatch`'s own body (2026-08-18, `TODO.md` item 8's live-game
/// architecture item) so [simulateMatchLive] can run the exact same
/// quarter-by-quarter logic one segment at a time (computing a quarter,
/// handing it to a live UI to show, awaiting a real coaching pick, then
/// continuing) instead of all the way through in one synchronous call, the
/// way [simulateMatch] itself still does and always will for every
/// AI-vs-AI game, the season simulator, and everything else that doesn't
/// need a human watching.
///
/// [simulateMatch] and [simulateMatchLive] are both thin wrappers around
/// this class -- construct it, then drive it quarter by quarter with
/// [prepareQuarter]/[runPossessions]/[wrapUpQuarter] (sync) or
/// [prepareQuarterLive]/[startQuarterClock]/[runSegment]/
/// [resolveLateGameBreakLive]/[wrapUpQuarter] (live) until [isComplete],
/// then read the result off [toMatchResult]. Every field and most methods
/// are private precisely because those two functions are the only
/// callers this class is meant to have.
class _GameSimulation {
  _GameSimulation(
    this._random, {
    required this.homeRoster,
    required this.awayRoster,
    required this.homeTargetMinutes,
    required this.awayTargetMinutes,
    Coach? homeCoach,
    Coach? awayCoach,
    required DefensiveTactic homeDefenseTactic,
    required DefensiveTactic awayDefenseTactic,
    this.homeCoachingPicker,
    this.awayCoachingPicker,
    this.homeLiveCoachingPicker,
    this.awayLiveCoachingPicker,
  }) : homeOffenseCoachBonus = homeCoach == null
           ? 0.0
           : coachQualityBonus(homeCoach.stats.offense),
       awayOffenseCoachBonus = awayCoach == null
           ? 0.0
           : coachQualityBonus(awayCoach.stats.offense),
       homeDefenseCoachBonus = homeCoach == null
           ? 0.0
           : coachQualityBonus(homeCoach.stats.defense),
       awayDefenseCoachBonus = awayCoach == null
           ? 0.0
           : coachQualityBonus(awayCoach.stats.defense),
       // Each side's own Motivation multiplier stands on its own too --
       // like the coach-quality bonus above (2026-08-20, no longer a
       // head-to-head comparison against the *other* side's coach), it
       // only ever needs this side's own coach present.
       homeMotivationBonusMultiplier = motivationBonusMultiplier(
         homeCoach?.stats.motivation ?? 50,
       ),
       awayMotivationBonusMultiplier = motivationBonusMultiplier(
         awayCoach?.stats.motivation ?? 50,
       ),
       homeOffenseBonus = offenseBonusFor(
         detectOffenseShape(startingFiveByMinutes(homeTargetMinutes)),
       ),
       awayOffenseBonus = offenseBonusFor(
         detectOffenseShape(startingFiveByMinutes(awayTargetMinutes)),
       ),
       homeDefenseBonus = defenseBonusFor(homeDefenseTactic),
       awayDefenseBonus = defenseBonusFor(awayDefenseTactic),
       // Each side's Face-Guard-the-Star target (if any) is whoever on
       // the *opposing* roster rates highest overall -- null-safe, though
       // a real 12-player roster is never empty in practice.
       homeDefenseTargetId = _bestPlayerId(awayRoster),
       awayDefenseTargetId = _bestPlayerId(homeRoster),
       // All 24 rostered players, not just whoever's on court -- a
       // benched player still needs an energy value to recover into
       // (`fatigue.dart`).
       energy = {
         for (final p in [...homeRoster, ...awayRoster]) p: kMaxEnergy,
       } {
    homeOnCourt = pickOnCourt(
      roster: homeRoster,
      targetMinutes: homeTargetMinutes,
      minutesPlayed: minutesPlayed,
      fouledOut: fouledOut,
      rested: homeRestedPlayers,
    );
    awayOnCourt = pickOnCourt(
      roster: awayRoster,
      targetMinutes: awayTargetMinutes,
      minutesPlayed: minutesPlayed,
      fouledOut: fouledOut,
      rested: awayRestedPlayers,
    );
    final homeJumper = _tallest(homeOnCourt);
    final awayJumper = _tallest(awayOnCourt);
    tipOffWinnerIsHome = resolveTipOff(_random, homeJumper, awayJumper);
    // Surfaced as a real event (2026-08-18, TODO.md item 8's live-game
    // architecture stage 3) so a live translator has something to credit
    // the tip-off to -- previously resolved silently, with no MatchEvent
    // at all despite MatchEventType.tipOff already existing in the enum.
    final tipOffEvent = MatchEvent(
      type: MatchEventType.tipOff,
      secondsElapsed: 0,
      player: tipOffWinnerIsHome ? homeJumper : awayJumper,
      secondPlayer: tipOffWinnerIsHome ? awayJumper : homeJumper,
    );
    events.add(tipOffEvent);
    possessions.add([tipOffEvent]);
  }

  final Random _random;

  // Configuration -- fixed for the whole game, computed once in the
  // constructor rather than re-derived every quarter or possession.
  final List<Player> homeRoster;
  final List<Player> awayRoster;
  final Map<Player, int> homeTargetMinutes;
  final Map<Player, int> awayTargetMinutes;
  final double homeOffenseCoachBonus;
  final double awayOffenseCoachBonus;
  final double homeDefenseCoachBonus;
  final double awayDefenseCoachBonus;

  /// Each side's own coach's Motivation, scaled into a multiplier once
  /// up front (`coaching_option.dart`'s `motivationBonusMultiplier`) --
  /// a coach with no `Coach` supplied at all reads as the neutral
  /// midpoint (50 -> 1.0x, no change), same "opt-in only" default this
  /// whole coaching-option system already has for everything else.
  /// Applied only when that side's coaching-option pick actually
  /// resolves to a real bonus (`_applyCoachingPick`) -- motivation with
  /// no pick active has nothing to scale.
  final double homeMotivationBonusMultiplier;
  final double awayMotivationBonusMultiplier;
  final OffenseShapeBonus homeOffenseBonus;
  final OffenseShapeBonus awayOffenseBonus;
  final DefenseTacticBonus homeDefenseBonus;
  final DefenseTacticBonus awayDefenseBonus;
  final String? homeDefenseTargetId;
  final String? awayDefenseTargetId;
  final CoachingOptionPicker? homeCoachingPicker;
  final CoachingOptionPicker? awayCoachingPicker;
  final LiveCoachingPicker? homeLiveCoachingPicker;
  final LiveCoachingPicker? awayLiveCoachingPicker;
  late final bool tipOffWinnerIsHome;

  // Game state -- mutated quarter to quarter and possession to
  // possession by [prepareQuarter]/[runPossessions]/[wrapUpQuarter] (or
  // their live equivalents).
  var quarter = 1;
  var homeScore = 0;
  var awayScore = 0;
  final homeScoreByQuarter = <int>[];
  final awayScoreByQuarter = <int>[];
  final events = <MatchEvent>[];

  /// The same events as [events], grouped by possession (the tip-off
  /// counts as its own single-event "possession") -- kept alongside the
  /// flat list rather than instead of it, since [toMatchResult] and the
  /// box score it feeds only ever wanted a flat log, while
  /// [simulateMatchLive]'s translator (2026-08-18, `TODO.md` item 8's
  /// live-game architecture stage 3) needs real possession boundaries to
  /// tell "first pass of a new possession" (reads as bringing the ball
  /// up) apart from "a later pass in the same one" (reads as ball
  /// movement) -- a distinction the flat list alone can't make.
  final possessions = <List<MatchEvent>>[];
  final minutesPlayed = <Player, double>{};
  final personalFouls = <Player, int>{};
  final fouledOut = <Player>{};
  final Map<Player, double> energy;
  late List<Player> homeOnCourt;
  late List<Player> awayOnCourt;

  // Quarter-break coaching options (2026-08-17, `0B_Planned.md`'s
  // quarter-break bullet): each side's currently-active pick (`null` if
  // none, or if that side has no picker at all), the flat bonus it
  // resolves to (`coachingBonusFor`, recomputed only when the pick
  // changes, not every possession), and who's currently sat by
  // [CoachingOption.restAPlayer] -- all cleared at the top of every new
  // quarter/period, since a pick's duration never outlives the stoppage
  // that offered it. `homeUnansweredRun`/`awayUnansweredRun` track
  // [CoachingOption.stopTheBleeding]'s trigger: however many points one
  // side has scored, unanswered, right now -- reset to 0 for a side the
  // instant the *other* side scores.
  var homeCoachingBonus = kNoCoachingOptionBonus;
  var awayCoachingBonus = kNoCoachingOptionBonus;
  var homeRestedPlayers = <Player>{};
  var awayRestedPlayers = <Player>{};
  var homeUnansweredRun = 0;
  var awayUnansweredRun = 0;

  // Per-quarter possession-loop state -- lives across possessions within
  // a single quarter, and (only ever relevant to [simulateMatchLive])
  // across a mid-quarter pause at the Q4 late-game break, since
  // [runSegment] can return control to its caller without this quarter
  // being over. [runPossessions] (the sync path) never sees that pause --
  // it resolves the break inline and keeps going within the same call --
  // but shares this same state and the same [_processOnePossession] step
  // logic rather than duplicating it.
  var _quarterClock = 0.0;
  var _secondsSinceSubCheck = 0.0;
  var _homeTeamFouls = 0;
  var _awayTeamFouls = 0;
  var _lateBreakFired = false;
  var _offenseIsHome = false;
  var _homeScoreBeforeQuarter = 0;
  var _awayScoreBeforeQuarter = 0;

  /// Whether the whole game (regulation plus however many overtime
  /// periods it took) is over -- the exact condition `simulateMatch`'s
  /// old `while` loop used to keep going.
  bool get isComplete => quarter > _quarterCount && homeScore != awayScore;

  /// Whether the Q4 late-game coaching break is due right now -- "one
  /// more in Q4 if the game is within 7 points... at the 2:00 mark"
  /// (`TODO.md` item 8). Checked after every possession, same as the
  /// ordinary substitution-check timer, since there's no other
  /// mid-quarter breakpoint in this loop.
  bool get _isLateBreakDue =>
      quarter == _quarterCount &&
      !_lateBreakFired &&
      _quarterClock <= _lateGameBreakClockSeconds &&
      (homeScore - awayScore).abs() <= _lateGameBreakMargin;

  void _repickOnCourt() {
    homeOnCourt = pickOnCourt(
      roster: homeRoster,
      targetMinutes: homeTargetMinutes,
      minutesPlayed: minutesPlayed,
      fouledOut: fouledOut,
      rested: homeRestedPlayers,
    );
    awayOnCourt = pickOnCourt(
      roster: awayRoster,
      targetMinutes: awayTargetMinutes,
      minutesPlayed: minutesPlayed,
      fouledOut: fouledOut,
      rested: awayRestedPlayers,
    );
  }

  /// Applies whichever [CoachingOption] one side just picked (or `null`,
  /// a no-op) -- shared by the sync and live coaching-break paths, since
  /// this part (unlike *deciding* what got picked) never needs to await
  /// anything. [CoachingOption.fireTheTeamUp]/[CoachingOption.restAPlayer]
  /// apply once, immediately; everything else becomes that side's flat
  /// bonus for the rest of its duration.
  void _applyCoachingPick(bool isHome, CoachingOption? picked) {
    if (picked == CoachingOption.fireTheTeamUp) {
      final roster = isHome ? homeRoster : awayRoster;
      energy.addAll(applyFireTheTeamUp(energy, roster));
    } else if (picked == CoachingOption.restAPlayer) {
      final onCourt = isHome ? homeOnCourt : awayOnCourt;
      final toRest = pickPlayerToRest(energy, onCourt);
      if (isHome) {
        homeRestedPlayers = {?toRest};
      } else {
        awayRestedPlayers = {?toRest};
      }
    } else if (isHome) {
      homeCoachingBonus = applyMotivationToCoachingBonus(
        coachingBonusFor(picked),
        homeMotivationBonusMultiplier,
      );
    } else {
      awayCoachingBonus = applyMotivationToCoachingBonus(
        coachingBonusFor(picked),
        awayMotivationBonusMultiplier,
      );
    }
  }

  /// Offers (if a picker is supplied) and applies a coaching-option pick
  /// for each side independently, right now, for the current [quarter] --
  /// the synchronous path, for [homeCoachingPicker]/[awayCoachingPicker].
  void _runCoachingBreak(CoachingBreakStoppage stoppage) {
    if (homeCoachingPicker != null) {
      final offered = offerCoachingOptions(
        _random,
        stoppage: stoppage,
        opponentUnansweredRun: awayUnansweredRun,
      );
      final picked = homeCoachingPicker!((
        quarter: quarter,
        ownScore: homeScore,
        opponentScore: awayScore,
        opponentUnansweredRun: awayUnansweredRun,
        offered: offered,
      ));
      _applyCoachingPick(true, picked);
    }
    if (awayCoachingPicker != null) {
      final offered = offerCoachingOptions(
        _random,
        stoppage: stoppage,
        opponentUnansweredRun: homeUnansweredRun,
      );
      final picked = awayCoachingPicker!((
        quarter: quarter,
        ownScore: awayScore,
        opponentScore: homeScore,
        opponentUnansweredRun: homeUnansweredRun,
        offered: offered,
      ));
      _applyCoachingPick(false, picked);
    }
  }

  /// [_runCoachingBreak]'s awaited twin, for
  /// [homeLiveCoachingPicker]/[awayLiveCoachingPicker].
  Future<void> _runCoachingBreakLive(CoachingBreakStoppage stoppage) async {
    if (homeLiveCoachingPicker != null) {
      final offered = offerCoachingOptions(
        _random,
        stoppage: stoppage,
        opponentUnansweredRun: awayUnansweredRun,
      );
      final picked = await homeLiveCoachingPicker!((
        quarter: quarter,
        ownScore: homeScore,
        opponentScore: awayScore,
        opponentUnansweredRun: awayUnansweredRun,
        offered: offered,
      ));
      _applyCoachingPick(true, picked);
    }
    if (awayLiveCoachingPicker != null) {
      final offered = offerCoachingOptions(
        _random,
        stoppage: stoppage,
        opponentUnansweredRun: homeUnansweredRun,
      );
      final picked = await awayLiveCoachingPicker!((
        quarter: quarter,
        ownScore: awayScore,
        opponentScore: homeScore,
        opponentUnansweredRun: homeUnansweredRun,
        offered: offered,
      ));
      _applyCoachingPick(false, picked);
    }
  }

  /// Clears both sides' active coaching state (a pick's duration never
  /// outlives the stoppage that offered it), offers+applies a fresh pick
  /// via [_runCoachingBreak], and re-picks both sides' on-court five to
  /// reflect it -- the common "resolve a break" sequence shared by
  /// [prepareQuarter] and the sync Q4 late-game break inside
  /// [runPossessions].
  void _resolveBreakSync(CoachingBreakStoppage stoppage) {
    homeCoachingBonus = kNoCoachingOptionBonus;
    awayCoachingBonus = kNoCoachingOptionBonus;
    homeRestedPlayers = {};
    awayRestedPlayers = {};
    _runCoachingBreak(stoppage);
    _repickOnCourt();
  }

  /// [_resolveBreakSync]'s awaited twin, via [_runCoachingBreakLive].
  Future<void> _resolveBreakLive(CoachingBreakStoppage stoppage) async {
    homeCoachingBonus = kNoCoachingOptionBonus;
    awayCoachingBonus = kNoCoachingOptionBonus;
    homeRestedPlayers = {};
    awayRestedPlayers = {};
    await _runCoachingBreakLive(stoppage);
    _repickOnCourt();
  }

  /// Everything that happens *between* quarters, for whichever quarter is
  /// about to start (i.e. the current [quarter], already incremented by
  /// the previous [wrapUpQuarter] call) -- offering a coaching break (for
  /// quarters 2-4 only; there's no break before overtime) and re-picking
  /// each side's on-court five. Not called for quarter 1, which the
  /// constructor already sets up. The sync path, for [simulateMatch].
  void prepareQuarter() {
    if (quarter <= _quarterCount) {
      // Keyed off which quarter the pick is *for*, not which one just
      // ended -- only the end-of-Q1 break (deciding Q2) is firstHalf;
      // deciding Q3 or Q4 is secondHalf either way
      // (`CoachingBreakStoppage`'s own doc comment).
      _resolveBreakSync(
        quarter == 2
            ? CoachingBreakStoppage.firstHalf
            : CoachingBreakStoppage.secondHalf,
      );
    } else {
      // Overtime: no break offered, but a stale pick from Q4 still
      // shouldn't carry in, and the on-court five still needs a fresh
      // pick for the new period.
      homeCoachingBonus = kNoCoachingOptionBonus;
      awayCoachingBonus = kNoCoachingOptionBonus;
      homeRestedPlayers = {};
      awayRestedPlayers = {};
      _repickOnCourt();
    }
  }

  /// [prepareQuarter]'s awaited twin, for [simulateMatchLive].
  Future<void> prepareQuarterLive() async {
    if (quarter <= _quarterCount) {
      await _resolveBreakLive(
        quarter == 2
            ? CoachingBreakStoppage.firstHalf
            : CoachingBreakStoppage.secondHalf,
      );
    } else {
      homeCoachingBonus = kNoCoachingOptionBonus;
      awayCoachingBonus = kNoCoachingOptionBonus;
      homeRestedPlayers = {};
      awayRestedPlayers = {};
      _repickOnCourt();
    }
  }

  /// Resets the per-quarter possession-loop state for a fresh quarter --
  /// called once per quarter, before the first [runPossessions] or
  /// [runSegment] call for it.
  void startQuarterClock() {
    _quarterClock = quarter <= _quarterCount
        ? _quarterSeconds
        : _overtimeSeconds;
    _secondsSinceSubCheck = 0;
    _homeTeamFouls = 0;
    _awayTeamFouls = 0;
    _lateBreakFired = false;
    _offenseIsHome = quarter.isOdd ? tipOffWinnerIsHome : !tipOffWinnerIsHome;
    _homeScoreBeforeQuarter = homeScore;
    _awayScoreBeforeQuarter = awayScore;
  }

  /// Records the just-finished quarter's score delta -- shared tail end
  /// of both [runPossessions] and [runSegment] once the quarter's clock
  /// actually reaches 0.
  void _finishQuarterScoring() {
    homeScoreByQuarter.add(homeScore - _homeScoreBeforeQuarter);
    awayScoreByQuarter.add(awayScore - _awayScoreBeforeQuarter);
  }

  /// Simulates exactly one possession and applies all its bookkeeping --
  /// score, minutes, fatigue, fouls/substitutions, the sub-check timer,
  /// and flips whose ball it is next. Shared by [runPossessions] (the
  /// sync path's uninterrupted loop) and [runSegment] (the live path's
  /// resumable one) so the actual possession-handling logic only exists
  /// once.
  void _processOnePossession() {
    final offense = _offenseIsHome ? homeOnCourt : awayOnCourt;
    final defense = _offenseIsHome ? awayOnCourt : homeOnCourt;
    final defenseInBonus = _offenseIsHome
        ? _awayTeamFouls >= _teamFoulBonusThreshold
        : _homeTeamFouls >= _teamFoulBonusThreshold;
    final offenseMargin = _offenseIsHome
        ? homeScore - awayScore
        : awayScore - homeScore;

    final result = simulatePossession(
      _random,
      offense: offense,
      defense: defense,
      defenseInBonus: defenseInBonus,
      offenseMargin: offenseMargin,
      offenseIsHome: _offenseIsHome,
      defenseIsHome: !_offenseIsHome,
      offenseCoachBonus: _offenseIsHome
          ? homeOffenseCoachBonus
          : awayOffenseCoachBonus,
      defenseCoachBonus: _offenseIsHome
          ? awayDefenseCoachBonus
          : homeDefenseCoachBonus,
      offenseBonus: _offenseIsHome ? homeOffenseBonus : awayOffenseBonus,
      defenseBonus: _offenseIsHome ? awayDefenseBonus : homeDefenseBonus,
      defenseTargetPlayerId: _offenseIsHome
          ? awayDefenseTargetId
          : homeDefenseTargetId,
      energy: energy,
      offenseCoachingBonus: _offenseIsHome
          ? homeCoachingBonus
          : awayCoachingBonus,
      defenseCoachingBonus: _offenseIsHome
          ? awayCoachingBonus
          : homeCoachingBonus,
    );
    events.addAll(result.events);
    possessions.add(result.events);
    _quarterClock -= result.secondsElapsed;
    _secondsSinceSubCheck += result.secondsElapsed;

    final minutesThisPossession = result.secondsElapsed / 60;
    for (final p in offense) {
      minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
    }
    for (final p in defense) {
      minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
    }

    // Fatigue (`fatigue.dart`): everyone on court this possession drains
    // energy; everyone else on either bench recovers it. `offense` and
    // `defense` together are exactly `homeOnCourt` + `awayOnCourt`
    // (whichever side is which flips every possession, but the on-court
    // set doesn't), so this covers all 10 on-court players regardless of
    // which side is attacking. `staminaDrainMultiplier` (2026-08-17,
    // `CoachingOption.fullCourtPress`/`pickUpThePace`/`paceYourself`)
    // applies by *roster* membership, not offense/defense -- a team's
    // pace pick costs (or saves) stamina the same whether they're
    // currently attacking or defending.
    for (final p in offense) {
      final multiplier = homeRoster.contains(p)
          ? homeCoachingBonus.staminaDrainMultiplier
          : awayCoachingBonus.staminaDrainMultiplier;
      energy[p] =
          (energy[p]! -
                  fatigueDrainPerMinute(p.ratings.stamina) *
                      multiplier *
                      minutesThisPossession)
              .clamp(0.0, kMaxEnergy)
              .toDouble();
    }
    for (final p in defense) {
      final multiplier = homeRoster.contains(p)
          ? homeCoachingBonus.staminaDrainMultiplier
          : awayCoachingBonus.staminaDrainMultiplier;
      energy[p] =
          (energy[p]! -
                  fatigueDrainPerMinute(p.ratings.stamina) *
                      multiplier *
                      minutesThisPossession)
              .clamp(0.0, kMaxEnergy)
              .toDouble();
    }
    // `CoachingOption.restAPlayer`'s pick gets a bigger recovery bump
    // than the ordinary bench trickle -- "a bigger-than-usual energy
    // recovery bump" (2026-08-17).
    for (final p in homeRoster) {
      if (homeOnCourt.contains(p)) continue;
      final multiplier = homeRestedPlayers.contains(p)
          ? kRestAPlayerRecoveryMultiplier
          : 1.0;
      energy[p] =
          (energy[p]! +
                  fatigueRecoveryPerMinute(p.ratings.stamina) *
                      multiplier *
                      minutesThisPossession)
              .clamp(0.0, kMaxEnergy)
              .toDouble();
    }
    for (final p in awayRoster) {
      if (awayOnCourt.contains(p)) continue;
      final multiplier = awayRestedPlayers.contains(p)
          ? kRestAPlayerRecoveryMultiplier
          : 1.0;
      energy[p] =
          (energy[p]! +
                  fatigueRecoveryPerMinute(p.ratings.stamina) *
                      multiplier *
                      minutesThisPossession)
              .clamp(0.0, kMaxEnergy)
              .toDouble();
    }

    if (_offenseIsHome) {
      homeScore += result.pointsScored;
    } else {
      awayScore += result.pointsScored;
    }

    // `CoachingOption.stopTheBleeding`'s trigger: however many points the
    // *current* possession's team has scored, unanswered, right now. A
    // score resets the *other* side's run to 0 -- it doesn't touch this
    // side's own (a 0-point possession doesn't end a run either, only the
    // other team actually scoring does).
    if (result.pointsScored > 0) {
      if (_offenseIsHome) {
        homeUnansweredRun += result.pointsScored;
        awayUnansweredRun = 0;
      } else {
        awayUnansweredRun += result.pointsScored;
        homeUnansweredRun = 0;
      }
    }

    for (final event in result.events) {
      if (event.type != MatchEventType.shootingFoul &&
          event.type != MatchEventType.nonShootingFoul) {
        continue;
      }
      final foulingPlayer = event.player!;
      personalFouls[foulingPlayer] = (personalFouls[foulingPlayer] ?? 0) + 1;
      final foulerIsHome = homeRoster.contains(foulingPlayer);
      if (foulerIsHome) {
        _homeTeamFouls++;
      } else {
        _awayTeamFouls++;
      }

      if (personalFouls[foulingPlayer]! >= _personalFoulOutLimit) {
        fouledOut.add(foulingPlayer);
        if (foulerIsHome) {
          homeOnCourt = substituteForFoulOut(
            foulingPlayer: foulingPlayer,
            onCourt: homeOnCourt,
            roster: homeRoster,
            targetMinutes: homeTargetMinutes,
            minutesPlayed: minutesPlayed,
            fouledOut: fouledOut,
            rested: homeRestedPlayers,
          );
        } else {
          awayOnCourt = substituteForFoulOut(
            foulingPlayer: foulingPlayer,
            onCourt: awayOnCourt,
            roster: awayRoster,
            targetMinutes: awayTargetMinutes,
            minutesPlayed: minutesPlayed,
            fouledOut: fouledOut,
            rested: awayRestedPlayers,
          );
        }
      }
    }

    if (_secondsSinceSubCheck >= _substitutionCheckSeconds) {
      _secondsSinceSubCheck = 0;
      _repickOnCourt();
    }

    _offenseIsHome = !_offenseIsHome;
  }

  /// Simulates every possession of the current [quarter], start to finish
  /// -- the sync path, for [simulateMatch]. The Q4 late-game coaching
  /// break, when due, resolves synchronously inline via
  /// [_resolveBreakSync], then possessions continue in the same call --
  /// unlike [runSegment], which instead returns control so a real human
  /// pick can be awaited.
  void runPossessions() {
    startQuarterClock();
    while (_quarterClock > 0) {
      _processOnePossession();
      if (_isLateBreakDue) {
        _lateBreakFired = true;
        _resolveBreakSync(CoachingBreakStoppage.secondHalf);
      }
    }
    _finishQuarterScoring();
  }

  /// The live path's per-quarter possession runner, for
  /// [simulateMatchLive] -- like [runPossessions], but returns as soon as
  /// the quarter naturally ends (`false`) *or* the Q4 late-game break
  /// becomes due (`true`), instead of resolving that break inline.
  /// Callers must have already called [startQuarterClock] once for this
  /// quarter; calling this again after a `true` return resumes the *same*
  /// quarter's remaining possessions (nothing here re-initializes the
  /// clock), once whatever coaching pick applies has been.
  bool runSegment() {
    while (_quarterClock > 0) {
      _processOnePossession();
      if (_isLateBreakDue) {
        _lateBreakFired = true;
        return true;
      }
    }
    _finishQuarterScoring();
    return false;
  }

  /// Resolves the Q4 late-game break for [simulateMatchLive] -- the
  /// awaited counterpart to what [runPossessions] does inline via
  /// [_resolveBreakSync]. Only ever called after [runSegment] returns
  /// `true`.
  Future<void> resolveLateGameBreakLive() =>
      _resolveBreakLive(CoachingBreakStoppage.secondHalf);

  /// Advances to the next quarter and applies the halftime energy bump if
  /// the quarter that just finished was Q2. Always called immediately
  /// after [runPossessions] (or, on the live path, after [runSegment]
  /// finally returns `false`) -- kept separate so a live driver can hand
  /// this quarter's events to a UI before the next quarter's possessions
  /// start appending to the same list.
  void wrapUpQuarter() {
    quarter++;
    if (quarter == 3) {
      // Halftime: a flat +10 energy bump for every rostered player
      // (`fatigue.dart`'s kHalftimeEnergyBump), on top of the ordinary
      // bench-recovery trickle already applied above -- independent of
      // who's on court right at this instant.
      for (final p in [...homeRoster, ...awayRoster]) {
        energy[p] = (energy[p]! + kHalftimeEnergyBump)
            .clamp(0.0, kMaxEnergy)
            .toDouble();
      }
    }
  }

  MatchResult toMatchResult() => MatchResult(
    homeScore: homeScore,
    awayScore: awayScore,
    homeScoreByQuarter: homeScoreByQuarter,
    awayScoreByQuarter: awayScoreByQuarter,
    events: events,
    minutesPlayed: minutesPlayed,
    personalFouls: personalFouls,
    fouledOut: fouledOut,
    finalEnergy: energy,
  );
}
