# Women's Basketball Manager: App Plan

## Product vision

Build an Android-first, single-player women's basketball franchise game. Players create an expansion club, develop a changing roster through seasons, draft and trade players, and make limited but meaningful coaching choices during games. The league is entirely fictional.

The game works completely offline after installation. It has no accounts, cloud sync, multiplayer, or real-world player/team data. The existing web portrait tool and LibreSprite artwork are seed assets for a core in-game customization system.

## Guiding decisions

- **Title:** Women's Basketball Manager.
- **Platforms:** Flutter for Android first, with a web build as the next priority. iOS is not currently in scope.
- **Persistence:** Local-only saves, with explicit save-game versions and migrations. No backend or sign-in is required.
- **Monetization:** Free with carefully placed AdMob banners on selected screens, including the dashboard and gameplay screen. Ads must not interrupt game flow.
- **Game model:** Keep the simulator deterministic and independent of Flutter widgets. A seed plus saved game state must reproduce seasons and games for testing.
- **League:** 20 original teams split evenly between Atlantic and Pacific conferences. Teams may use real U.S. and Canadian cities but must not resemble real organizations.
- **Fictional world:** Use only original names, teams, portraits, logos, colleges, and player data. Build an eventual rookie pipeline of about 100 fictional colleges in plausible U.S. and Canadian locations.
- **Portraits:** Port the existing layered rendering, weighted selection, and recoloring logic to Flutter. Store appearance data and cache completed portraits as PNGs. The coach can later edit individual players and coaches.

## Phase 0 — Foundation and product definition

**Goal:** Establish a shippable, offline Flutter foundation and a clear fictional world.

### Deliverables

- Create the Flutter app with Android development and production configuration, structured so web support can follow.
- Set up feature modules, routing, state management, repositories, domain models, dependency injection, formatting, static analysis, and tests. Pick and document one approach.
- Establish design foundations: color, typography, spacing, dark mode, accessibility rules, loading/empty/error states, and reusable components.
- Implement local persistence, backup/export considerations, and versioned save-game migrations.
- Reserve simple placeholder banner space on screens as they're designed, starting with the dashboard. No ad SDK integration yet — see Phase 5 for the real ad service boundary.
- Audit and catalog the current portrait assets and manifest. Define a Flutter asset pipeline and licensing record; the initial migration specification lives in `portraits.md`.
- Define the initial 20-team Atlantic/Pacific league template and rules for original names, colors, and branding.
- Define 100 fake universities from which players could be drafted
- Set up CI for formatting, static analysis, unit tests, and Android builds.

### Exit criteria

- The player can open the app directly into a local game shell with no sign-in or network dependency.
- Local saves survive app restarts and are versioned for safe future migrations.
- CI produces an installable Android build.

## Phase 1 — Expansion franchise, players, and rosters

**Goal:** Make the franchise setup and roster-management loop satisfying.

### Player system

- Player identity: fictional name, age/experience, hometown, position(s), handedness, biography, personality/archetype, and status.
- Basketball ratings, all on the shared 1-99 scale, per the "Final Stat Architecture" in `star_system.md`: four physical (speed, agility, strength, stamina), four offensive (ball control, passing, **interior offense**, **perimeter offense**), and four defensive/playmaking (perimeter defense, interior defense, disruption, blocking), plus potential as a separate ceiling rating. Interior/perimeter offense cover all offensive work in that zone (finishing, post moves, offensive rebounding instinct, boxing out for interior; jump shooting, shot fakes, footwork for perimeter), not just makes/misses — no separate finishing rating. Rebounding isn't stored or derived at all — it's the universal action-success formula applied twice at simulation time (offensive rebound: strength + interior offense; defensive rebound: strength + interior defense).
- Derived capabilities: overall, role fit, lineup chemistry, fatigue/readiness, morale, injury risk, and development trajectory.
- Player detail screen with ratings, season statistics, portrait, role explanation, nickname, and earned cosmetics.
- Seeded player generation (question.md decision 23): `generatePlayer` (name, hometown, age/service, position-biased ratings) and `generateStartingRoster` (a full 12-player weak active roster, guaranteed below the four-star threshold, with full position coverage). A curated initial pool beyond the generated starting rosters is still open.

### Coach system

**The player is the General Manager, not the coach** (question.md decision 24). The coach is a hired NPC staff member the GM manages — generated at onboarding, not player-named.

