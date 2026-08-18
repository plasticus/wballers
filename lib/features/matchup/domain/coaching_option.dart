import 'dart:math';

import '../../match/engine/fatigue.dart' show kMaxEnergy;
import '../../player/domain/player.dart';

/// The 10 quarter-break/timeout coaching nudges a GM can pick from --
/// catalog locked 2026-08-17 (`0B_Planned.md`'s quarter-break bullet).
/// Every option nets more "pro" than "con" on purpose: there's no morale
/// mechanic in this game, and these are explicitly standing in for one
/// (a direct GM call, same date) -- "give them a plan," not a min-maxed
/// lever. A pick lasts exactly as long as the stoppage that offered it:
/// a full quarter at an ordinary break, or the remaining ~2 minutes at
/// the Q4 2:00-mark stoppage (`TODO.md` item 8's "within 7 points" rule
/// for when that extra stoppage exists at all).
enum CoachingOption {
  focusDefense,
  focusOffense,
  fullCourtPress,
  parkTheBus,
  paceYourself,
  pickUpThePace,
  fireTheTeamUp,
  attackTheBoards,
  restAPlayer,
  stopTheBleeding,
}

extension CoachingOptionInfo on CoachingOption {
  /// The name shown on the coaching-break sheet.
  String get label => switch (this) {
    CoachingOption.focusDefense => 'Focus Defense',
    CoachingOption.focusOffense => 'Focus Offense',
    CoachingOption.fullCourtPress => 'Full-Court Press',
    CoachingOption.parkTheBus => 'Park the Bus',
    CoachingOption.paceYourself => 'Pace Yourself',
    CoachingOption.pickUpThePace => 'Pick Up the Pace',
    CoachingOption.fireTheTeamUp => 'Fire the Team Up!',
    CoachingOption.attackTheBoards => 'Attack the Boards',
    CoachingOption.restAPlayer => 'Rest a Player',
    CoachingOption.stopTheBleeding => 'Stop the Bleeding',
  };

  /// A quick shorthand of what the option does, same "read at a glance"
  /// spirit as `defensive_tactic.dart`'s `shorthand`.
  String get shorthand => switch (this) {
    CoachingOption.focusDefense => 'Defense +5%, offense -2.5%, this quarter.',
    CoachingOption.focusOffense => 'Offense +5%, defense -2.5%, this quarter.',
    CoachingOption.fullCourtPress =>
      "Defense +5%. Burns more stamina, but slows the opponent's own "
          'possessions way down.',
    CoachingOption.parkTheBus =>
      'Drains the clock on both ends -- no rating change.',
    CoachingOption.paceYourself =>
      'Slows the game down on both ends, a little easier on the legs.',
    CoachingOption.pickUpThePace =>
      'Faster possessions, Disruption +5%, burns a bit more stamina -- '
          'the comeback push.',
    CoachingOption.fireTheTeamUp => '+5 energy, whole roster, right now.',
    CoachingOption.attackTheBoards =>
      'Rebounding +5%, Perimeter Defense -2.5%.',
    CoachingOption.restAPlayer =>
      "Sits whoever's most gassed for the rest of the stretch, with a "
          'bigger recovery bump. No picker -- the coach reads the bench.',
    CoachingOption.stopTheBleeding =>
      'Defense +5%, no downside -- only offered when the opponent is '
          'mid an unanswered run.',
  };
}

/// Continuous per-possession rating/pace/stamina nudges a [CoachingOption]
/// applies to whichever team picked it, for the rest of its duration.
/// Doesn't cover [CoachingOption.fireTheTeamUp] or [CoachingOption.restAPlayer]
/// -- both are one-time state changes ([applyFireTheTeamUp]/
/// [pickPlayerToRest] below), not a per-possession bonus, so
/// [coachingBonusFor] resolves both to [kNoCoachingOptionBonus].
typedef CoachingOptionBonus = ({
  /// Flat, every offensive rating contest this team touches (drive,
  /// jumper, pass, free throw).
  double offenseBonus,

  /// Flat, every defensive rating contest this team touches (interior/
  /// perimeter shot defense, blocking) -- NOT disruption or rebounding,
  /// which get their own dedicated fields below since some options
  /// target one specifically without touching the other.
  double defenseBonus,

  /// Added on top of [defenseBonus] for pass-disruption specifically --
  /// only ever nonzero for [CoachingOption.pickUpThePace].
  double disruptionBonus,

  /// Added on top of [defenseBonus] for perimeter shot defense
  /// specifically -- only ever nonzero for [CoachingOption.attackTheBoards]'s
  /// trade-off.
  double perimeterDefenseBonus,

  /// This team's rebounding at both ends (offensive and defensive
  /// boards) -- a dedicated field rather than folded into [offenseBonus]/
  /// [defenseBonus], since "crash the boards" shouldn't also boost
  /// drives or shot defense.
  double reboundingBonus,

  /// Extra seconds added to this team's own action-seconds roll while
  /// they're on offense (`possession_engine.dart`'s `_rollActionSeconds`)
  /// -- the same knob `kBlowoutPaceMargin` already uses automatically,
  /// just coach-picked instead of score-triggered. Negative for
  /// [CoachingOption.pickUpThePace] (speeds its own offense up).
  double ownPaceSecondsBonus,

  /// Extra seconds added to the *opponent's* action-seconds roll while
  /// this team is on defense -- only ever nonzero for
  /// [CoachingOption.fullCourtPress].
  double opponentPaceSecondsBonus,

  /// Multiplies this team's on-court players' `fatigueDrainPerMinute`
  /// (`fatigue.dart`) for the duration, regardless of which side of the
  /// ball they're on. 1.0 is "no change."
  double staminaDrainMultiplier,
});

