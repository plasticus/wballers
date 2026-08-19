# Coaching stats: Motivation & Management — status and open scoping

Everything scattered across `Aug10Questions.md`, `TODO.md`, `0A_Completed.md`,
`0D_Season_2_Roadmap.md`, and `old-mds/FLUTTER_APP_PLAN.md`/`question.md`
about the coach stat block, gathered in one place (2026-08-19, a direct GM
ask: "I can't look at them at the same time"). Covers all 5 `CoachStats`
fields for context, but the actual decision this file exists for is just
Motivation and Management — the 2 that still don't do enough.

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
| **Motivation** | Morale/chemistry + close-game resilience | ⚠️ Partially — see below. |
| **Management** | Trade/draft shrewdness | ❌ Nothing — see below. |

Confirmed by grepping `lib/` directly (2026-08-19): no code path reads
`CoachStats.management` for any decision at all. It's generated
(`coach_generator.dart`), shown on the coach-selection screen, and
persisted (`coach_json.dart`) — and that's the entire list.

## Motivation — the one real hook it has

`retirement_advancer.dart`'s `attemptRetirementPersuasion`: when a player
on the GM's own roster is a pending retirement decision, the coach's
Motivation drives a skill check (`resolvePendingRetirement`,
`current_franchise_provider.dart`) — clamped between `kMinPersuasionChance`/
`kMaxPersuasionChance` (10%/90%, first-pass numbers) so a maxed coach can
never *guarantee* a stay and a bottomed-out one can never make it
*impossible*. Shipped 2026-08-11 (`0A_Completed.md`), reusing "the closest
of the 5 `CoachStats` to 'keep a veteran playing'" per that stat's own doc
comment — an acknowledged imperfect thematic fit, not a real morale system.

What's still missing from the original pitch: nothing about team-wide
morale/chemistry exists, and nothing ties Motivation to close-game
resilience (clutch performance, late-game execution).

## Management — a genuinely clean slate

Zero design decisions made beyond the one-line original pitch
("trade/draft shrewdness"). No trade system exists yet at all (the Trade
Block is preview-only per `TODO.md` item 1), and AI draft picks
(`resolveAiPicksUntilOwnTurn`) already use a fixed "best player available"
heuristic with no coach-quality input.

## Stale open question, superseded by the above (moved here from
`Aug10Questions.md` #16, 2026-08-19 — written 2026-08-10, before Offense/
Defense/Motivation had any consumer at all)

> Confirmed: only Development is wired in (feeds training growth).
> Offense/Defense/Motivation/Management are generated and shown but do
> nothing yet.
>
> - Worth scoping as a real feature soon, or stays on the shelf for now?
>   If soon: any starting thoughts on what each stat should affect (e.g.,
>   Motivation → training bonus, Offense/Defense → in-game play-calling
>   bias, Management → rest/rotation decisions)?

(Offense/Defense/Motivation have since gained real consumers, described
above — this snapshot is kept only as dated context for how the original
question was framed, not as still-current status.)

## What actually needs deciding

1. **Management** — pick a lane. The original pitch was "trade/draft
   shrewdness," but there's no trade system to be shrewd about yet, and
   AI draft logic is a fixed heuristic today. Candidates: fold into AI
   draft-pick quality (a strong-Management AI team's picks lean more
   toward need over pure best-player-available?), factor into the AI
   trade-offer system once one exists (`star_system.md`'s still-unbuilt
   enforcement flow, see `roster-legality-notes.md`), or something else
   entirely (the old #16 question's own suggestion was rest/rotation
   decisions, which doesn't match the original written pitch at all).
2. **Motivation's morale/chemistry half** — still completely unscoped.
   Team-wide morale affecting what, exactly? And "close-game resilience"
   — a clutch-performance modifier layered onto `possession_engine.dart`
   the same way fatigue/coaching-option bonuses already stack?
