# Women's Basketball Manager — Planned Work

Everything still to build, organized by the phase it belongs to. Where a
design question has already been answered (from the old `Phase2&3-Q&A.md`
working pass), the answer is written in directly as the plan rather than
left as an open question — treat these as decided, not tentative, unless
marked otherwise. See `0A_Completed.md` for what's already built and
`0C_Vision_and_Ideas.md` for premise-level ideas that aren't phase-scoped
yet.

## UI conventions

- **Pacific left, Atlantic right** -- whenever a screen lays the two conferences out side by side (e.g. a future wide-layout standings board), Pacific goes on the left and Atlantic on the right, matching real US geography. Declared 2026-08-06; nothing in the app does a side-by-side layout yet (`LeagueScreen` stacks Atlantic above Pacific vertically today), so there's nothing to fix yet -- apply this the first time one gets built.

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

- **Game days: declared (2026-08-06), built (2026-08-06)** — Sundays and Thursdays, regular season and Continental Cup alike; Tuesdays added during the postseason for a 3-games/week pace. `GameDay` (`season/domain/game_day.dart`) is now a real field on every `ScheduledGame`, and `generateSeasonSchedule` assigns it for real (regular season games land on whichever of Sunday/Thursday neither team is already booked on that week; preseason's 2 passes get one day each; Continental Cup rounds are all fixed to Thursday; postseason series games rotate Sunday/Tuesday/Thursday by game index). One known, deliberately-unsolved gap: Continental Cup Round 1 (week 4) doesn't coordinate days with regular-season games already in that week, so a team can occasionally have a game "on" the same nominal day from each — this predates day-tracking (it was already an uncoordinated extra game that week) and is real follow-up work, not solved here.
- **Schedule, the full match engine (contest resolver → possession loop → fouls → game loop → overtime), a season simulator, the full Continental Cup bracket (Rounds 1-5), and the postseason bracket (best-of-3/5/7): all built** — see `0A_Completed.md`'s match-engine, season-simulator, Continental Cup, and postseason entries (`simulateMatch`, `simulateSeason`, `computeStandings`, `generateContinentalCupRound2`-`5`, `postseasonSeeds`, `generatePostseasonFirstRound`/`Semifinals`/`Finals`). A real standings table can now be produced from a full 20-team, 310-game season in ~200ms, a full Continental Cup bracket resolves end to end to a single champion, and so does the postseason bracket (real 2022+ WNBA format: top 8 seeds, standard bracket, best-of-3 → best-of-5 → best-of-7). The Continental Cup and postseason are now wired into `Franchise`/persistence/the Dashboard -- see the "Season-progression model" entry below. Still open: a real home-court-advantage mechanic in the match engine itself (postseason home/away assignment currently has no mechanical effect on outcomes).
- **Draft: built** — see `0A_Completed.md`'s draft entry (`generateDraftClass`, `generateDraftOrder`, `simulateDraft`, `College`/`kColleges`). Lottery/order specifics are decided now (weighted lottery for the 12 non-playoff teams, reverse-standings order for the 8 playoff teams, same order repeats for all 3 rounds) rather than left TBD, and college prestige affects only prospect exposure (which college a prospect happens to attend), never quality, as originally intended. Still open: wiring it into `Franchise`/persistence/a screen with a real draft-day flow, and any real GM AI for draft-day decisions beyond "best player available" (no team-needs modeling yet) -- also blocked on `Franchise` having no season-number/"start next season" concept for a draft to trigger from at all. **Preview built (2026-08-07)**: the Player Market screen's Draft tab (see `0A_Completed.md`'s Player Market entry) shows `generateDraftClass`'s real output, just not wired to anything -- a stopgap, not the real flow above.

### Presentation

- **Season-progression model: decided (2026-08-05) — Option B.** The GM plays through their own team's games one at a time; the other 19 teams' games simulate automatically in the background. `simulateSeason`/`simulateMatch` (the whole backend built this session) stay an admin/testing tool for now, not the primary game loop — later, once the GM has staff, they'll be able to delegate individual games to a Coach, but that's a future phase, not this one.
  **Franchise/save wiring: built (2026-08-06)** — see `0A_Completed.md`'s season-progress entry. `SeasonProgress` (schedule + played-game history + next game day) is now a required part of the save, generated once at franchise creation same as `League`, and `advanceToNextGameDay` is the team-agnostic "background-sim everyone scheduled that game day" building block. Advances by game day, not by week (see the "Game days" entry above) -- with only 2-3 games scheduled a week, "Advance Week" would blow past individual games the GM wants to play through one at a time, so `SeasonProgress.nextGameDayIndex` points into the schedule's distinct (week, day) game days instead of a bare week number, and every advance always plays at least one game (bye weeks never get an entry).
  **Dashboard UI trigger: built (2026-08-06)** — see `0A_Completed.md`'s "Advance to Next Game Day" entry. **Continental Cup Rounds 2-5 and the postseason bracket: folded in (2026-08-06)** — see `0A_Completed.md`'s "The season actually finishes now" entry; the season resolves all the way to a Continental Cup champion and a season champion, no manual intervention required. Still open: this is all same-instant sim-and-reveal, not a real play-through (no live/interactive viewer exists yet, and building one is a distinct, much larger feature); no standings/schedule/results screens beyond the Dashboard's own-record-plus-next-matchup summary and the League screen's standings table; no bracket-viewer screen for the postseason (just a champion banner once it's done); no home-court-advantage mechanic in the match engine itself yet (postseason home/away assignment currently has no mechanical effect on outcomes).
- **Player detail screen: built (2026-08-06)** — see `0A_Completed.md`'s entry (`PlayerDetailScreen`, reachable from a roster row, replacing the old tap-straight-to-portrait-editor behavior). Current ratings (all 12 fields, grouped Physical/Offense/Defense, plus Potential), traits, this-season stats (aggregated from `PlayedGame.boxScoreByPlayerId`), and an awards section all built. Still open: prior-seasons history -- `Franchise` has no multi-season concept at all yet (no season/year field, no "start next season" flow), so that section is an honest placeholder for now, not populated data.
- **League screens.** Spec (2026-08-05):
  - **Standings page** — built and ready to display (`computeStandings`, real tiebreakers).
  - **Schedule page: built (2026-08-06), full-league view added (2026-08-07)** — see `0A_Completed.md`'s Schedule screen entry (`ScheduleScreen`, reachable from a "Schedule" button on the League tab). A "My Team" / "Full League" toggle now lets the GM see every game leaguewide, grouped by week, not just their own club's calendar.
  - **Results page: built (2026-08-06)** — see `0A_Completed.md`'s Results screen entry (`ResultsScreen`/`PlayedGameDetailScreen`, reachable from a "Results" button on the League tab). Every league game played this season, newest first; tap one for a full per-player box score. Not the full original spec -- no FG% team summary line, no 3-player spotlight/MVP pick (still undesigned) -- just the box score itself. Real, meaningful save-size growth from this: persisting a full box score for every game (not just the GM's own) landed at ~2.7MB for a complete 319-game regular season in a diagnostic run, up from ~190KB when only scores were kept. Judged acceptable for local device storage, but worth knowing if save size becomes a real complaint later.
  - **Player leaders and team stats: built (2026-08-07)** — see `0A_Completed.md`'s Stats screen entry (`StatsScreen`, a new 5th `AppShell` tab). Leaguewide per-category leaders, an MVP race, a team stat table beyond plain win-loss, and one team's roster stats side by side.
  - **Cup and Playoffs bracket tabs: built (2026-08-07)** — see `0A_Completed.md`'s "League screen gains Cup and Playoffs tabs" entry. `LeagueScreen` is now 3 tabs (Regular Season/Cup/Playoffs) instead of a bare standings list; the Cup tab lists every round's matchups (including upcoming ones once generated), and the Playoffs tab shows the full postseason bracket, reconstructed from persisted game history, once the regular season wraps up.
  - Still not started: individual team pages (a dedicated page per team beyond the League tab's standings row and the Stats tab's roster view) and historical records. A News screen exists now (see the "News screen" entry below), just with only one real source feeding it so far.
- **Achievement/nickname ceremony / end-of-season screen: placeholder built (2026-08-06)** — see `0A_Completed.md`'s Season Recap entry (`SeasonRecapScreen`). Fires after the playoffs (reachable from the Dashboard's trophy banner once a champion exists), shows the champion, the GM's own final record, and how far they got in the postseason (or that they missed it) -- but deliberately not the real ceremony. Per the GM's own call (2026-08-05), the real batch-presentation ceremony (award winners, nicknames earned, neon hair unlocked) is still a big enough chunk of work to defer to whatever phase end-of-season systems properly get tackled -- this screen just says so explicitly ("What's Next") rather than the GM hitting a dead end after a bare trophy line. Open structural question from before still stands: this might deserve its own phase (a "Phase 2.5" or "3.5") rather than a bullet inside Phase 2.

### Ongoing systems and deferred items

- **Player development/training: built (2026-08-06)** — see `0A_Completed.md`'s weekly-training entry (`runTraining`, `TrainingScreen`, the Dashboard's "Training Report Ready" card, `TrainingReportScreen`). The full decided design landed: gap-to-potential/minutes/coach/trait-driven growth, the confirmed age curve for decline, weekly (not end-of-season) resolution gated on `lastFullyCompletedWeek`, a real Training screen (team-wide focus + 3 individually-assignable coaches, sticky settings), and a surfaced per-player report. Still open, and said so in that entry's code comments rather than left silent: the 19 AI teams don't train yet (only the GM's own roster does); `PlayerRatings.potential` itself never moves yet (trades/minutes-trend/earned-identity triggers all depend on systems that don't exist yet); breakout/decline doesn't route through the nickname/hair-color earned-identity system yet (that trigger doesn't exist either); an Assistant GM proactively recommending training changes is still explicitly future work; and the training-coach staff role itself has no hire/fire flow yet, same posture as the head `Coach`.
- **News screen: superseded by Mail (2026-08-07)** — see `0A_Completed.md`'s Mail-inbox entry. The 4th `AppShell` tab and its passive `Franchise.trainingReports` feed are now `MailScreen`, not `NewsScreen` (deleted outright, not deprecated in place) -- a real GM ask to fold News into a proper inbox, not just rename it.
- **Mailbox: built for real (2026-08-07)** — closes out the note below, which correctly predicted this shape back on 2026-08-07 morning. `mail/domain/mail_item.dart`'s `MailItem` (`AssistantGmMailItem` + `TrainingReportMailItem`) and `mail/application/mailbox.dart`'s `mailboxFor`/`unreadMailCount` are the real, generic inbox this note originally deferred -- read/unread state included (`Franchise.readMailIds`), a red badge on the Mail tab, and the Assistant GM roster-gap message as the first (and so far only) system message. Still exactly one system-message type -- a trade offer is the natural second one, whenever the trade system lands. See `0A_Completed.md` for the full build.
  Original note, kept for context: the GM's own idea, floated alongside a News-preview request but explicitly a bigger, separate thing: a real inbox for actionable incoming items (trade offers once the trade system exists, an Assistant GM's proactive recommendations once that role exists, and whatever else needs a GM decision rather than just a passive read) with unread/read state tracked per item. News is a passive archive of what already happened; a Mailbox would be where things arrive still needing a response.
