# Coaching stats: Motivation & Management — status and open scoping

Everything scattered across `Aug10Questions.md`, `TODO.md`, `0A_Completed.md`,
`0D_Season_2_Roadmap.md`, and `old-mds/FLUTTER_APP_PLAN.md`/`question.md`
about the coach stat block, gathered in one place (2026-08-19, a direct GM
ask: "I can't look at them at the same time"). Originally existed because
Motivation and Management were the 2 stats that didn't do enough — both are
now locked (2026-08-19), so this file mostly records *why* they landed
where they did.

## The 5 stats, original intent (`old-mds/question.md` decision 15 /
`old-mds/FLUTTER_APP_PLAN.md`)

> Coaches carry a small stat block, deliberately much smaller than player
> ratings: Offense, Defense, Development, Motivation, and Management.
> Offense/Defense affect in-game tactical calls (Phase 3), Development
> affects player growth (Phase 2), Motivation affects morale/chemistry
> (Phase 2) and close-game resilience (Phase 3), and Management affects
> trade/draft shrewdness (Phase 2). Defined in Phase 1 alongside player
> identity, matching how player ratings are defined before their systems
> exist.

All 5 were deliberately generated, displayed, and persisted from day one,
before any of them had a real consumer — same "define the number before
the system that uses it" pattern player ratings themselves went through.

## Where each one actually stands today

| Stat | Original intent | Actually wired to |
|---|---|---|
| **Offense** | In-game tactical calls | ✅ Built — `possession_engine.dart`/`match_engine.dart`: attacking coach's Offense vs. defending coach's Defense, a real per-possession bonus. |
| **Defense** | In-game tactical calls | ✅ Built — same mechanism as Offense, above. |
| **Development** | Player growth speed | ✅ Built — training growth (the very first stat wired in). |
| **Motivation** | Morale/chemistry + close-game resilience | ✅ Built, narrower scope — see below. |
| **Management** | Trade/draft shrewdness | ✅ Built — Hidden Gems (draft) + trade-value swing math (trading), see `trading-and-hidden-gems-notes.md`. |

## Motivation — locked 2026-08-19, in-game-coaching only

**The scope, decided for good:** Motivation is *purely* in-game coaching
influence now — how much it amplifies a coach's quarter-break coaching-
option picks. The morale/chemistry and close-game-resilience halves of the
original pitch are dropped, not just unbuilt — a direct GM call: "I want to
drop the other ideas for motivation, as of now. It's simply in-game
motivation from coach, so it does more with the quarterly coaching."

**For a GM who mostly sims games:** Motivation's only real effect fires
through `LiveCoachingPicker`/`CoachingOptionPicker` — a real quarter-break
pick actually being made (`match_engine.dart`'s `homeCoachingPicker`/
`awayCoachingPicker`). The bulk-sim path (`simulateMatch` with no picker
attached — every AI-vs-AI game, and the GM's own games whenever they choose
"sim instead of watch") never calls into a coaching option at all, so
Motivation does nothing for those games. **If most of your games get
simmed rather than watched live, Motivation isn't a stat worth chasing.**

Two real hooks, both shipped:

- `retirement_advancer.dart`'s `attemptRetirementPersuasion`: when a player
  on the GM's own roster is a pending retirement decision, the coach's
  Motivation drives a skill check (`resolvePendingRetirement`,
  `current_franchise_provider.dart`) — clamped between `kMinPersuasionChance`/
  `kMaxPersuasionChance` (10%/90%, first-pass numbers) so a maxed coach can
  never *guarantee* a stay and a bottomed-out one can never make it
  *impossible*. Shipped 2026-08-11 (`0A_Completed.md`) — an acknowledged
  imperfect thematic fit ("the closest of the 5 `CoachStats` to 'keep a
  veteran playing'"), not itself part of the in-game-coaching scope above.
- **In-game coaching, shipped 2026-08-19** — the real reason this stat
  exists now: Motivation scales the quarter-break coaching-option bonuses
  (`coaching_option.dart`'s `motivationBonusMultiplier`/
  `applyMotivationToCoachingBonus`, wired into `match_engine.dart`). Linear,
  0.25x at Motivation 1 up to 1.75x at 99, anchored so the scale's exact
  midpoint (50) is 1.0x — "the coach has 50 motivation, they just get the
  standard bonuses," the GM's own spec, verbatim. Applies to the 5 rating-
  percentage fields (offense/defense/disruption/perimeter-defense/
  rebounding) on whichever tradeoff option a coach's pick resolves to, both
  the pro and con side alike; deliberately leaves the pace-seconds/stamina-
  multiplier fields alone. Verified end-to-end: a maxed-Motivation coach
  calling Focus Defense every break suppresses the opponent's scoring more,
  over 150 sample games, than a neutral coach making the identical call.

## Management — built 2026-08-19, `trading-and-hidden-gems-notes.md`

Two real hooks:

- **Hidden Gems** (the draft): a coach's Management gives their draft pick
  a real skill-point bonus, linear from 0 at Management ≤30 up to
  +12/+24/+36 (rounds 1/2/3) at Management 79 (the real generation
  ceiling). Applies to every team's own picks, GM and AI alike, off each
  team's own head coach.
- **Trade-value swing math**: how large a value mismatch a coach's
  Management can get a GM-facing trade through — `tradeSwing(management)`,
  concave, floored so even the worst real coach can always trade same-OVR
  players. Powers the GM's own Trade Board (`trade_offer_generator.dart`).

**Deliberately not factored in:** the off-season AI-to-AI trade pass
(`ai_offseason_trade_advancer.dart`, 2026-08-19) uses a flat
`kAiOffseasonTradeMaxGap` (36) for every trade regardless of either team's
own Management — a direct GM spec ("Max gap of 36"), not tied to the
Management-driven `tradeSwing` formula the GM-facing board uses. Two
separate trade systems, two separate value-gap rules, on purpose.
