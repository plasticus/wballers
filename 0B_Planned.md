# Women's Basketball Manager — Planned Work

Everything still to build, organized by the phase it belongs to. Where a
design question has already been answered (from the old `Phase2&3-Q&A.md`
working pass), the answer is written in directly as the plan rather than
left as an open question — treat these as decided, not tentative, unless
marked otherwise. See `0A_Completed.md` for what's already built and
`0C_Vision_and_Ideas.md` for premise-level ideas that aren't phase-scoped
yet.

## Phase 2 — League, season, and franchise simulation

**Goal:** turn roster management into an ongoing fictional basketball world.

Grouped below by what depends on what: league/team structure has to exist
before rosters can be generated for it, which has to exist before a season
can be scheduled and simulated, which has to happen before there's
anything for the presentation layer or end-of-season systems to show.

### Season mechanics and simulation

- **Season calendar: 24 weeks**, running roughly May-October in fictional time. Regular-season games and Continental Cup rounds (below) interleave within this skeleton:

  | Week | Event |
  | --- | --- |
  | 1 (~May 1) | Pre-season: 2 games vs. random inter-conference opponents, don't count toward standings |
  | 2 (~May 8) | Regular season tip-off |
  | 4 (~May 22) | Continental Cup Round 1 |
  | 6 (~June 5) | Continental Cup Round 2 |
  | 8 (~June 19) | Continental Cup Round 3 (Quarterfinals) |
  | 10 (~July 3) | Continental Cup Round 4 (Semifinals) |
  | 12 (~July 17) | Continental Cup Final (mid-season) |
  | 18 (~August 28) | End of regular season |
  | 19 (~September 4) | All-Star break (1 week) |
  | 20 (~September 11) | Postseason Round 1 (best-of-3) |
  | 22 (~September 25) | Postseason Round 2 / Semifinals (best-of-5) |
  | 24 (~October 9) | Postseason Finals (best-of-7) concludes |

- **Schedule, the full match engine (contest resolver → possession loop → fouls → game loop → overtime), a season simulator, the full Continental Cup bracket (Rounds 1-5), and the postseason bracket (best-of-3/5/7): all built** — see `0A_Completed.md`'s match-engine, season-simulator, Continental Cup, and postseason entries (`simulateMatch`, `simulateSeason`, `computeStandings`, `generateContinentalCupRound2`-`5`, `postseasonSeeds`, `generatePostseasonFirstRound`/`Semifinals`/`Finals`). A real standings table can now be produced from a full 20-team, 310-game season in ~200ms, a full Continental Cup bracket resolves end to end to a single champion, and so does the postseason bracket (real 2022+ WNBA format: top 8 seeds, standard bracket, best-of-3 → best-of-5 → best-of-7). Still open in this area: wiring any of this into `Franchise`/persistence/a screen — these are all standalone functions nothing calls yet, same "not prematurely plumbed" posture the schedule generator had before them; and a real home-court-advantage mechanic in the match engine itself (postseason home/away assignment currently has no mechanical effect on outcomes).
- **Draft: built** — see `0A_Completed.md`'s draft entry (`generateDraftClass`, `generateDraftOrder`, `simulateDraft`, `College`/`kColleges`). Lottery/order specifics are decided now (weighted lottery for the 12 non-playoff teams, reverse-standings order for the 8 playoff teams, same order repeats for all 3 rounds) rather than left TBD, and college prestige affects only prospect exposure (which college a prospect happens to attend), never quality, as originally intended. Still open: wiring it into `Franchise`/persistence/a screen, and any real GM AI for draft-day decisions beyond "best player available" (no team-needs modeling yet).

### Presentation

- **Season-progression model: decided (2026-08-05) — Option B.** The GM plays through their own team's games one at a time; the other 19 teams' games simulate automatically in the background. `simulateSeason`/`simulateMatch` (the whole backend built this session) stay an admin/testing tool for now, not the primary game loop — later, once the GM has staff, they'll be able to delegate individual games to a Coach, but that's a future phase, not this one. This decision unblocks the actual build order for the season loop, once it's picked up: a per-game flow for the GM's own games, plus a background-sim trigger for everyone else's, both needing real Franchise/save wiring that doesn't exist yet.
- **Player detail screen, pulled forward as an early Phase 2 prerequisite** (not left for later). Spec (2026-08-05): current skills/ratings, current-season stats, a prior-seasons history (stats *and* which team each season was with), and an awards/notables section. Also the natural home for the trait display noted under Phase 1.5 above.
- **League screens.** Spec (2026-08-05):
  - **Standings page** — built and ready to display (`computeStandings`, real tiebreakers).
  - **Schedule page** — built and ready to display (`generateSeasonSchedule`/`SeasonSchedule`).
  - **Results page** — every game played, scrollable back through the whole season. Per game: final score, both teams' FG%, and a 3-player-per-team spotlight (one delegated the game's MVP) with their quick stats (points/assists/rebounds/steals/blocks) — a real box score, like a sports website's game recap. `computeBoxScore` (`match/domain/player_box_score.dart`) now produces the per-player stat lines this needs; picking the 3 spotlighted players and an MVP per game is still undesigned.
  - Still not started: team pages, player leaders, news, historical records.
  - It's a static team directory today with no season data behind any of this.
