# Phase 2 & 3 — Open Questions and Answers

A working Q&A pass on loose threads from Phase 1/1.5 plus open Phase 2 and
Phase 3 design questions from `FLUTTER_APP_PLAN.md`. Answered 2026-08-04.
Not yet folded into `question.md` as numbered decisions or into
`FLUTTER_APP_PLAN.md`'s phase text — this is the working scratch pad for
that; treat answers here as directional until they land there.

## Loose threads from Phase 1 / 1.5

### 1. Player detail screen / trait display

**Q:** Traits have no dedicated UI yet (only shown via `traits.md` and the
generator). Pull the player detail screen forward as a Phase 2
prerequisite, or let it wait?

**A:** Pull it forward. Do it early in Phase 2, sooner rather than later —
season stats, awards, and box scores all need somewhere to live, and that's
the player detail screen.

### 2. GM's own portrait/persona

**Q:** Decision 24 flagged that the GM presumably wants a customizable
identity distinct from the coach's `isCoach` portrait. Decide now, or stay
parked?

**A:** Decided: the GM doesn't need a portrait at all. Coaches do. Drop
this thread — it's resolved, not deferred.

### 3. Team identity beyond onboarding (prestige, logos, custom branding)

**Q:** Prestige and a full custom-identity editor are still open;
onboarding only covers name/city/a starter color palette.

**A:** No logos for now — none of the 20 teams have them yet either. Also
flagging: onboarding doesn't currently appear to actually offer a color
palette to choose from at expansion time — worth double-checking against
what's built versus what the plan describes.

### 4. Bench order, captain, depth chart beyond the starting five

**Q:** `StartingLineup` only covers the five starters today.

**A:** Not really an open question — this needs to exist. All 12 active
roster players (+2 developmental) need a full ordering, effectively a
minutes-distribution ranking, not just a 5-player starting lineup. See the
"Target Minutes" idea in the appendix below — this is likely how that
ordering gets expressed.

### 5. Rating-threshold-based archetype selection

**Q:** Archetypes are currently assigned uniformly at random per position.
Should archetype selection correlate to actual ratings (a "Sniper" should
have high perimeter offense)? Phase 2, alongside league-wide roster
generation, or later?

**A:** Archetype should drive stats, not the other way around — and once
assigned, a player's archetype never changes. Generation order becomes:
roll/assign the archetype first, then roll ratings biased to fit that
archetype. This produces a controlled, sensible mix of players instead of
random stats that may or may not match the label. Needs to land wherever
player generation is touched next (Phase 2's league-wide roster
generation is the natural point, since that's the next time generation
logic gets opened up).

## Phase 2 — League, season, franchise sim

### 6. 19 AI team roster quality/generation

**Q:** Same `generatePlayer`/`generateStartingRoster` machinery with a
different quality center, or a distinct generator? The expansion-roster
generator is deliberately incapable of reaching 4-star; the AI-league
generator needs the opposite guarantee.

**A:** Outcome matters more than mechanism here. Target: **every team
carries exactly one 5-star player, leaning veteran, plus three 4-star
players, mixed young/mid/old.** (Stays comfortably inside the `star_system.md`
caps of ≤2 five-star and ≤6 four-star-or-better combined.) Implementation
approach (shared generator with a different quality center vs. a distinct
function) is left to whoever builds it.

### 7. Team replacement mechanics

**Q:** Does the replaced AI team's slot/colors get taken over (still 20
teams total), or does it just vanish, running the league at 19 AI + 1 GM
team?

**A:** The new team slots directly into the replaced team's old spot — the
league stays at 20. The GM chooses the new team's colors; offer a curated
set of options (not a totally free picker) so it's harder to accidentally
collide with another team's existing colors.

### 8. Schedule format

**Q:** Games per season, round-robin weighting between conference/
cross-conference?

**A:** **28 games**: each team plays every other team in its own
conference twice (9 opponents × 2 = 18) and every team in the other
conference once (10 × 1 = 10). Plus playoffs, a preseason, and a future
"cup" bonus mini-tournament (not designed yet, just flagged as an idea).
28 is a starting point — if a season plays too fast in practice, revisit.

### 9. Playoff structure

**Q:** How many teams, series format — and does Phase 2 simulate playoff
games with a placeholder formula since Phase 3's match engine doesn't
exist yet, or wait?

**A:** Mimic the real WNBA's playoff structure. Yes — simulate playoffs in
Phase 2, ahead of Phase 3's real match engine existing.

### 10. "Difficulty" setting

**Q:** Named in the League configuration bullet with no definition — what
does it modulate?

**A:** Likely a small adjustment to the action-success formulas to make
games easier/harder to win. Not a Phase 2 concern — punt to Phase 3, since
it hooks into the match engine's formulas, which don't exist until then.

### 11. Draft mechanics

**Q:** Lottery vs. straight order by record, rounds/picks, how college
prestige (`colleges.md`) factors in?

**A:** Mimic the real WNBA's pick-order mechanism. College prestige has
**zero mechanical effect** on prospect quality — it's flavor text only.