/// "No effect" -- every field zero (1.0 for the multiplier), so a caller
/// that doesn't pass a [CoachingOptionBonus] at all (every possession-
/// level test, and every AI-vs-AI game with no coaching picker supplied)
/// behaves exactly like before this system existed.
const kNoCoachingOptionBonus = (
  offenseBonus: 0.0,
  defenseBonus: 0.0,
  disruptionBonus: 0.0,
  perimeterDefenseBonus: 0.0,
  reboundingBonus: 0.0,
  ownPaceSecondsBonus: 0.0,
  opponentPaceSecondsBonus: 0.0,
  staminaDrainMultiplier: 1.0,
);

/// [CoachingOption.fullCourtPress]'s opponent-pace penalty -- "slows the
/// clock ONLY for opponent (like if an event is currently every 3s, we
/// double it to 6s)," a direct GM spec (2026-08-17). A possession's base
/// action roll is uniform(1,5)s (mean 3s); +3.0s flat roughly doubles
/// that mean to 6s.
const kFullCourtPressOpponentPaceSeconds = 3.0;

/// [CoachingOption.fullCourtPress]'s own-team stamina cost -- "increase
/// stamina loss... just a push" (a direct GM spec, magnitude left to be
/// filled in, 2026-08-17). Reuses `fatigue.dart`'s drain-formula shape
/// rather than one flat number, so it still scales off each player's own
/// Stamina rating instead of hitting a 99-Stamina and 50-Stamina player
/// identically.
const kFullCourtPressStaminaMultiplier = 1.4;

/// [CoachingOption.parkTheBus]/[CoachingOption.paceYourself]'s pace
/// penalty, applied to *both* teams' possessions -- "drain the clock on
/// both sides of the ball" / "slows the game down on both ends." Park
/// the Bus is the more extreme call (no other tradeoff, so it leans on
/// the same magnitude `possession_engine.dart`'s automatic blowout-pace
/// rubber-banding already uses); Pace Yourself is the gentler version,
/// paired with an actual stamina benefit below.
const kParkTheBusPaceSeconds = 5.0;
const kPaceYourselfPaceSeconds = 2.0;

/// [CoachingOption.paceYourself]'s stamina relief -- "slightly reduces
/// stamina drain."
const kPaceYourselfStaminaMultiplier = 0.85;

/// [CoachingOption.pickUpThePace]'s own-offense speedup -- "less time
/// between events/shots." Negative, clamped at `possession_engine.dart`'s
/// own action-seconds floor so it can never roll a nonsensical near-zero
/// possession.
const kPickUpThePacePaceSeconds = -1.0;

/// [CoachingOption.pickUpThePace]'s stamina cost -- "increases stamina
/// drain by a bit," smaller than Full-Court Press's push since this is a
/// tempo call, not a full defensive scheme change.
const kPickUpThePaceStaminaMultiplier = 1.2;