- **Achievement/nickname ceremony / end-of-season screen.** Fires after the playoffs, not at end of regular season. Per the GM's own call (2026-08-05): build this as a **placeholder for now** — the real batch-presentation ceremony (award winners, nicknames earned, neon hair unlocked) is a big enough chunk of work to defer to whatever phase end-of-season systems properly get tackled, rather than trying to land it alongside the other Phase 2 presentation work above. Open structural question from before still stands: this might deserve its own phase (a "Phase 2.5" or "3.5") rather than a bullet inside Phase 2.

### Ongoing systems and deferred items

- **Player development/regression.** Age curve vs. `potential` ceiling vs. coach Development stat vs. High/Low Potential traits — no formula decided yet; deferred to revisit sometime after the rest of Phase 2 ships. Morale and news/event generation are the same shape — systems that layer on top of the season loop once it exists, not designed yet.
- **Injury model.** Keep it slight — minor injuries reduce a player's ratings by 10-25% for 2-4 games. Benching an injured player heals them faster than playing through it. A GM can sign a free agent to a 7-day contract to cover the gap.
- **Fatigue does not need to persist between games in Phase 2** — it's tracked per-game only (see the stamina appendix under Phase 3 below). A season-calendar-level rest/back-to-back model was considered and explicitly not chosen; nothing to build here beyond making sure Phase 3's per-game fatigue actually resets between games.
- **Trade system.** Not needed for a while (no trading planned for the first few phases of Phase 2 work). When it arrives: the AI should own most of the valuation logic itself; the GM's role is just to put a player on the trade block, and the AI generates offers from there.
- **Balancing tools.** Simulation batches, diagnostics, distribution checks, seeded regression scenarios.

### Exit criteria (Phase 2)

- A player can complete a season, develop a roster, draft and trade players, and begin the next season with persistent history.
- Re-running the same state with the same simulator version and seed produces the same results.

## Phase 3 — Match engine and tactical play-by-play

