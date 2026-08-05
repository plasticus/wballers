# Women's Basketball Manager — Planned Work

Everything still to build, organized by the phase it belongs to. Where a
design question has already been answered (from the old `Phase2&3-Q&A.md`
working pass), the answer is written in directly as the plan rather than
left as an open question — treat these as decided, not tentative, unless
marked otherwise. See `0A_Completed.md` for what's already built and
`0C_Vision_and_Ideas.md` for premise-level ideas that aren't phase-scoped
yet.

## Phase 1.5 remainder

- A dedicated trait display (player detail screen, or an expandable section on the roster row) — traits are generated and persisted but have no UI surface yet.
- The special/neon hair-color picker is built and gated correctly; it just has nothing to react to yet. See Phase 2's achievement/nickname ceremony below — that's what will actually open the gate.

## Phase 2 — League, season, and franchise simulation

**Goal:** turn roster management into an ongoing fictional basketball world.

Grouped below by what depends on what: league/team structure has to exist
before rosters can be generated for it, which has to exist before a season
can be scheduled and simulated, which has to happen before there's
anything for the presentation layer or end-of-season systems to show.

### League and team structure

- **League configuration and runtime.** The 20-team-per-playthrough Atlantic/Pacific format needs to become a real runtime concept — the drawn league (`drawLeagueTeams`) is derived on demand from `kLeagueTeamPool` and a franchise's `simulationSeed` today, not persisted as live league state anywhere. Includes tiebreakers and season calendar (schedule and playoffs are their own items below).
- **Team replacement mechanics.** When a GM's new club replaces an existing team, it slots directly into that team's old spot — the league stays at 20 (drawn from the 40-team pool, see `0A_Completed.md`). The GM picks the new team's colors from a curated set of options, not a fully free color picker, so it's harder to accidentally collide with another team's existing palette.
- **19 AI team rosters, generated for the first time** (this playthrough's drawn league teams have identity only today, no players). Target: every team carries exactly one 5-star player, leaning veteran, plus three 4-star players with a mixed young/mid/old spread — stays comfortably inside the star-system caps (≤2 five-star, ≤6 four-star-or-better combined). Concretely, aim for roughly 4 four-star-or-better players and at least 2 traited players per team, so a freshly generated roster already reads as a real team with texture. Whether this reuses `generatePlayer`/`generateStartingRoster` with a different quality center or a distinct generator function is an implementation detail, not a design constraint — outcome matters more than mechanism.
- **Archetype-drives-stats generation reorder.** Currently archetype is assigned uniformly at random per position, independent of rolled ratings. Change the order: assign/roll the archetype *first*, then bias ratings to actually fit that archetype (a "Sniper" should end up with high perimeter offense). Once assigned, a player's archetype never changes. This is a Phase 1.5-originated idea, but it belongs here — league-wide roster generation is the next time generation logic actually gets opened up, so it should land alongside the AI-roster work above, not before it.

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

- **Schedule: 28 regular-season games.** Each team plays every other team in its own conference twice (9 opponents × 2 = 18) and every team in the other conference once (10 × 1 = 10), plus the 2-game pre-season set above. 28 is a starting point — revisit if a season plays too fast or too slow in practice once it's real.
- **WBL Continental Cup.** A mid-season, all-20-team single-elimination bracket slotted into the weeks above — explicitly *not* a WNBA-style Commissioner's Cup group stage. Cup games do **not** count toward regular-season standings.
  - Teams: all 20, randomly seeded.
  - Round 1: 10 games, all 20 teams play; 10 winners advance.
  - Round 2: the 4 highest-margin-of-victory Round 1 winners get byes (tiebreaker: coin flip); the remaining 6 play 3 games; 3 winners advance. 7 teams remain (4 byes + 3 winners).
  - Round 3 (Quarterfinals): 3 of the 4 bye teams (random draw) join the 3 Round 2 winners — 6 teams play 3 games; 3 winners advance. The last bye team (highest remaining margin-of-victory; tiebreaker: coin flip) sits out again, carrying a second bye straight to the Semifinals.
  - Round 4 (Semifinals): 4 teams (3 Round 3 winners + the double-bye team) play 2 games; 2 winners advance.
  - Round 5 (Championship): 1 game for the title.
  - Total: 19 games (10 + 3 + 3 + 2 + 1) — checks out against 20 teams needing 19 games to reach a single champion.
- **A fast, deterministic simulator** for AI-vs-AI results and full-season progression — the engine the schedule above actually runs on.
- **Postseason.** Best-of-3 first round, best-of-5 semifinals, best-of-7 finals — see the season calendar above for timing. Simulate postseason games in Phase 2 using a placeholder formula, ahead of Phase 3's real match engine existing — don't wait for Phase 3 to let a season actually finish.
- **Draft.** Mirror the real WNBA's pick-order mechanism (lottery/order specifics TBD against that reference), sourced from the fictional college pipeline (`colleges.md`). College prestige has **zero mechanical effect** on prospect quality — it's flavor text only; potential, growth, and outcomes are still generated independently of it.

### Presentation

- **Player detail screen, pulled forward as an early Phase 2 prerequisite** (not left for later) — season stats, awards, and box scores all need somewhere to live, and that's this screen. Also the natural home for the trait display noted under Phase 1.5 above.
- **League screens.** Standings, schedule, results, team pages, player leaders, awards, news, historical records. The League screen should read as a real standings page once there's a season to report: win-loss record, and between seasons, last season's regular-season record plus the champion (with a trophy emoji). It's a static team directory today with no season data behind it.
- **Achievement/nickname ceremony.** Fires after the playoffs, not at end of regular season. A dedicated end-of-season screen shows all award winners and what it means for them (nickname earned, neon hair color unlocked, etc.) as a batch presentation, not a one-off confirmation per player. Open structural question: this ceremony machinery might be big enough to deserve its own phase (a "Phase 2.5" or "3.5") rather than living as a bullet inside Phase 2 — not decided, worth reconsidering once the rest of Phase 2 is further along.

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

**Goal:** make individual games legible and strategically meaningful without a full animation project.

- **Possession-based engine**: pace, shot selection, turnovers, fouls, rebounds, automatic substitutions, clock/game states, end-game logic. Action success uses the universal formula already established: Physical Stat + Skill/Defensive Stat.
- **Live scrolling play-by-play feed** (not instant computation presented as a log afterward). Stops automatically for coaching adjustments at the end of each quarter, and additionally at the 2:00 mark of any quarter if the score is within 10 points.
- **Fully automatic substitutions**, driven by a target-minutes ranking the GM sets (not fixed rotation minutes the GM babysits in real time). A reference starting point for that ranking, summing to a full 200-minute game across a 12-player active roster:

  | Rank | Target minutes |
  | --- | --- |
  | 1-3 | 30 each |
  | 4-5 | 26 each |
  | 6-7 | 14 each |
  | 8-9 | 8 each |
  | 10 | 6 |
  | 11-12 | 4 each |
  | 13-14 (developmental) | 0 |

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
- A settings screen: light/dark theme override, selectable court color themes, adjustable text size (the text-scale provider this depends on already exists from Phase 0).

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
