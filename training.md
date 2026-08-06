# Women's Basketball Manager — Training & Player Development

**Status: proposal, not decided.** Everything below is a starting point for
discussion, not a locked design the way `traits.md`/`star_system.md`
document already-built systems. Where I have a real opinion I've stated it
plainly; where it's genuinely your call, it's called out in "Open
questions" at the bottom rather than snuck into the design as a fait
accompli.

## What already exists, waiting for this system

Nothing about training is built yet, but several pieces already assume it
will be, and this proposal is built to slot into them rather than invent
parallel machinery:

- **`PlayerRatings.potential`** — a separate ceiling rating, already
  rolled wider and upward-skewed at generation so even a weak roster can
  hide a gem (`old-mds/question.md` decision on `generatePlayer`). The
  clear implication: current ratings are meant to move toward this over
  time, not sit fixed for a player's whole career.
- **`CoachStats.development`** — its own doc comment already says what
  it's for: "how much this coach accelerates player growth (Phase 2
  player development)."
- **Traits already written for this** (`traits.md`, "Work ethic /
  development" section): **High/Low Potential** (trains faster/slower,
  more/less likely to reach the ceiling), **Highly Coachable/Stubborn**
  (amplify or dampen a good Development coach's effect), **Gym Rat**
  (keeps improving in the offseason without needing focused coaching
  attention; ages more gracefully).
- **`RosterStatus.developmental`** — at most 2 active-roster-exempt
  slots, restricted to `yearsOfService <= 3`
  (`kMaxDevelopmentalYearsOfService`). Real WNBA two-way/hardship
  framing aside, in-game this reads as "a slot for a young player you're
  actively investing in" — a natural lever for this system to hook into
  without inventing a new one.
- **`star_system.md`'s "Breakout Dilemma"** — explicitly describes a
  3-star youngster or 4-star starter "exploding statistically during a
  deep playoff run" and having their overall rating increase as a
  result, mid-season, from performance, not from an offseason menu.
  That's real design intent already on record, and it points toward
  performance-driven growth being part of this, not just a coach-managed
  training screen.
- **`age`/`yearsOfService`** — players generate at age 20-34, with
  `yearsOfService` rolled independently from a separate debut age
  (19-28), specifically so an international rookie debuting late is a
  natural outcome. No age curve exists yet, but the range is already
  sitting there waiting for one.
- **`0B_Planned.md`'s Phase 4 list** explicitly parks "Training plans,
  facilities, chemistry, player goals..." as *later, richer* work. Read
  together with `CoachStats.development` being framed as Phase 2, the
  implication is that development itself should land now, but a
  GM-facing training-plan UI shouldn't — see the proposal below.

## Proposed model: two growth channels, no new screen

### Channel 1 — performance-driven growth (automatic)

Ties directly into what the match engine already tracks (minutes played,
box score) rather than needing new state. Resolved **once, at season
end** — not continuously game-by-game — which keeps this simple, avoids
needing any UI before Phase 4, and matches the project's existing
turn-based/seeded architecture (every other generation step in this game
is a deterministic function of a season's accumulated state, not a
running simulation).

A player's rating drift for the season is a function of:

1. **Gap to potential** — more room to grow, more likely to grow.
   A player already at or above their potential has ~nothing left here
   (below, more on whether potential itself should ever move).
2. **Age curve** — see below.
3. **Minutes played that season** — reps. A player who barely played
   gets little from this channel regardless of talent (this is *also*
   the honest answer to "why would a bench scrub ever become a star" --
   they mostly don't, unless something else intervenes, which is
   realistic).
4. **Coach's `development` stat** — a straightforward multiplier on the
   whole thing.
5. **Traits** — High/Low Potential and Highly Coachable/Stubborn modify
   #4's effective strength; Gym Rat adds a smaller *unconditional* floor
   independent of coach quality (matches its written description:
   "without needing focused coaching attention").

Past a threshold age, this channel flips sign — ratings drift down
instead of up, with Gym Rat's "ages more gracefully" softening (not
eliminating) the decline.

### Channel 2 — the Developmental slot (reuses what's already built)

Being on `RosterStatus.developmental` applies a flat multiplier on top of
Channel 1 for that player's season -- already eligibility-gated by
`yearsOfService <= 3`, so this doesn't need any new restriction, just a
number. This is what makes "a young prospect getting the Developmental
slot and inconsistent minutes" a real, distinct strategy from "a young
prospect getting real rotation minutes" -- the first trades reps for a
guaranteed multiplier, the second trades a smaller multiplier for more
reps. Different bets for different rosters, no new UI to support it.