/// [CoachingOption]'s mechanical effect -- the actual locked numbers
/// (2026-08-17 GM sign-off on every one). Magnitudes deliberately match
/// the engine's existing bonus scale (coach-matchup cap 5%, offense/
/// defense-tactic bonuses "comfortably under" 5%, home court 2.5%) -- no
/// separate calibration pass needed. `null` (no option active) and the 2
/// instant-action options both resolve to [kNoCoachingOptionBonus].
CoachingOptionBonus coachingBonusFor(CoachingOption? option) {
  if (option == null) return kNoCoachingOptionBonus;
  return switch (option) {
    CoachingOption.focusDefense => (
      offenseBonus: -0.025,
      defenseBonus: 0.05,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: 0.0,
      opponentPaceSecondsBonus: 0.0,
      staminaDrainMultiplier: 1.0,
    ),
    CoachingOption.focusOffense => (
      offenseBonus: 0.05,
      defenseBonus: -0.025,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: 0.0,
      opponentPaceSecondsBonus: 0.0,
      staminaDrainMultiplier: 1.0,
    ),
    CoachingOption.fullCourtPress => (
      offenseBonus: 0.0,
      defenseBonus: 0.05,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: 0.0,
      opponentPaceSecondsBonus: kFullCourtPressOpponentPaceSeconds,
      staminaDrainMultiplier: kFullCourtPressStaminaMultiplier,
    ),
    CoachingOption.parkTheBus => (
      offenseBonus: 0.0,
      defenseBonus: 0.0,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: kParkTheBusPaceSeconds,
      opponentPaceSecondsBonus: kParkTheBusPaceSeconds,
      staminaDrainMultiplier: 1.0,
    ),
    CoachingOption.paceYourself => (
      offenseBonus: 0.0,
      defenseBonus: 0.0,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: kPaceYourselfPaceSeconds,
      opponentPaceSecondsBonus: kPaceYourselfPaceSeconds,
      staminaDrainMultiplier: kPaceYourselfStaminaMultiplier,
    ),
    CoachingOption.pickUpThePace => (
      offenseBonus: 0.0,
      defenseBonus: 0.0,
      disruptionBonus: 0.05,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: kPickUpThePacePaceSeconds,
      opponentPaceSecondsBonus: 0.0,
      staminaDrainMultiplier: kPickUpThePaceStaminaMultiplier,
    ),
    CoachingOption.attackTheBoards => (
      offenseBonus: 0.0,
      defenseBonus: 0.0,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: -0.025,
      reboundingBonus: 0.05,
      ownPaceSecondsBonus: 0.0,
      opponentPaceSecondsBonus: 0.0,
      staminaDrainMultiplier: 1.0,
    ),
    CoachingOption.stopTheBleeding => (
      offenseBonus: 0.0,
      defenseBonus: 0.05,
      disruptionBonus: 0.0,
      perimeterDefenseBonus: 0.0,
      reboundingBonus: 0.0,
      ownPaceSecondsBonus: 0.0,
      opponentPaceSecondsBonus: 0.0,
      staminaDrainMultiplier: 1.0,
    ),
    // Instant, one-time state changes -- no continuous per-possession
    // bonus. See applyFireTheTeamUp/pickPlayerToRest below.
    CoachingOption.fireTheTeamUp ||
    CoachingOption.restAPlayer => kNoCoachingOptionBonus,
  };
}

/// [CoachingOption.fireTheTeamUp]'s flat energy bump -- "+5 energy for
/// the whole roster, right now" (2026-08-17, a direct GM ask).
const kFireTheTeamUpEnergyBoost = 5.0;

/// Applies [CoachingOption.fireTheTeamUp]: every player in [roster] (not
/// just whoever's currently on court -- "whole roster") gets
/// [kFireTheTeamUpEnergyBoost] added, immediately, clamped to
/// `fatigue.dart`'s own energy-pool ceiling. A pure function returning a
/// new map rather than mutating [energy] in place, same
/// non-destructive-by-default posture the rest of this domain layer
/// uses -- `match_engine.dart` merges the result back into its own
/// mutable energy map.
Map<Player, double> applyFireTheTeamUp(
  Map<Player, double> energy,
  List<Player> roster,
) {
  final result = Map<Player, double>.from(energy);
  for (final p in roster) {
    final current = result[p] ?? kMaxEnergy;
    result[p] = (current + kFireTheTeamUpEnergyBoost)
        .clamp(0.0, kMaxEnergy)
        .toDouble();
  }
  return result;
}

/// [CoachingOption.restAPlayer]'s extra energy-recovery multiplier on top
/// of the ordinary bench trickle (`fatigue.dart`'s
/// `fatigueRecoveryPerMinute`) while its pick sits out the rest of the
/// duration -- "a bigger-than-usual energy recovery bump."
const kRestAPlayerRecoveryMultiplier = 2.0;

/// [CoachingOption.restAPlayer]'s pick -- whoever in [onCourt] currently
/// has the lowest energy. Deliberately no GM player-picker (2026-08-17,
/// a direct GM call, after flagging a full player-select screen as "too
/// complicated"): "a coach's read of the bench, not a screen to
/// micromanage." `null` only if [onCourt] is empty (never true for a
/// real 5-on-court game).
Player? pickPlayerToRest(Map<Player, double> energy, List<Player> onCourt) {
  if (onCourt.isEmpty) return null;
  return onCourt.reduce(
    (a, b) => (energy[a] ?? kMaxEnergy) <= (energy[b] ?? kMaxEnergy) ? a : b,
  );
}