- **Coach archetypes: built (2026-08-06)** — see `0A_Completed.md`'s coach-archetype entry. GM confirmed keeping all 5 `CoachStats` (not trimming to 3) with archetype biasing them, same shape as the player system. **Onboarding coach selection: built (2026-08-06)** — the GM now picks their head coach from 3 generated candidates at onboarding (`0A_Completed.md`'s onboarding-rework entry) rather than getting one auto-assigned. Still ahead: any real hire/fire flow after the franchise already exists -- the onboarding pick is still the only way a coach ever enters the game.
- **Injury model, reworked (2026-08-06)** — captured as a design intent, not yet vetted or built. Three severity levels, each a straight stat-percentage reduction for a fixed number of games:

  | Level | Reduction | Duration |
  | --- | --- | --- |
  | A | 10% | 2 games |
  | B | 25% | 4 games |
  | C | 50% | 6 games |

  Recovery is bench-driven, not just time-driven: sitting an injured player for a full game (0 minutes played) drops them one severity level, regardless of how many games remain at the current level. Playing them through it does not. A day with no game scheduled for that team (a Continental Cup bye week, the All-Star break, etc.) counts the same as benching them.

  Worked example: a player suffers a C-level injury in Game 0 (no in-game effect that game; shows up on the injury report afterward). The GM benches them for Game 1 → drops to B (25%, 4 games). Benches again for Game 2 → drops to A (10%, 2 games). GM decides to play them starting Game 3 — they play Games 3 and 4 at a 10% stat penalty, and are back to 100% for Game 5.

  Injury *chance* (not yet formulated) is halved during the postseason — the game shouldn't be actively working against a GM's title push the same way it does in the regular season.

  A GM can still sign a free agent to a 7-day contract to cover the gap — carried over from the original version of this item, not changed by the rework above.
