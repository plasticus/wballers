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
/// callers keeps working exactly as before.
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
///   slot `OffenseShapeBonus`/`DefenseTacticBonus`/`coachMatchupBonus`
///   already share. Substitutions still don't react to it, though --
///   `pickOnCourt`/`targetMinutesFor` are driven purely by target minutes
///   and foul-outs, with no energy-aware "sit the gassed starter" logic
///   yet (that's the quarter-break coaching-options catalog's job,
///   `TODO.md` item 8, still blocked on its own undesigned catalog).
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
/// - **Coach Offense-vs-Defense matchup** (TODO.md's coach-stats item, a
///   direct GM ask): [homeCoach]/[awayCoach] are optional (`null` skips
///   the bonus entirely, e.g. an exhibition with no real per-team coach
///   assigned) -- when both are given, each team's own coach's
///   `CoachStats.offense` against the *other* coach's `CoachStats.defense`
///   ([coachMatchupBonus], `possession_engine.dart`) becomes that team's
///   flat rating bump whenever they're on offense, computed once here for
///   the whole game (coach stats don't change mid-game) rather than
///   re-derived every possession.
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
///   `defenseCoachingBonus`. Synchronous on purpose, for now: there's no
///   live, pause-for-a-human-tap game loop yet (this item's own
///   still-unbuilt "Architecture flagged" note) -- this is the
///   mechanical system made real, not the interactive UI around it.
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