- Coach identity: generated name and portrait (the portrait system already treats the coach as a distinct entity — see `portraits.md`).
- Coach stats — a small block, deliberately much smaller than player ratings: **Offense**, **Defense**, **Development**, **Motivation**, and **Management**. Offense/Defense affect the quality of in-game tactical calls (Phase 3 quarter-break/timeout choices); Development affects player growth speed (Phase 2); Motivation affects team morale/chemistry (Phase 2) and close-game resilience (Phase 3); Management affects trade and draft shrewdness (Phase 2).
- Defined here alongside player identity even though most of these stats have no consumer yet — their effects get wired up progressively as Phase 2 and Phase 3 systems are built.

### Team and roster system

- Expansion onboarding (`OnboardingScreen`, `createExpansionFranchise`): the GM (not the coach — question.md decision 24) names themselves and the club, picks a home city and conference, and gets a generated coach plus a weak generated roster. Does not yet replace a randomly selected existing team in its chosen conference — that's bookkeeping deferred to a future `League` concept (Phase 2), so the league isn't actually held at 20 teams yet once a franchise exists.
- Team profile: original name, colors, city, prestige, and visual identity. Onboarding only covers name/colors(from a small starter palette)/city; prestige and a full custom identity editor are still open.
- Roster rules: positions, starters, bench order, captain, depth chart, and validation warnings. Three roster statuses, loosely mirroring the real WNBA (question.md decision 22, `wnba_rules_reference.md`): **Active** (up to 12, capped at 2 five-star (90-99 OVR) plus at most 6 four-star-or-better (78-99 OVR) combined — the star-rating system in `star_system.md`, replacing a salary cap; no enforced minimum, running short-handed is just a disadvantage), **Developmental** (at most 2, exempt from the star caps, restricted to 3 years of service or fewer), and **Reserve/Inactive** (unconstrained catch-all for anyone under contract but not active). Star limits lock at the regular-season buzzer, not mid-season, and rosters must be legal again before free agency and the draft.
- Roster screens: `TeamRosterScreen` covers the roster summary (grouped by status, sorted by position then overall) -- the Team tab. Team hub (beyond the roster list), lineup editor, player comparison, and player search/filtering are still open.
- Save-game schema for franchise, players, teams, roster memberships, and simulation seed is built (`Franchise`, manual JSON serialization per feature, proven round-tripping through `SaveEnvelope`/`SaveRepository`). League template isn't part of the schema yet since franchises don't reference the league at all yet (see the onboarding note above).

### Exit criteria

- A new player can create an expansion club, inspect a complete roster, edit a legal lineup, and resume later without losing progress.
- Unit tests cover rating calculations, roster legality, generated-roster constraints, and local persistence/migrations.

## Phase 1.5 — Portraits and earned identity

**Goal:** Make player identity and customization a defining part of the game.

### Deliverables

- Rebuild the current layered avatar system in Flutter using the existing artwork, including part weights, layering order, and magenta-placeholder recoloring.
- Store compact appearance data and render/cache completed portraits as PNG files locally.
- Provide coach editing for individual player and coach appearances, with an accessible fallback portrait.
- Implement an achievement system for cosmetic unlocks and nickname suggestions.
- Award triggers include league MVP, scoring leader, defensive MVP, most defensive disruptions (blocks + steals), and future achievement types. Across a 20-team, 240-player league, aim for roughly 5 nicknames earned per season.
- Let the game suggest a nickname, while always allowing the coach to change it. On the 19 AI-run teams the suggestion is applied automatically; on the coach's own team, the coach can type their own instead.
- Player traits: the full 27-trait catalog lives in `traits.md` (question.md decision 21) — earnable, visible traits replacing the hidden-stat idea entirely, so a coach can scout for them instead of them being numbers nobody can see. Some traits are assignable at generation/draft time (Phase 1 work); most are earned from in-season or in-game situations, so their triggers get wired up progressively as Phase 2's season sim and Phase 3's match engine come online — same shape as the coach stats defined in Phase 1 before anything could consume them.

### Exit criteria

- Every roster screen displays a fast, consistent portrait.
- Portrait edits persist correctly, and rendering tests cover layering, recoloring, weights, and missing assets.
- Earned nicknames and cosmetic unlocks are visible, editable where appropriate, and persistent.
- Traits are visible on the player detail screen and persist correctly; draft-time trait assignment is testable even before any trait requiring a season/game situation can be earned.

## Phase 2 — League, season, and franchise simulation

**Goal:** Turn roster management into an ongoing fictional basketball world.

### Deliverables

