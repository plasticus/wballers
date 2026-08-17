/// Per-player energy tracking for one game (`0B_Planned.md`'s Phase 3
/// stamina appendix, promoted to a blocker 2026-08-17 ahead of the
/// quarter-break coaching-options work -- several sketched coaching
/// options act directly on stamina/fatigue, which didn't exist yet).
///
/// Energy is tracked entirely inside `simulateMatch`, keyed by [Player],
/// starting at [kMaxEnergy] for every one of the 24 rostered players (not
/// just whoever's on court) and never persisted or read outside that one
/// game -- a direct GM call (2026-08-17): fatigue does not carry between
/// games, only within one.
///
/// Formulas sanity-checked by hand (2026-08-17) against
/// `substitution_policy.dart`'s target-minutes table before being locked
/// in -- see `TODO.md` item 8's sub-note for the worked cases (a
/// 99-stamina star at her 30-minute target ends barely fatigued; a
/// 50-stamina player forced into the same minutes takes a real,
/// noticeable hit) -- and this file's own diagnostic
/// (`tool/fatigue_diagnostic.dart`) validates the same formulas against
/// real generated rosters and real bench-rotation behavior across many
/// simulated games, not just hand-picked scenarios.
library;

/// Starting/ceiling value of every player's energy pool for a game.
const kMaxEnergy = 100.0;

/// Energy below which a fatigue penalty starts applying at all -- a
/// player above this is at full effectiveness regardless of exactly how
/// far above.
const kFatigueThreshold = 80.0;

/// Stat penalty per point of energy lost below [kFatigueThreshold] --
/// 0.5%, so a player run all the way down to 0 energy caps out around a
/// 40% penalty (`(80 - 0) * 0.5%`). Deliberately far above every other
/// rating modifier in `possession_engine.dart` (home court 2.5%, traits
/// 5%, coach-matchup cap 5%, offense shape/defensive tactic "comfortably
/// under" 5%) -- confirmed intentional (2026-08-17): full exhaustion is
/// meant to be a severe, unmissable penalty, not another small tactical
/// nudge. The old "floor of 50% minimum effectiveness" language from the
/// original design note was dead -- unreachable given a 0-100 energy
/// pool -- and has been dropped in favor of the real ~40% ceiling this
/// formula actually produces.
const kFatiguePenaltyPerEnergyPoint = 0.005;

/// Flat energy bump every rostered player (on court or not) gets once, at
/// halftime -- on top of the ordinary bench-recovery trickle below.
const kHalftimeEnergyBump = 10.0;

/// How much energy a minute of live action drains, as a function of the
/// player's own [stamina] rating (1-99 scale): `2.6 * (1.5 - stamina/100)`.
/// A 99-stamina star drains ~1.33/min, a 70-stamina average player
/// ~2.08/min, a 50-stamina player 2.60/min. **Retuned (2026-08-17)**
/// from the original design note's `2 * (...)` -- the first pass (with
/// [fatigueRecoveryPerMinute] at parity below) left even the heaviest-
/// used rotation tier averaging under a 2% penalty across a real
/// 20-game diagnostic run (`tool/fatigue_diagnostic.dart`), a direct GM
/// call that ordinary heavy-minute play should feel it more, not just
/// foul-trouble/blowout/OT edge cases. Re-validated against the same
/// diagnostic before locking in -- see that file's own doc comment for
/// the retune's actual numbers.
double fatigueDrainPerMinute(int stamina) => 2.6 * (1.5 - stamina / 100);

/// How much energy a minute spent off the floor recovers, as a function
/// of [stamina] -- scales the same direction as the drain rate (good
/// conditioning helps both ends): `0.6 * stamina/100`. New for this pass
/// (2026-08-17, not in the original design note) -- without it, nothing
/// relieves fatigue mid-game except the one flat [kHalftimeEnergyBump],
/// which would leave the coaching-option "pick a recovery play" idea
/// (still blocked on its own undesigned catalog) as the *only* relief
/// valve. **Retuned down from an initial `1.0 * stamina/100`** alongside
/// the drain-rate bump above, same reason and same re-validation.
double fatigueRecoveryPerMinute(int stamina) => 0.6 * stamina / 100;

/// The rating-multiplier delta [energy] currently costs a player -- 0
/// (no penalty) at or above [kFatigueThreshold], increasingly negative
/// below it. Summed into `possession_engine.dart`'s existing per-player
/// bonus accumulator (the same slot `OffenseShapeBonus`/
/// `DefenseTacticBonus`/`coachMatchupBonus` already share) at every
/// rating contest a fatigued player touches, via that file's
/// `_fatigueBonus` helper (2026-08-17, wired in for real).
double fatigueBonusFor(double energy) {
  if (energy >= kFatigueThreshold) return 0.0;
  return -(kFatigueThreshold - energy) * kFatiguePenaltyPerEnergyPoint;
}
