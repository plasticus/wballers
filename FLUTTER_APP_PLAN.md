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

- Player identity: fictional name, age/experience, hometown, position(s), handedness, biography, archetype, traits, and status. Archetype and traits are built (question.md decision 27, Phase 1.5 work pulled forward): `Archetype` (`archetypes.md`) and `Trait` (`traits.md`) enums, generation (`generateArchetype`, `generateTraits`), persistence, and display in `TeamRosterScreen`'s roster row.
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

- Expansion onboarding (`OnboardingScreen`, `createExpansionFranchise`): the GM (not the coach — question.md decision 24) names themselves and the club, picks a home city and conference, and gets a generated coach plus a weak generated roster. The form shows the chosen conference's existing 10 teams for reference (`TeamRow`, shared with `LeagueScreen`). Does not yet actually replace a team: no random-by-default selection with an opt-in "pick which team to replace" checkbox, and no persisted record of the replacement — that's bookkeeping deferred to a future `League` concept (Phase 2), so the league isn't actually held at 20 teams yet once a franchise exists.
- Team profile: original name, colors, city, prestige, and visual identity. Onboarding only covers name/colors(from a small starter palette)/city; prestige and a full custom identity editor are still open.
- Roster rules: positions, starters, bench order, captain, depth chart, and validation warnings. Three roster statuses, loosely mirroring the real WNBA (question.md decision 22, `wnba_rules_reference.md`): **Active** (up to 12, capped at 2 five-star (90-99 OVR) plus at most 6 four-star-or-better (78-99 OVR) combined — the star-rating system in `star_system.md`, replacing a salary cap; no enforced minimum, running short-handed is just a disadvantage), **Developmental** (at most 2, exempt from the star caps, restricted to 3 years of service or fewer), and **Reserve/Inactive** (unconstrained catch-all for anyone under contract but not active). Star limits lock at the regular-season buzzer, not mid-season, and rosters must be legal again before free agency and the draft. **Starters** are built (`StartingLineup`, `evaluateLineupLegality`, question.md decision 25): one player per position, defaulted at onboarding to the best-available eligible active player and editable via `LineupEditorScreen`, validated against position eligibility (primary or secondary), the active roster, and no player double-booked across two slots. Bench order, captain, and depth chart beyond the starting five are still open.
- Roster screens: `TeamRosterScreen` covers the roster summary (grouped by status, sorted by position then overall, starters marked) -- the Team tab. `LineupEditorScreen` covers the starting five. Team hub (beyond the roster list), player comparison, and player search/filtering are still open.
- Save-game schema for franchise, players, teams, roster memberships, starting lineup, and simulation seed is built (`Franchise`, manual JSON serialization per feature, proven round-tripping through `SaveEnvelope`/`SaveRepository`). League template isn't part of the schema yet since franchises don't reference the league at all yet (see the onboarding note above). `Player` gained a stable `id` so save data (and the lineup specifically) can keep referencing the same player across a save/reload.

### Exit criteria

- A new player can create an expansion club, inspect a complete roster, edit a legal lineup, and resume later without losing progress.
- Unit tests cover rating calculations, roster legality, generated-roster constraints, and local persistence/migrations.

## Phase 1.5 — Portraits and earned identity

**Goal:** Make player identity and customization a defining part of the game.

### Deliverables