### The GM's actual lever: none new, on purpose

I'd deliberately *not* add a training-plan/training-focus screen in this
pass. The only levers that matter are ones the GM is already pulling for
other reasons -- who plays minutes, who's on the Developmental slot, who
they hired as coach. Training becomes a natural consequence of roster
decisions already being made, not a new menu competing for attention.

Two things point the same direction here: `0B_Planned.md` explicitly
parks "training plans" as later, richer Phase 4 work (implying whatever
lands now should be simpler than that), and your own steer on nicknames
earlier this project -- earned through play, never a GM-set slider --
generalizes cleanly to this: a breakout or a decline should read as
something that *happened to* a player because of how the season went,
not a number the GM dialed up directly.

## A concrete draft, so there's something to react to

Rough shape, not a real formula yet:

- A young (roughly 20-23), high-potential player getting starter minutes
  on a Developmental slot with a strong development coach: **+4 to +7
  overall** across a season.
- The same player getting real minutes but *not* on a Developmental
  slot, average coach: **+2 to +4**.
- A bench player, low minutes, any coach: **+0 to +1**, mostly noise.
- A player already at/above their potential: **~0**, small random jitter
  either way so it doesn't read as a hard wall.
- A player past the decline threshold (see open questions): **-1 to -3**,
  steeper the further past it, softened for Gym Rat.

## Where I'd stop, for now

- **No mid-season training UI.** Already covered above -- Phase 4's
  problem.
- **No facilities/investment layer** (practice facilities, staff size,
  etc.) -- also explicitly Phase 4.
- **No player-initiated training requests** ("I want more offensive
  reps") -- possible future hook for player goals (also Phase 4-listed),
  not this.
- **Retirement/aging out at the top of the range** is a related but
  separate system (roster churn, not development) -- worth its own doc
  later, not folded in here.

## Open questions for you

1. **Cadence** -- end-of-season only (my default above), or should there
   also be small in-season ticks (e.g. a light adjustment at the
   All-Star break/season midpoint)? End-of-season is simpler and matches
   the "resolve once, from accumulated state" pattern the rest of the
   season engine already uses; a mid-season tick would need its own
   trigger point and roughly doubles the surface area to test.
2. **Any GM-facing training decision at all**, even a small one, in this
   first pass -- or is "fully emergent from roster decisions" the right
   scope for now? I'd default to fully emergent (see above) but this is
   very much your call.
3. **Age curve specifics** -- what age does growth start tapering, and
   what age does real decline begin? A real WNBA-shaped guess: fastest
   growth 20-23, tapering through 26-27, plateau 27-29, decline
   starting ~30-32. Does that match the feel you want, given the game's
   20-34 generation range?
4. **Does `potential` ever move?** Right now it's rolled once at
   generation and (per this proposal) never changes. An alternative:
   scouting/coaching could occasionally *reveal* a player was
   under/over-rated at generation (a "hidden variance" idea), which
   would need its own scouting-accuracy concept that doesn't exist yet.
   I'd leave potential fixed for now and treat "scouting uncertainty" as
   a separate, later idea -- but flagging it since it's adjacent.
5. **Injury interaction** -- should missed games (from the injury
   rework noted in `0B_Planned.md`) reduce that season's growth (missed
   reps), or should development run fully independent of injury status?
   Leaning toward "missed games just mean fewer minutes counted in
   Channel 1," which falls out of the model above for free without a
   special case -- but wanted to name it explicitly rather than let it
   be an accident.
6. **Does the draft magnitude above feel right?** Too fast, too slow, or
   in the right neighborhood? This is the single easiest thing to tune
   once there's a real formula, so a rough gut check now saves a
   rebalancing pass later.
7. **Should a breakout or a decline get a surfaced moment** -- a
   notification, an end-of-season summary line, something in the
   eventual achievement/nickname ceremony (`0B_Planned.md`'s Phase 2
   award-triggers item) -- or should it stay quietly in the numbers and
   just show up next time the GM looks at the roster? Given the
   earned-identity precedent, I'd lean toward *some* surfaced moment for
   a genuine breakout (crossing into 4-star or 5-star territory) even if
   nothing else about training gets a screen yet.
8. **Special-cased veterans** -- should an older player signed
   specifically for locker-room/leadership value (a Leader-trait
   veteran, say) be exempted from the decline math, or is "everyone
   ages the same, that's the tradeoff of keeping a veteran around" the
   more honest version? I'd default to the latter -- no exemptions --
   but veteran-management strategy hinges on this answer.
