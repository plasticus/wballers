# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Coaching

1. **Wire up the coach stats that still do nothing** — confirmed 2026-08-10: only Development affects anything real (`training_advancer.dart`'s growth multiplier). Offense/Defense are the buildable half: a real match-simulation modifier off the GM's own coach's stats, the same pattern `kHomeAdvantageBonus` already uses for home-court advantage (`possession_engine.dart`) -- a flat rating bump/penalty for the team, not a full Phase 3 tactics system. Motivation and Management are a bigger lift and stay blocked: they're tied to systems that don't exist anywhere in the codebase yet (morale/chemistry, trades), so those two ride along with whichever system lands first, same as the original note said.