- League configuration for the 20-team Atlantic/Pacific format, schedule, playoffs, tiebreakers, season calendar, and difficulty.
- League screens: standings, schedule, results, team pages, player leaders, awards, news, and historical records.
- A fast deterministic simulator for AI-vs-AI results and full-season progression.
- Player development/regression, fatigue/recovery, morale, injuries, news, and event generation.
- Draft classes sourced from the fictional college pipeline; start with a simple, transparent draft.
- Basic trade system with AI valuation and clear player-facing explanations.
- Season lifecycle: preseason, regular season, playoffs, offseason, draft, and multi-season history.
- Balancing tools: simulation batches, diagnostics, distribution checks, and seeded regression scenarios.

### Exit criteria

- A player can complete a season, develop a roster, draft and trade players, and begin the next season with persistent history.
- Re-running the same state with the same simulator version and seed produces the same results.

## Phase 3 — Match engine and tactical play-by-play

**Goal:** Make individual games legible and strategically meaningful without making them a full animation project.

### Deliverables

- Possession-based engine: pace, shot selection, turnovers, fouls, rebounds, automatic substitutions, clock/game states, and end-game logic. Action success uses the universal formula from `star_system.md`: Physical Stat + Skill/Defensive Stat.
- Live textual play-by-play, pre-game setup, post-game box score, advanced stats, and tactical recap.
- Strategy choices at quarter breaks: offensive style, defensive coverage, pace, matchups, and shot priorities.
- A limited timeout system for special plays and in-game adjustments.
- Player roles and tactical fit that materially affect outcomes without reducing games to a single overall rating.
- Simulation and balance test suite covering edge cases, strategic viability, and statistical realism.

### Exit criteria

- A player can understand why a game was won or lost and make a meaningful adjustment in a rematch.
- Tactics, ratings, fatigue, and randomness each have tested, observable effects.

## Phase 4 — Court presentation and deeper franchise management

**Goal:** Add visual clarity and long-term depth after the text-based game loop is proven.

- Add a simple court/shot-chart presentation that shows shot locations and key play context. Do not require full player animation.
- Add scouting, richer draft classes, recruiting/international pipelines, and hidden information.
- Expand trades and add contracts, salary cap/budget, free agency, waivers, and staff/coaches as appropriate.
- Add an Assistant GM: a staff role that proactively surfaces roster suggestions (e.g. "player X would fill our open roster spot"). Not designed yet — question.md decision 22.
- Add training plans, facilities, chemistry, player goals, story events, rivalries, branding, uniforms, and arenas.
- Add historical records, Hall of Fame, achievements, and challenge scenarios.
- Add a settings screen: light/dark theme, selectable court color themes, and adjustable text size for players who need larger text.

## Phase 5 — Launch and iteration

**Goal:** Release a reliable offline Android game, learn from solo players, and prepare web support.

- Integrate the real AdMob SDK behind an `AdService` boundary, using test ad units in development and production ad unit IDs at release, on the dashboard and gameplay screens' reserved placements.
- Closed alpha and staged Android beta with structured feedback.
- Privacy-conscious, optional analytics only if they preserve the offline product promise.
- Measure onboarding completion, first lineup change, first game/season completion, crashes, and simulation abandonment.
- Accessibility audit: scalable text, screen-reader labels, color-safe indicators, motion reduction, and offline behavior.
- Performance and battery profiling across supported Android devices.
- Operational basics: privacy policy, terms, support contact, and Play Store identifiers. Account deletion flows are unnecessary because the game has no accounts.
- Play Store listing, screenshots/video, support documentation, release checklist, and post-launch improvement cadence.
- Assess and build the web release once the Android experience is stable.

## Cross-cutting work

- Version every simulation rule and saved-game migration; never silently invalidate a franchise.
- Prioritize automated tests for domain logic and the simulation engine before UI-level tests.
- Keep the game playable without a connection at every stage.
- Maintain a vertical slice at all times: create expansion team → manage roster → play/simulate game → see consequences → save.

## Suggested milestones

| Milestone | Player-visible outcome |
| --- | --- |
| Foundation demo | Open an offline Android app and start/resume a local save. |
| Expansion roster slice | Create a club, receive a varied weak roster, edit a lineup, and save it. |
| Season slice | Simulate a short season, view standings, develop players, and reach a draft. |
| Tactical slice | Follow live play-by-play, make quarter/timeout choices, and read a clear box score. |
| Presentation slice | See shot locations on a simple court presentation. |
| Release candidate | Play multiple reliable seasons with balanced results and recoverable saves. |

## First implementation target

Build a thin vertical slice: create an expansion franchise → name it → receive a weak generated roster → browse generated, editable portraits → set a valid starting five and bench → simulate one exhibition through play-by-play → read the box score → save and restore. It validates the local app foundation, roster UX, portrait system, and core game loop before full-league depth is added.