**Being built alongside Phase 2, not deferred until it exits** (decided 2026-08-05, see the "simulator" bullet under Phase 2's season mechanics) — the possession engine below *is* what Phase 2's simulator needs to produce real game results, so it's being built now rather than gated behind a Phase 2/3 boundary. Left as its own phase heading here since the goal and exit criteria are still a coherent unit of work, not because it's on hold.

**Goal:** make individual games legible and strategically meaningful without a full animation project.

- **Possession-based engine.** Core possession loop, fouls/free throws, and the full quarters-and-scoreboard game loop are all **built** — see `0A_Completed.md`'s three match-engine entries (`simulatePossession`, `resolveTipOff`, `simulateMatch`). Alternating possession falls out of the engine automatically. A first round of pacing/scoring/bench-rotation calibration is done too (same entry) — combined score down to ~201 average from ~420, bench players now actually see the floor — though it's still not exact and the full "batch-simulate thousands of games against real WNBA numbers" pass is still open. Overtime is built too (5-minute periods until the tie breaks — a season simulator needs a winner out of every game). Still open here: a live/paced play-by-play presentation of the event log (the engine currently just returns the whole game's events at once, not a feed you watch unfold).
- **Live scrolling play-by-play feed** (not instant computation presented as a log afterward). Stops automatically for coaching adjustments at the end of each quarter, and additionally at the 2:00 mark of any quarter if the score is within 10 points.
- **Fully automatic substitutions: built, using a default ranking, not a GM-set one yet.** `substitution_policy.dart`'s `targetMinutesFor` assigns the reference table below by rating rank (best players play the most) since there's no UI yet for the GM to set their own ranking — same "sensible default, later overridable" shape used elsewhere. `pickOnCourt` re-picks the 5 furthest-behind-schedule players every 2 simulated minutes (foul-outs substitute immediately on top of that). Reference table, summing to a full 200-minute game across a 12-player active roster:

  | Rank | Target minutes |
  | --- | --- |
  | 1-3 | 30 each |
  | 4-5 | 26 each |
  | 6-7 | 14 each |
  | 8-9 | 8 each |
  | 10 | 6 |
  | 11-12 | 4 each |
  | 13-14 (developmental) | 0 |

  Still open: a real GM-set target-minutes ranking (and the UI for it) — the periodic in-quarter recheck that gets low-minute bench players actual playing time is built (see `0A_Completed.md`).

- **Quarter-break/timeout choices.** A pool of roughly a dozen possible options (improve offense, improve defense, fire the team up, reduce stamina drain, full-court press, park the bus, mount a comeback push, pace yourselves, etc.); the GM sees only ~3 choices at a time, situationally selected from the pool depending on game state. Full option catalog and selection logic still to be worked out.
- **Timeout system specifics** (count per game, what a "special play" modifies) — parked, deliberately not designed yet. Get the quarter-break check-ins working first.
- **"Difficulty" setting** — likely a small adjustment to the action-success formulas to make games easier/harder to win. Belongs here, not Phase 2, since it hooks into formulas that don't exist until the match engine does.
- **Stamina & fatigue formulas**, captured as a starting design intent, not yet vetted or built:
  - Energy pool: starts at 100 max. Drain per minute played: `2 * (1.5 - (Stamina / 100))` — a 99-stamina star drains ~1.02/min, a 70-stamina average player ~1.60/min, a 50-stamina player 2.00/min.
  - Fatigue penalty: no penalty above 80 energy; 0.5% stat penalty per point lost below 80; floor of 50% minimum effectiveness.
  - Recovery: no passive recovery on the bench. Quarter breaks give no automatic recovery — requires the coach to pick a specific coaching option (ties into the quarter-break system above). Halftime gives a flat +10 energy bump to the whole roster.
- **Pre-game setup, post-game box score, advanced stats, and a tactical recap** wrapped around the live play-by-play feed above.
- **Player roles and tactical fit** that materially affect outcomes without reducing games to a single overall-rating comparison.
- **Simulation and balance test suite** covering edge cases, strategic viability, statistical realism.

### Exit criteria (Phase 3)

- A player can understand why a game was won or lost and make a meaningful adjustment in a rematch.
- Tactics, ratings, fatigue, and randomness each have tested, observable effects.

## Phase 4 — Court presentation and deeper franchise management

**Goal:** add visual clarity and long-term depth once the text-based game loop is proven.

- Simple court/shot-chart presentation showing shot locations and key play context — no full player animation required.
- Scouting, richer draft classes, recruiting/international pipelines, hidden information.
- Expanded trades, contracts, salary cap/budget, free agency, waivers, staff/coaches as appropriate.
- An Assistant GM: a staff role that proactively surfaces roster suggestions ("player X would fill our open roster spot"). Not designed yet.
- Training plans, facilities, chemistry, player goals, story events, rivalries, branding, uniforms, arenas.
- Historical records, Hall of Fame, achievements, challenge scenarios.
- **Trophy Room screen** (noted 2026-08-05, not designed yet): a GM-facing franchise page showing every championship and cup won by the club, plus individual player awards (MVP, Defensive MVP, whatever other award types get built) earned by any player *while they were on the roster* — not a career-wide stat dump, scoped to what happened under this franchise. Depends on awards/achievements existing as trackable data first (see the achievement/nickname ceremony item under Phase 2 above, and this section's Hall of Fame item).
- A settings screen: light/dark theme override, selectable court color themes, adjustable text size (the text-scale provider this depends on already exists from Phase 0).
- **Fun side stats** (noted 2026-08-06, not designed yet): flavor numbers with no mechanical weight, purely for color — jersey sales being the prompting example, plus whatever else fits the same "amusing, not load-bearing" spirit (attendance, merch, fan mail, social buzz, that kind of thing). Deliberately parked until after the core gameplay loop (Phase 3) is proven — this is seasoning, not substance.

## Phase 5 — Launch and iteration

**Goal:** release a reliable offline Android game, learn from solo players, prepare web support.

- Real AdMob SDK behind an `AdService` boundary — test ad units in development, production units at release — on the dashboard and gameplay screens' already-reserved placements.
- Closed alpha and staged Android beta with structured feedback.
- Privacy-conscious, optional analytics only if they preserve the offline product promise.
- Measure onboarding completion, first lineup change, first game/season completion, crashes, simulation abandonment.
- Accessibility audit: scalable text, screen-reader labels, color-safe indicators, motion reduction, offline behavior.
- Performance and battery profiling across supported Android devices.
- Privacy policy, terms, support contact, Play Store identifiers. No account-deletion flow needed — the game has no accounts.
- Play Store listing, screenshots/video, support documentation, release checklist, post-launch improvement cadence.
- Assess and build the web release once the Android experience is stable.