/// Point threshold for an "unanswered run" to make
/// [CoachingOption.stopTheBleeding] eligible -- "only offered if the
/// opponent's on an unanswered run (8+ points, no answer) right before
/// the stoppage" (2026-08-17, a direct GM ask).
const kStopTheBleedingRunThreshold = 8;

/// How many options are offered at a given break -- "the GM sees only
/// ~3 choices at a time" (`0B_Planned.md`'s original quarter-break
/// sketch, still true post-selection-logic-lock).
const kCoachingOptionsOfferedCount = 3;

/// Which stoppage a coaching break happens at -- drives
/// [CoachingOption.parkTheBus]'s 2nd-half-only eligibility ("maybe Park
/// the Bus is only a 2nd half option," a direct GM call, 2026-08-17).
/// Keyed off which quarter the pick is *for*, not which quarter just
/// ended: the end-of-Q1 break (deciding Q2) is the only [firstHalf]
/// break -- halftime (deciding Q3), end-of-Q3 (deciding Q4), and the Q4
/// 2:00-mark stoppage (deciding the final ~2 minutes, `TODO.md` item 8)
/// are all [secondHalf].
enum CoachingBreakStoppage { firstHalf, secondHalf }

/// The 3 options offered at a given break -- selection logic locked
/// 2026-08-17 (`0B_Planned.md`'s quarter-break bullet): "I pretty much
/// assume it'll be random-ish, not situational (except StB)," with
/// exactly 2 eligibility gates on top of an otherwise-equal-odds random
/// draw:
///
/// 1. [CoachingOption.stopTheBleeding] is *guaranteed* one of the 3 slots
///    when [opponentUnansweredRun] hits [kStopTheBleedingRunThreshold] --
///    not just added to the random pool ("the free pass is earned by the
///    situation").
/// 2. [CoachingOption.parkTheBus] only enters the random pool at
///    [CoachingBreakStoppage.secondHalf].
///
/// Everything else is an equal-odds random draw, via [random], for
/// whatever slots remain.
List<CoachingOption> offerCoachingOptions(
  Random random, {
  required CoachingBreakStoppage stoppage,
  required int opponentUnansweredRun,
}) {
  final stopTheBleedingEligible =
      opponentUnansweredRun >= kStopTheBleedingRunThreshold;
  final randomPool = [
    CoachingOption.focusDefense,
    CoachingOption.focusOffense,
    CoachingOption.fullCourtPress,
    CoachingOption.paceYourself,
    CoachingOption.pickUpThePace,
    CoachingOption.fireTheTeamUp,
    CoachingOption.attackTheBoards,
    CoachingOption.restAPlayer,
    if (stoppage == CoachingBreakStoppage.secondHalf) CoachingOption.parkTheBus,
  ]..shuffle(random);

  final offered = <CoachingOption>[
    if (stopTheBleedingEligible) CoachingOption.stopTheBleeding,
  ];
  final remainingSlots = kCoachingOptionsOfferedCount - offered.length;
  offered.addAll(randomPool.take(remainingSlots));
  return offered;
}

/// Everything a [CoachingOptionPicker] needs to decide -- a snapshot,
/// not a live reference, so nothing in here changes after the picker is
/// called. [offered] is already-filtered/drawn via [offerCoachingOptions]
/// -- a picker chooses from this list (or returns `null` to skip), it
/// doesn't re-run selection logic itself.
typedef CoachingBreakContext = ({
  int quarter,
  int ownScore,
  int opponentScore,
  int opponentUnansweredRun,
  List<CoachingOption> offered,
});

/// A caller-supplied decision for one side's coaching break --
/// `match_engine.dart`'s `simulateMatch` callers pass one of these to opt
/// a team into real coaching-option picks; omitting it (the default)
/// means that side never gets offered anything, same "AI always
/// Balanced" posture `defensive_tactic.dart` already established for
/// [DefensiveTactic]. Synchronous -- answered immediately, not awaited --
/// which is exactly right for every caller of `simulateMatch` itself
/// (every AI-vs-AI game, the season simulator; nobody's watching, so
/// there's nothing to pause for). [LiveCoachingPicker] below is the real,
/// awaitable version, for `simulateMatchLive`'s one actual human-watched
/// game (2026-08-18, `TODO.md` item 8's live-game architecture work).
typedef CoachingOptionPicker =
    CoachingOption? Function(CoachingBreakContext context);

/// [CoachingOptionPicker]'s async twin -- `match_engine.dart`'s
/// `simulateMatchLive` awaits one of these at each real break instead of
/// calling it synchronously, so a live screen can actually show the
/// coaching-break sheet and wait for the GM's tap before the game
/// continues. Same contract otherwise: choose one of [context]'s
/// `offered` options, or resolve to `null` to skip the break entirely.
typedef LiveCoachingPicker =
    Future<CoachingOption?> Function(CoachingBreakContext context);