/// The full mutable state and step-by-step logic for one game -- split out
/// of `simulateMatch`'s own body (2026-08-18, `TODO.md` item 8's live-game
/// architecture item) so a second, async driver can run the exact same
/// quarter-by-quarter logic one segment at a time (computing a quarter,
/// handing it to a live UI to show, awaiting a real coaching pick, then
/// continuing) instead of all the way through in one synchronous call, the
/// way [simulateMatch] itself still does and always will for every
/// AI-vs-AI game, the season simulator, and everything else that doesn't
/// need a human watching.
///
/// [simulateMatch] is a thin wrapper around this class: construct it, spin
/// [isComplete] into an ordinary loop calling [prepareQuarter] (skipped for
/// quarter 1, which is already set up by the constructor),
/// [runPossessions], and [wrapUpQuarter] each time around, then read the
/// result off [toMatchResult]. That loop -- not this class's internals --
/// is the whole public contract; every field and method below is private
/// precisely because the eventual live driver is the only other caller
/// that will ever need this level of control, and it doesn't exist yet.
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
  }) : homeOffenseCoachBonus = homeCoach == null || awayCoach == null
           ? 0.0
           : coachMatchupBonus(
               offenseCoachOffense: homeCoach.stats.offense,
               defenseCoachDefense: awayCoach.stats.defense,
             ),
       awayOffenseCoachBonus = homeCoach == null || awayCoach == null
           ? 0.0
           : coachMatchupBonus(
               offenseCoachOffense: awayCoach.stats.offense,
               defenseCoachDefense: homeCoach.stats.defense,
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
    tipOffWinnerIsHome = resolveTipOff(
      _random,
      _tallest(homeOnCourt),
      _tallest(awayOnCourt),
    );
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
  final OffenseShapeBonus homeOffenseBonus;
  final OffenseShapeBonus awayOffenseBonus;
  final DefenseTacticBonus homeDefenseBonus;
  final DefenseTacticBonus awayDefenseBonus;
  final String? homeDefenseTargetId;
  final String? awayDefenseTargetId;
  final CoachingOptionPicker? homeCoachingPicker;
  final CoachingOptionPicker? awayCoachingPicker;
  late final bool tipOffWinnerIsHome;

  // Game state -- mutated quarter to quarter and possession to
  // possession by [prepareQuarter]/[runPossessions]/[wrapUpQuarter].
  var quarter = 1;
  var homeScore = 0;
  var awayScore = 0;
  final homeScoreByQuarter = <int>[];
  final awayScoreByQuarter = <int>[];
  final events = <MatchEvent>[];
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

  /// Whether the whole game (regulation plus however many overtime
  /// periods it took) is over -- the exact condition `simulateMatch`'s
  /// old `while` loop used to keep going.
  bool get isComplete => quarter > _quarterCount && homeScore != awayScore;

  /// Offers (if a picker is supplied) and applies a coaching-option pick
  /// for each side independently, right now, for the current [quarter].
  /// [CoachingOption.fireTheTeamUp]/[CoachingOption.restAPlayer] apply
  /// once, immediately; everything else becomes that side's flat bonus
  /// for the rest of its duration. Synchronous -- see [simulateMatch]'s
  /// own doc comment on why that's still fine for now.
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
      if (picked == CoachingOption.fireTheTeamUp) {
        energy.addAll(applyFireTheTeamUp(energy, homeRoster));
      } else if (picked == CoachingOption.restAPlayer) {
        final toRest = pickPlayerToRest(energy, homeOnCourt);
        homeRestedPlayers = {?toRest};
      } else {
        homeCoachingBonus = coachingBonusFor(picked);
      }
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
      if (picked == CoachingOption.fireTheTeamUp) {
        energy.addAll(applyFireTheTeamUp(energy, awayRoster));
      } else if (picked == CoachingOption.restAPlayer) {
        final toRest = pickPlayerToRest(energy, awayOnCourt);
        awayRestedPlayers = {?toRest};
      } else {
        awayCoachingBonus = coachingBonusFor(picked);
      }
    }
  }

  /// Everything that happens *between* quarters, for whichever quarter is
  /// about to start (i.e. the current [quarter], already incremented by
  /// the previous [wrapUpQuarter] call) -- offering a coaching break (for
  /// quarters 2-4 only; there's no break before overtime) and re-picking
  /// each side's on-court five. Not called for quarter 1, which the
  /// constructor already sets up.
  void prepareQuarter() {
    // A pick's duration never outlives the stoppage that offered it --
    // clear everything before (maybe) offering a fresh one below, so a
    // stale pick can never silently carry into a quarter (or overtime)
    // nobody chose it for.
    homeCoachingBonus = kNoCoachingOptionBonus;
    awayCoachingBonus = kNoCoachingOptionBonus;
    homeRestedPlayers = {};
    awayRestedPlayers = {};
    if (quarter <= _quarterCount) {
      // Keyed off which quarter the pick is *for*, not which one just
      // ended -- only the end-of-Q1 break (deciding Q2) is firstHalf;
      // deciding Q3 or Q4 is secondHalf either way
      // (`CoachingBreakStoppage`'s own doc comment).
      _runCoachingBreak(
        quarter == 2
            ? CoachingBreakStoppage.firstHalf
            : CoachingBreakStoppage.secondHalf,
      );
    }
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

  /// Simulates every possession of the current [quarter], start to finish
  /// -- fouls, substitutions, fatigue, the coaching-option bonuses
  /// already set for this quarter by [prepareQuarter] (or the
  /// constructor, for quarter 1), and the extra Q4 late-game coaching
  /// break if this happens to be that quarter.
  void runPossessions() {
    final periodSeconds = quarter <= _quarterCount
        ? _quarterSeconds
        : _overtimeSeconds;
    var homeTeamFouls = 0;
    var awayTeamFouls = 0;
    var quarterClock = periodSeconds;
    var secondsSinceSubCheck = 0.0;
    // Only ever meaningful in Q4 (`_lateGameBreakClockSeconds` check
    // below), but declared fresh every quarter/period so it's never
    // accidentally left `true` from a prior quarter.
    var lateBreakFired = false;
    var offenseIsHome = quarter.isOdd
        ? tipOffWinnerIsHome
        : !tipOffWinnerIsHome;
    final homeScoreBeforeQuarter = homeScore;
    final awayScoreBeforeQuarter = awayScore;

    while (quarterClock > 0) {
      final offense = offenseIsHome ? homeOnCourt : awayOnCourt;
      final defense = offenseIsHome ? awayOnCourt : homeOnCourt;
      final defenseInBonus = offenseIsHome
          ? awayTeamFouls >= _teamFoulBonusThreshold
          : homeTeamFouls >= _teamFoulBonusThreshold;
      final offenseMargin = offenseIsHome
          ? homeScore - awayScore
          : awayScore - homeScore;

      final result = simulatePossession(
        _random,
        offense: offense,
        defense: defense,
        defenseInBonus: defenseInBonus,
        offenseMargin: offenseMargin,
        offenseIsHome: offenseIsHome,
        defenseIsHome: !offenseIsHome,
        offenseCoachBonus: offenseIsHome
            ? homeOffenseCoachBonus
            : awayOffenseCoachBonus,
        offenseBonus: offenseIsHome ? homeOffenseBonus : awayOffenseBonus,
        defenseBonus: offenseIsHome ? awayDefenseBonus : homeDefenseBonus,
        defenseTargetPlayerId: offenseIsHome
            ? awayDefenseTargetId
            : homeDefenseTargetId,
        energy: energy,
        offenseCoachingBonus: offenseIsHome
            ? homeCoachingBonus
            : awayCoachingBonus,
        defenseCoachingBonus: offenseIsHome
            ? awayCoachingBonus
            : homeCoachingBonus,
      );
      events.addAll(result.events);
      quarterClock -= result.secondsElapsed;
      secondsSinceSubCheck += result.secondsElapsed;

      final minutesThisPossession = result.secondsElapsed / 60;
      for (final p in offense) {
        minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
      }
      for (final p in defense) {
        minutesPlayed[p] = (minutesPlayed[p] ?? 0) + minutesThisPossession;
      }

      // Fatigue (`fatigue.dart`): everyone on court this possession
      // drains energy; everyone else on either bench recovers it. `offense`
      // and `defense` together are exactly `homeOnCourt` + `awayOnCourt`
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

      if (offenseIsHome) {
        homeScore += result.pointsScored;
      } else {
        awayScore += result.pointsScored;
      }

      // `CoachingOption.stopTheBleeding`'s trigger: however many points
      // the *current* possession's team has scored, unanswered, right
      // now. A score resets the *other* side's run to 0 -- it doesn't
      // touch this side's own (a 0-point possession doesn't end a run
      // either, only the other team actually scoring does).
      if (result.pointsScored > 0) {
        if (offenseIsHome) {
          homeUnansweredRun += result.pointsScored;
          awayUnansweredRun = 0;
        } else {
          awayUnansweredRun += result.pointsScored;
          homeUnansweredRun = 0;
        }
      }

      // The extra Q4-only coaching break, once per game -- "one more in
      // Q4 if the game is within 7 points... at the 2:00 mark" (`TODO.md`
      // item 8). Checked possession-by-possession like the ordinary
      // substitution-check timer, since there's no other mid-quarter
      // breakpoint in this loop.
      if (quarter == _quarterCount &&
          !lateBreakFired &&
          quarterClock <= _lateGameBreakClockSeconds &&
          (homeScore - awayScore).abs() <= _lateGameBreakMargin) {
        lateBreakFired = true;
        homeCoachingBonus = kNoCoachingOptionBonus;
        awayCoachingBonus = kNoCoachingOptionBonus;
        homeRestedPlayers = {};
        awayRestedPlayers = {};
        _runCoachingBreak(CoachingBreakStoppage.secondHalf);
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

      for (final event in result.events) {
        if (event.type != MatchEventType.shootingFoul &&
            event.type != MatchEventType.nonShootingFoul) {
          continue;
        }
        final foulingPlayer = event.player!;
        personalFouls[foulingPlayer] = (personalFouls[foulingPlayer] ?? 0) + 1;
        final foulerIsHome = homeRoster.contains(foulingPlayer);
        if (foulerIsHome) {
          homeTeamFouls++;
        } else {
          awayTeamFouls++;
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

      if (secondsSinceSubCheck >= _substitutionCheckSeconds) {
        secondsSinceSubCheck = 0;
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

      offenseIsHome = !offenseIsHome;
    }

    homeScoreByQuarter.add(homeScore - homeScoreBeforeQuarter);
    awayScoreByQuarter.add(awayScore - awayScoreBeforeQuarter);
  }

  /// Advances to the next quarter and applies the halftime energy bump if
  /// the quarter that just finished was Q2. Always called immediately
  /// after [runPossessions] -- the two aren't merged into one method so a
  /// future live driver can hand this quarter's [events] to a UI (reading
  /// them off before the next quarter's possessions start appending to
  /// the same list) between the two calls.
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