- **Hot/cold streaks** (noted 2026-08-06) — captured as a design intent, explicitly the least settled item on this list ("not sure how to assign" per the GM). A streak shifts a player's game-time stats by 5% (hot: +5%, cold: -5%) and lasts 3 games. Proposed assignment mechanism, still tentative:
  - After each game day, a team has a 33% chance of a new streak starting.
  - Coin flip decides hot vs. cold.
  - Assigned to a random player on the active roster.
  - A player can't hold both at once; a team can only have one hot and one cold streak active at a time.
- **Name-pool collision review** (noted 2026-08-07) — a GM playtest rolled a real roster with three players sharing the surname Clarke, which made talking through lineup decisions genuinely harder ("which Clarke do you mean"). Not urgent, but worth a real pass at some point: either grow `kLastNames`/`kFirstNames` (`core/generation/name_pools.dart`) enough that same-roster collisions get rare by sheer pool size, or add a soft uniqueness pass to `generateStartingRoster`/`generateAiRoster` that re-rolls a name on collision within one team. Whichever approach, cross-team collisions across the full 20-team league are fine to leave alone -- it's only confusing within a single roster.
- **Interstitial-ad performance boost** (noted 2026-08-06, not designed yet) — the GM's own idea, captured as a note for a later phase, not something to build now. Watching an interstitial ad grants a temporary +5% overall boost to all players for the next 3 games. Needs a game-planning screen to live on, which doesn't exist yet (nothing in the app today sits between "advance to next game day" and the result) — depends on that screen existing first, and on the real AdMob integration from Phase 5 (`AdService`) to actually gate it on a watched ad rather than a free toggle.
- **Fatigue does not need to persist between games in Phase 2** — it's tracked per-game only (see the stamina appendix under Phase 3 below). A season-calendar-level rest/back-to-back model was considered and explicitly not chosen; nothing to build here beyond making sure Phase 3's per-game fatigue actually resets between games.
- **Trade system.** Not needed for a while (no trading planned for the first few phases of Phase 2 work). When it arrives: the AI should own most of the valuation logic itself; the GM's role is just to put a player on the trade block, and the AI generates offers from there. **Preview built (2026-08-07)**: the Player Market screen's Trade Block and Free Agents tabs (see `0A_Completed.md`'s Player Market entry) show flavor data with no valuation/signing logic behind them at all -- confirms the shape this system will eventually need a home in, not a substitute for it.
- **Free-agent pool: built (2026-08-07)** — see `0A_Completed.md`'s Day-0-free-agent-pool entry. `Franchise.freeAgents` is now real, persisted, unrostered-player state (12 to start, one deliberately decent), and `signFreeAgent` moves one onto the active roster for real. Still open: no ongoing pool refresh (a player cut or waived doesn't return to it, since there's no cut/waive flow yet either), and no contract/salary concept at all — a sign is permanent and free, not a 7-day stopgap.
- **Balancing tools.** Simulation batches, diagnostics, distribution checks, seeded regression scenarios.

### Exit criteria (Phase 2)

- A player can complete a season, develop a roster, draft and trade players, and begin the next season with persistent history.
- Re-running the same state with the same simulator version and seed produces the same results.

## Phase 3 — Match engine and tactical play-by-play

**Being built alongside Phase 2, not deferred until it exits** (decided 2026-08-05, see the "simulator" bullet under Phase 2's season mechanics) — the possession engine below *is* what Phase 2's simulator needs to produce real game results, so it's being built now rather than gated behind a Phase 2/3 boundary. Left as its own phase heading here since the goal and exit criteria are still a coherent unit of work, not because it's on hold.

**Goal:** make individual games legible and strategically meaningful without a full animation project.

- **Possession-based engine.** Core possession loop, fouls/free throws, and the full quarters-and-scoreboard game loop are all **built** — see `0A_Completed.md`'s three match-engine entries (`simulatePossession`, `resolveTipOff`, `simulateMatch`). Alternating possession falls out of the engine automatically. A first round of pacing/scoring/bench-rotation calibration is done too (same entry) — combined score down to ~201 average from ~420, bench players now actually see the floor — though it's still not exact and the full "batch-simulate thousands of games against real WNBA numbers" pass is still open. Overtime is built too (5-minute periods until the tie breaks — a season simulator needs a winner out of every game). Still open here: a live/paced play-by-play presentation of the event log (the engine currently just returns the whole game's events at once, not a feed you watch unfold).
- **Live scrolling play-by-play feed** (not instant computation presented as a log afterward). Stops automatically for coaching adjustments at the end of every quarter. **Correction (2026-08-06):** the additional 2:00-mark stoppage is 4th-quarter-only, not every quarter — a last-ditch chance to adjust late in a close game, not a recurring mid-quarter check-in. It also fires on a tighter margin than originally written: within **7 points**, not 10.
- **Fully automatic substitutions: built. GM-set ranking: also built now (2026-08-07).** `substitution_policy.dart`'s `targetMinutesFor` assigns the reference table below by rating rank (best players play the most) -- still the automatic default every AI team uses, since they have no GM to set an order. The GM's own team now uses their real Bench Order instead (`targetMinutesForOrderedRoster`, `0A_Completed.md`'s bench-order-drives-minutes entry) -- dragging a player up or down in `DepthChartScreen` has real mechanical effect on games now, not just a cosmetic reorder. `pickOnCourt` re-picks the 5 furthest-behind-schedule players every 2 simulated minutes (foul-outs substitute immediately on top of that). Reference table, summing to a full 200-minute game across a 12-player active roster:

  | Rank | Target minutes |
  | --- | --- |
  | 1-3 | 30 each |
  | 4-5 | 26 each |
  | 6-7 | 14 each |
  | 8-9 | 8 each |
  | 10 | 6 |
  | 11-12 | 4 each |
  | 13-14 (developmental) | 0 |

- **Quarter-break/timeout choices: catalog locked (2026-08-17).** Every option nets more "pro" than "con" on purpose -- there's no morale mechanic in this game, and these nudges are explicitly standing in for one (a direct GM call): "give them a plan," not a min-maxed lever. Each pick lasts exactly as long as the stoppage that offered it -- a full quarter if picked at an ordinary break, or just the remaining ~2 minutes if picked at the 4th-quarter 2:00-mark stoppage. The +5%/-2.5% magnitudes deliberately match the engine's existing bonus scale (coach-matchup cap 5%, offense/defense-tactic bonuses "comfortably under" 5%, home court 2.5%) -- no separate calibration pass needed.

  | Option | Effect |
  | --- | --- |
  | Focus Defense | Defense +5%, offense -2.5% |
  | Focus Offense | Offense +5%, defense -2.5% |
  | Full-Court Press | Defense +5%, own stamina drain up (~1.4x), opponent's own possessions take ~2x as long |
  | Park the Bus | Both teams' possessions take longer -- clock-drain only, no rating change |
  | Pace Yourself | Both teams' possessions take longer, plus a small stamina-drain reduction |
  | Pick Up the Pace | Own possessions take less time, own stamina drain up a bit, Disruption +5% -- this is the comeback push |
  | Fire the Team Up! | +5 energy, whole roster, immediately |
  | Attack the Boards | Rebounding +5%, Perimeter Defense -2.5% |
  | Rest a Player | Auto-picks whoever's lowest energy in the current rotation and sits them for the duration, with a bigger-than-usual energy recovery bump. Deliberately no GM player-picker -- a coach's read of the bench, not a screen to micromanage. |
  | Stop the Bleeding | Situational -- only offered if the opponent is mid an unanswered run (8+ points, no answer) right before the stoppage. Defense +5%, no downside; the free pass is earned by the situation, not given every quarter. |

  **Mechanically grounded, not a new system.** The 4 pace options (Full-Court Press/Park the Bus/Pace Yourself/Pick Up the Pace) all reuse the *existing* per-team possession-duration lever `possession_engine.dart` already has for blowout-pace rubber-banding (`kBlowoutPaceMargin`/`offenseMargin` slowing a possession's `secondsElapsed`) -- a coach-picked trigger alongside the automatic score-margin one, not a new mechanic. Full-Court Press's stamina bump reuses `fatigue.dart`'s existing `fatigueDrainPerMinute` formula shape (a ~1.4x multiplier scales off each player's own Stamina rating, rather than one flat number hitting a 99-Stamina and a 50-Stamina player identically).

  **Still open**: the situational selection logic for which ~3 of these 10 options actually get shown at a given break. Stop the Bleeding is the one option with a real trigger condition so far; the other 9 are presumably always-eligible, which is more than "~3 at a time" can show without some further selection rule. Not designed yet.
- **Timeout system specifics** (count per game, what a "special play" modifies) — parked, deliberately not designed yet. Get the quarter-break check-ins working first.
- **Stamina & fatigue formulas**, captured as a starting design intent, not yet vetted or built. **Promoted to a blocker (2026-08-17):** planning the quarter-break coaching-options build surfaced that several sketched options ("reduce stamina drain," the halftime energy bump) have no underlying system to act on — `match_engine.dart` still lists "no energy/fatigue model" as a known simplification. Build this first, before the quarter-break/live-visual work below.
  - **Formulas locked and built (2026-08-17)** — real code now, `lib/features/match/engine/fatigue.dart`, tracked inside `simulateMatch` (`match_engine.dart`) and surfaced on `MatchResult.finalEnergy`. Validated two ways before locking in: hand-checked against `substitution_policy.dart`'s target-minutes table first (`TODO.md` item 8's sub-note), then re-validated with `tool/fatigue_diagnostic.dart` — 20 real games, real generated rosters, real possession-by-possession engine noise, not just hand-picked scenarios. One retune happened off that diagnostic's first real-game run (see below).
  - Energy pool: starts at 100 max, per game only -- resets every game, never persists between games (a direct GM call, 2026-08-17: no cross-game fatigue).
  - Drain per minute played: `2.6 * (1.5 - (Stamina / 100))` — a 99-stamina star drains ~1.33/min, a 70-stamina average player ~2.08/min, a 50-stamina player 2.60/min. **Retuned up from an initial `2 * (...)`** — the first real-game diagnostic run left even the heaviest-used rotation tier averaging under a 2% penalty, a direct GM call that ordinary heavy-minute play should feel it, not just foul-trouble/blowout/OT edge cases.
  - Fatigue penalty: no penalty above 80 energy; 0.5% stat penalty per point lost below 80. Ceiling is ~40% at 0 energy, confirmed intentional (2026-08-17) — deliberately far above every other rating modifier in the engine (home court 2.5%, traits 5%, coach-matchup cap 5%, offense shape/defensive tactic "comfortably under" 5%, all in `possession_engine.dart`) — full exhaustion is meant to be a severe, unmissable penalty, not another small tactical nudge. (The original design note's "floor of 50% minimum effectiveness" language was dead -- unreachable given a 0-100 energy pool -- and has been dropped in favor of the real ~40% ceiling this formula actually produces.)
  - Recovery: passive bench trickle, new for this pass (2026-08-17, not in the original design note) — `0.6 * (Stamina / 100)` energy per minute spent off the floor, capped at 100. **Retuned down from an initial `1.0 * (...)`**, same diagnostic-driven pass as the drain-rate bump above. Scales with Stamina the same direction as drain, so good conditioning helps both ends. Halftime still gives a flat +10 energy bump to the whole roster on top of this; quarter breaks otherwise give no *additional* bump beyond the ordinary bench trickle unless/until the coach picks a specific coaching option (ties into the quarter-break system above, still blocked on its own undesigned catalog).
  - **Final validated numbers** (`tool/fatigue_diagnostic.dart`, 20 games): the top two rotation tiers (1-3 and 4-5, the 30/26-minute targets) now take a real, near-universal penalty most games — avg final energy 66/61, 98-100% of their player-games crossing the fatigue threshold at all, avg implied penalty 7-9%, with a real (if small) tail into "severe" (<50 energy) territory for the 4-5 tier. Every tier below that (14 minutes and under) stays essentially untouched (0-8% of player-games ever crossing the threshold). One honest wrinkle: the by-Stamina-rating comparison (independent of rotation tier) got muddier at these settings — a poor-stamina player playing far fewer minutes can land at a similar or even slightly higher final energy than a great-stamina player carrying nearly double the workload, since Stamina is absorbing a much bigger minutes gap rather than producing a strictly higher number outright. Considered and accepted, not chased further.
  - **Gameplay effect: built (2026-08-17)**. `fatigueBonusFor`'s penalty is summed into every `possession_engine.dart` rating contest a fatigued player touches (passing, shooting, free throws, blocking, rebounding, both offense and defense) via that file's `_fatigueBonus` helper -- the same additive-bonus-accumulator slot `OffenseShapeBonus`/`DefenseTacticBonus`/`coachMatchupBonus` already share, exactly the hook this appendix originally sketched. Re-validated post-wiring against the existing scoring calibration (`match_engine.dart`'s own doc comment cites ~201 combined average as the prior target) via `tool/fatigue_diagnostic.dart`: 205.1 avg combined score across 20 games with fatigue fully live, well within normal batch noise -- confirms fatigue adds realism/variance symmetrically rather than skewing total scoring one direction.
  - **Still open**: substitutions don't react to fatigue yet -- `pickOnCourt`/`targetMinutesFor` (`substitution_policy.dart`) are still driven purely by target minutes and foul-outs, no energy-aware "sit the gassed starter" logic. `MatchResult.finalEnergy` is deliberately kept available past what gameplay itself needs, for a future post-game consumer (a direct GM ask, 2026-08-17: a "most tired players" callout that could inform moving a worn-down player down the rotation) -- no such consumer built yet, same transient/game-scoped lifetime as the rest of `MatchResult` (never persisted, matching the "no cross-game fatigue" call already locked in above).
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