### 12. Trade AI valuation formula

**Q:** What inputs, and how do they combine?

**A:** Not needed for a while — no trading for a few phases yet. When it
arrives: the AI should own most of the valuation logic itself. The GM's
role is to put a player on the trade block; the AI generates offers from
there.

### 13. Player development/regression curve

**Q:** Age curve vs. `potential` ceiling vs. coach `Development` stat vs.
High/Low Potential traits — no formula yet.

**A:** Deferred — revisit sometime after Phase 2 ships.

### 14. Achievement/nickname ceremony timing

**Q:** Fires at end of regular season, end of playoffs, or both? Batch
review vs. one confirmation per nickname?

**A:** **After the playoffs.** There will be a dedicated end-of-season
screen showing all award winners and what it means for them (nickname
earned, neon hair color unlocked, etc.) — a batch presentation, not a
one-off confirmation per player.

**Flagged structural note:** all of the end-of-season ceremony/awards
machinery is looking big enough to be its own phase rather than a bullet
inside Phase 2 — possibly a **Phase 2.5 or 3.5**. Not decided, just
flagged for whoever next edits `FLUTTER_APP_PLAN.md`.

### 15. Injury model

**Q:** Severity/duration, interaction with Reserve/Inactive status?

**A:** Keep injuries slight. Minor injuries reduce a player's ratings by
**10-25%** for **2-4 games**. Benching an injured player heals them
faster than playing through it. A GM can sign a free agent to a
**7-day contract** to cover the gap.

### 16. Fatigue persistence

**Q:** Tracked per-game (Phase 3), or accumulated across the season
calendar with rest/back-to-backs (Phase 2)?

**A:** **Per-game only.** Fatigue does not persist between games — see
the "Stamina & Fatigue Mechanics" idea in the appendix for the shape this
should take.

## Phase 3 — Match engine

### 17. Play-by-play pacing

**Q:** Live scrolling possession-by-possession feed, or instant
computation presented as a readable log afterward?

**A:** **Live scrolling feed.** Stops automatically for coaching
adjustments at the end of each quarter, and additionally at the
**2:00 mark** of any quarter if the score is within **10 points**.

### 18. Auto-substitution triggers

**Q:** Fixed rotation minutes, fatigue threshold, foul trouble, some
blend — does coach Offense/Defense/Motivation influence rotation calls?

**A:** Rotation is **fully automatic** — the GM should not need to get
involved at that level. (Target-minutes ordering, per the appendix idea,
is the input; the engine handles the actual in-game substitution timing
itself.)

### 19. Quarter-break/timeout choice granularity

**Q:** Small fixed enum per category, or a wider matrix?

**A:** A pool of roughly a dozen possible options — e.g. improve offense,
improve defense, fire them up (raise morale), reduce stamina drain, full
court press this quarter, park the bus, mount a comeback push, pace
yourselves — and the GM sees only **~3 choices at a time**, situationally
selected from that pool depending on game state. Full option catalog and
selection logic to be worked out when this gets built.

### 20. Timeout system specifics

**Q:** How many per game, what does a "special play" modify?

**A:** Parked — "maybe in the future." Get the quarter-break check-ins
working first before designing a separate timeout layer on top.

## Appendix: supplied mechanic ideas (Phase 3 reference)

Not yet vetted or built — captured here as the starting design intent for
whoever implements stamina and rotation in Phase 3.

### Stamina & Fatigue Mechanics

**1. Energy pool & drain**
- Starting energy: 100 max.
- Drain formula (per minute played): `Drain = 2 * (1.5 - (Stamina / 100))`
  - Stamina 99 (star): ~1.02 energy/min
  - Stamina 70 (average): ~1.60 energy/min
  - Stamina 50 (low): 2.00 energy/min

**2. Fatigue penalty**
- Threshold: no penalties above 80 energy.
- Rate: 0.5% stat penalty per 1 point lost below 80.
- Floor: minimum effectiveness locked at 50%.

**3. Recovery & management**
- Bench: no passive recovery.
- Quarter breaks: no automatic recovery — requires the coach to select a
  specific coaching option (ties into question 19 above).
- Halftime: standard flat +10 energy bump to the whole roster.

### Target Minutes

A 12-player active roster (plus 2 developmental) ranked by intended
minutes share, summing to a full 200-minute game (5 players × 40 minutes):

| Player | Target minutes |
| --- | --- |
| 1 | 30 |
| 2 | 30 |
| 3 | 30 |
| 4 | 26 |
| 5 | 26 |
| 6 | 14 |
| 7 | 14 |
| 8 | 8 |
| 9 | 8 |
| 10 | 6 |
| 11 | 4 |
| 12 | 4 |
| 13 | 0 |
| 14 | 0 |

**Total: 200 minutes.** This is the likely shape of the "full lineup
ordering" called for in question 4 above — not just five starters, but a
minutes-ranked list covering the whole roster, which the automatic
substitution engine (question 18) then executes against during a game.
