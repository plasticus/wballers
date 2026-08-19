# Coach lifecycle — age, growth, hiring, retirement (scoping only, 2026-08-19)

Gathered from a direct GM ask, same session as the AI off-season trades and
Trade Deadline lock. **Scoped, not built** — the ask itself was explicit
that this could be "today, or... just scope it a bit right now." Everything
below is what's locked from the GM's own words, a proposed generation
algorithm to satisfy it, and a short list of what's still a real open
question before this becomes a build.

## What's locked

1. **Hiring.** The GM can hire a new head coach every off-season, if they
   want to — entirely voluntary, no forced turnover the way a poor-record
   AI team gets fired (`coach_free_agency_advancer.dart` stays AI-only for
   *that* trigger). A new Dashboard button, off-season only (something like
   "Available Head Coaches"), opens a list of ~10 candidates, sortable by
   OVR or any individual stat — same shape `PlayerSortFilterBar`/
   `PlayerSortKey` already give Free Agents.
2. **Age.** `Coach` has no age field today at all. Coaches enter the league
   around 45, retire at 65 (65 is their *last* season — same "one final
   season, then gone" shape `kMandatoryRetirementAge` already gives
   players, just a different number and no persuasion-to-stay mechanic
   mentioned for coaches).
3. **Growth.** Flat **+1 per stat, every off-season** (all 5 `CoachStats`
   fields, uniformly) — no archetype-differentiated growth, no jitter, no
   roll. At entry (age 45): 250 total skill points (the 5 stats summed,
   `CoachStats`' own `overall` getter is their *average*, so this is
   `overall * 5` in that sense). At 65 (their final season): 350 total.
   The math is self-consistent on purpose: 65 − 45 = 20 seasons ×
   5 stats × 1 point = 100 points of growth, and 250 + 100 = 350 exactly
   — the given endpoints and the given growth rate aren't 2 independent
   numbers, they're the same fact stated twice.
4. **Per-stat bounds.** Every individual stat: minimum 30, maximum 79 (the
   79 ceiling already matches today's *real* generation ceiling by
   coincidence/design — `coach_generator.dart`'s qualityCenter 50 +
   archetype bias 14 + jitter 15 already tops out at 79 today; this locks
   it as a real floor/ceiling instead of an emergent one, and adds a real
   30 floor where today's is a looser ~29).
5. **Creation order.** Age first, then skill total from age (linear, see
   point 3), then that total gets distributed across the 5 stats — every
   stat starts at the 30 floor, the remaining `total − 150` gets
   distributed "randomly beyond that" (see the proposed algorithm below
   for how to keep every stat inside the 30-79 band while hitting the
   exact total).
6. **Every team's starting head coach** (GM's own and all 19 AI teams,
   at league/franchise creation) is age **50 ± 1** (49/50/51) — worked
   example straight from the GM: "if they're 49 to 51, they'll have
   skills of 270 to 280," which checks out against point 3's formula
   (250 + 5×4 = 270, 250 + 5×6 = 280) and is what confirms "50 ± 1" means
   *age*, not OVR.
7. **A re-roll button** on the onboarding coach-picker (today: 3 fixed
   candidates, no way to reroll) — a GM fishing for a specific specialty
   ("looking for like a high development coach or something") can hit
   it to draw a fresh batch, still inside the same 49-51 age band.
8. **Archetypes stay** — "I still like giving them a label, I don't want
   that to go away." The existing 8 `CoachArchetype` values and their
   flavor stay; only the underlying stat-generation math needs to change
   to fit the new age-driven-total system (see below).

## A proposed generation algorithm (not locked, just a starting shape)

Today's `_generateStat` rolls each of the 5 stats independently (a
`qualityCenter` + archetype bias + jitter, each clamped) — the *total*
was never a fixed target, just whatever 5 independent rolls happened to
sum to. The new rule fixes the total *first* (from age), so generation has
to become "distribute a known total across 5 stats, each within [30, 79],
biased toward the archetype's strengths" — a real algorithm change, not a
tuning tweak:

1. Roll (or accept) an age, get `total` from the linear formula.
2. Start every stat at the 30 floor (`total_so_far = 150`).
3. While `total_so_far < total`: pick one stat to bump by 1, weighted by
   the archetype's existing bias table (`_archetypeBias` — an Offensive
   Innovator's `offense`/`defense` weights already lean +14/-6, which
   could translate directly into "how often this stat gets picked for the
   next point" instead of "how much this stat gets nudged"), skipping any
   stat already at the 79 ceiling. Deterministic for a given `Random`
   stream, same as every other generator in this codebase.
4. This guarantees the exact total and the exact per-stat bounds by
   construction — no clamp-and-hope needed the way jitter-based generation
   used to.

Re-checked against the bounds: the real range is 250-350 total. Floor
(5×30=150) and ceiling (5×79=395) both comfortably contain it, so no
input ever forces an impossible distribution.

## What's still genuinely open (not locked, worth deciding before a build)

1. **Mandatory retirement at 66, for whom, and what happens next?** Players
   get a persuasion mechanic (Motivation skill check) before a mandatory
   retirement actually sticks; nothing like that was mentioned for
   coaches. Does the GM's own coach retiring at 66 just remove them
   outright (forcing a trip to the new hiring screen before advancing,
   same "gate the advance button" pattern the roster-short-a-player check
   already uses), or auto-replace with a fresh coach the way a fired AI
   team does? And do AI coaches *also* retire at 66, as a second,
   independent trigger alongside their existing performance-based firing
   (`coach_free_agency_advancer.dart`'s bottom-5-record check)?
2. **Where do the ~10 "Available Head Coaches" candidates come from?**
   Proposed default (not locked): generate them fresh every time the
   screen opens, deterministically seeded off the season — same
   "recompute, don't persist" posture the Draft/Free Agents preview tabs
   and the onboarding coach-picker already use — rather than a new,
   persisted, shared "free agent coach pool" concept. Worth confirming
   before building, since a shared pool is a meaningfully bigger feature.
3. **What happens to the GM's old coach when they hire a new one?**
   Proposed default: discarded outright, same as a fired AI coach today
   — no persisted "former coaches" list, since nothing reads one. Only
   matters if the Assistant Coach idea below ever gets built, since that
   would give a coach a real reason to stick around after being replaced.

## MAYBE pile — Assistant Coach, explicitly not scoped for real yet

A second coaching slot, deliberately **not** modifying any `CoachStats`
directly — its only job is to grow while sitting on the roster, so a GM
can develop a future head coach ahead of time: grooming a replacement for
an aging (e.g. 64-year-old) head coach, or "banking" a coach with great
stats for a season or two before promoting them. Two possible mechanics
floated, neither committed to:

- Just sit and grow (the same +1/stat/season everyone gets), with no
  effect on the current head coach at all — purely a "queue up your next
  hire" slot.
- (Flagged by the GM as possibly not worth the complexity) The assistant's
  *highest* single stat contributes 10% of its value as a bonus to the
  head coach's matching stat, for as long as both are employed together.

Both stay parked until there's real appetite to scope this properly — the
GM's own words: "keep it as a maybe."