- Rebuild the current layered avatar system in Flutter using the existing artwork, including part weights, layering order, and magenta-placeholder recoloring. **Built** (question.md decision 28): `PortraitAppearance`/`PortraitManifest`/`PortraitWeights` domain models, `generatePortraitAppearance` (seeded; never rolls neon hair colors or coach-only shoulders/hats/glasses at generation time -- those are unlock/editor-only), a `dart:ui` compositor (`portrait_renderer.dart`) porting `render.js`'s recoloring math pixel-for-pixel, and `FilePortraitCache` for the rendered PNGs. `Player`/`Coach` both carry a nullable `appearance`; every generation function threads an *optional* `PortraitWeights` parameter through so existing seeded-determinism tests are untouched when it's omitted. Wired into onboarding (awaits the bundled `weights.json` before creating a franchise) and displayed via `PortraitImage` on `TeamRosterScreen`'s roster rows, with an accessible fallback when no appearance exists yet.
- Store compact appearance data and render/cache completed portraits as PNG files locally. **Built** -- appearance data round-trips through the normal `Player`/`Coach` JSON persistence; rendered PNGs are cached separately via `PortraitCache`/`FilePortraitCache` (`core/persistence/`), keyed on appearance version and jersey color so trades/edits can't serve a stale image.
- Provide coach editing for individual player and coach appearances, with an accessible fallback portrait. **Built** (question.md decision 29): `PortraitEditorScreen` covers every field/color/style option the doc calls for (skin tone, hair, eyes, eyebrows, nose, mouth, accessories for everyone; shoulders/hats/glasses/facial hair for the coach too), with a live un-cached preview. Reachable by tapping a roster row's portrait in `TeamRosterScreen`, or the new coach row above it. Special/neon hair colors are gated behind having earned an achievement (question.md decision 30) -- see below, since nothing can earn one yet, the picker exists and is tested but nobody will see it in the running app until Phase 2.
- Implement an achievement system for cosmetic unlocks and nickname suggestions. **Data model and mechanism built** (question.md decision 30): `Achievement` enum, `PlayerAchievementRecord`, `grantAchievement`/`suggestNickname` (a curated nickname pool per award type), and the special-hair-color unlock gate in the portrait editor. **Not built, and can't be until Phase 2:** anything that actually determines a winner.
- Award triggers include league MVP, scoring leader, defensive MVP, most defensive disruptions (blocks + steals), and future achievement types. Across a 20-team, 240-player league, aim for roughly 5 nicknames earned per season. All four award types exist in the `Achievement` enum now; determining who actually wins one needs Phase 2's season simulation (tracked per-player stats, a standings/leaderboard concept) to exist first -- there is currently no way for any player, GM's team or otherwise, to objectively be "the league's scoring leader."
- Let the game suggest a nickname, while always allowing the coach to change it. On the 19 AI-run teams the suggestion is applied automatically; on the coach's own team, the coach can type their own instead. `grantAchievement` produces the suggestion; deciding whether to auto-apply it (AI teams) or hold it for GM approval (their own team) is season-end ceremony logic that belongs to Phase 2, not the generator -- it needs team/season context this layer doesn't have. Nicknames are deliberately *not* a general GM rename tool (an earlier pass got this wrong, giving the GM a free-text field in `PortraitEditorScreen` -- corrected per the user: a GM can't assign a nickname to an arbitrary player on a whim, it's earned). `Player.nickname` and `updatePlayerNickname` exist as infrastructure only; no UI sets a nickname today, and won't until there's a real earn-and-suggest moment for the GM to respond to.
- Player traits: the full trait catalog (29 traits, not 27 as decision 21 says — stale count) lives in `traits.md` (question.md decisions 21, 27) — earnable, visible traits replacing the hidden-stat idea entirely, so a coach can scout for them instead of them being numbers nobody can see. `Trait` domain model, generation-time rolling (`generateTraits`, 0-3 per player), and persistence are built. Most traits are still only assignable at generation/draft time in practice — their in-season/in-game triggers get wired up progressively as Phase 2's season sim and Phase 3's match engine come online, same shape as the coach stats defined in Phase 1 before anything could consume them. Still open: a dedicated trait display on the player detail screen (`TeamRosterScreen`'s roster row shows archetype but not traits yet — traits are more numerous and need their own treatment, e.g. icons or an expandable list).
- Player archetypes: `archetypes.md`'s position-keyed play-style catalog is built (question.md decision 27) — `Archetype` domain model, `kArchetypesByPosition`, random-per-position generation (`generateArchetype`), persistence, and display in the roster row. Rating-threshold-based selection (so a "Sniper" actually correlates with high perimeter offense) is still explicitly open, per `archetypes.md`'s own note.

### Exit criteria

- Every roster screen displays a fast, consistent portrait. (`TeamRosterScreen` does; other roster/detail screens don't exist yet to wire it into.)
- Portrait edits persist correctly, and rendering tests cover layering, recoloring, weights, and missing assets. (Rendering/recoloring/layering/weights-loading are all tested against the real bundled assets; edits now persist too, via `PortraitEditorScreen` and dedicated provider/widget tests.)
- Earned nicknames and cosmetic unlocks are visible, editable where appropriate, and persistent. (Data model, persistence, GM-editing, and the cosmetic-unlock gate are all built and tested; nothing can be *earned* through play yet, since that needs Phase 2's season simulation.)
- Traits are visible on the player detail screen and persist correctly; draft-time trait assignment is testable even before any trait requiring a season/game situation can be earned. (Persistence and generation-time assignment are done; a dedicated player detail screen showing them individually is still open — today only the archetype shows, on the roster row.)

## Phase 2 — League, season, and franchise simulation

**Goal:** Turn roster management into an ongoing fictional basketball world.

### Deliverables

- League configuration for the 20-team Atlantic/Pacific format, schedule, playoffs, tiebreakers, season calendar, and difficulty. This is also where the other 19 teams get actual rosters for the first time (`kInitialLeagueTeams` is identity-only today — no players). Target roughly 75-80 average team overall for a freshly generated league, distinct from an expansion club's own deliberately weak roster (`star_system.md`'s star tiers imply teams generally cluster in 4-star territory, not scattered across the full range). Concretely: each team should generate with roughly 4 four-star-or-better players (staying under the 6-player combined cap from `star_system.md`) and at least 2 players carrying a trait, so a freshly generated team already reads as a real roster with texture rather than 12 generic bodies -- important for actually being able to look at a generated team and evaluate whether the generation logic is producing sensible results.
- League screens: standings, schedule, results, team pages, player leaders, awards, news, and historical records. `LeagueScreen` should read as a real standings page once there's a season to report on: win-loss record, and when between seasons, last season's regular-season record plus the champion (🏆). Today it's a static team directory with no season data behind it — building a standings *layout* now would just be decoration with nothing real to show.
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
