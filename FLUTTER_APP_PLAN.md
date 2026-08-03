# WBallers Flutter App Plan

## Product vision

Build a mobile-first women's basketball management game: players build a club, develop a roster, compete through seasons, make tactical choices, and see an original league develop over time. The current web portrait tool is a useful seed asset; it is not the app itself.

The recommended first release is a **single-player, offline-capable franchise mode** with optional account sync. Live head-to-head, social features, and monetization should wait until the core simulation is proven fun and reliable.

## Guiding decisions

- **Platforms:** Flutter for iOS and Android; design the domain layer so a web build remains possible later.
- **Backend:** Supabase for authentication, PostgreSQL game data, Storage for uploaded images, Edge Functions for trusted multiplayer/server-side work, and optional Realtime later.
- **Sign-in:** Google and Apple sign-in on mobile, plus an anonymous/guest path that can be upgraded to an account. Apple sign-in is required if iOS offers other third-party sign-in methods.
- **Game model:** keep simulation logic deterministic and independent of Flutter widgets and Supabase. Use a seed plus saved game state so seasons and matches can be reproduced and tested.
- **Visual identity:** use only original art, names, logos, data, and player likenesses, or assets with rights cleared for commercial use. Do not imply affiliation with real leagues or athletes.

## Phase 0 — Foundation and product definition

**Goal:** establish a shippable Flutter foundation before game features accumulate.

### Deliverables

- Create the Flutter application with development, staging, and production configuration.
- Set up a clean app architecture: feature modules, routing, state management, repositories, domain models, and dependency injection. Pick and document one approach (for example Riverpod + GoRouter + Freezed/json_serializable).
- Establish design foundations: color, typography, spacing, dark mode, accessibility rules, loading/empty/error states, and a reusable component library.
- Create Supabase projects and environments.
- Configure Supabase Auth: anonymous guest access, Google sign-in, Apple sign-in, account linking, logout, and account deletion.
- Define Row Level Security policies from day one. A user may read/write only her own franchise and saved-game data unless a later social feature explicitly grants access.
- Set up Storage buckets and image constraints for future roster photos.
- Add crash reporting, analytics with a privacy-conscious event list, remote configuration/feature flags, and basic in-app feedback.
- Set up CI: formatting, static analysis, unit tests, Android/iOS builds, signed release workflow, and environment-secret handling.
- Add the required operational materials: privacy policy, terms, support contact, data-deletion flow, App Store/Play Store identifiers, and consent choices where required.
- Audit and catalog the current web assets/data (`teams.json`, portrait parts, and manifest) for possible migration. Define an asset pipeline and licensing status instead of copying the browser rendering code into the app.

### Exit criteria

- A guest can open the app, create or restore an account, and reach a protected home screen.
- A signed-in user has an isolated Supabase profile and a reliable local/offline cache.
- CI produces installable builds; errors and key onboarding events are observable.

## Phase 1 — Players, teams, and rosters

**Goal:** make the core collection and management loop satisfying before simulating a full league.

### Player system

- Player identity: name, age/experience, nationality or hometown if desired, position(s), handedness, biography, personality/archetype, and status.
- Basketball ratings: shooting by area, finishing, playmaking, ball handling, defense, rebounding, athleticism, stamina, discipline, and potential. Keep ratings data-driven and visible only at the level that supports the intended game style.
- Derived capabilities: overall, role fit, lineup chemistry, fatigue/readiness, morale, injury risk, and development trajectory.
- Player detail screen with ratings, season statistics, contract/status, portrait, and role explanation.
- Seeded player generator and a small curated starting set; no real-player data until rights are addressed.

### Team and roster system

- Team profile: original name, colors, city, prestige, finances/budget (if in initial scope), staff placeholders, and visual identity.
- Roster rules: positions, active/inactive roster, starters, bench order, captain, depth chart, and validation warnings.
- Roster screens: team hub, lineup editor, player comparison, player search/filtering, and roster summary.
- Initial acquisition flow: draft/expansion draft or starting-team selection. Choose one simple onboarding route for the MVP.
- Save-game schema for user franchises, players, teams, and roster memberships. Keep immutable league templates separate from player-owned saves.

### Exit criteria

- A new player can choose a club, inspect a complete roster, edit a legal lineup, and return later without losing progress.
- Unit tests cover rating calculations, roster legality, persistence/migrations, and account isolation.

## Phase 1.5 — Portraits and roster photos

**Goal:** add personality without making photography or image moderation a dependency for the core game.

### Recommended rollout

1. **Launch with generated portraits.** Port or recreate the current layered avatar system in Flutter, or pre-render portraits through a controlled asset pipeline. Store compact appearance data, not a unique full image for every generated player.
2. **Add team/player images.** Support original in-game illustrations first; then allow a user to upload an image only for her own franchise if desired.
3. **Add moderation and controls before social display.** Images that other users can see need reporting, review, removal, rate limits, and a clear acceptable-use policy.

### Technical requirements

- Supabase Storage paths scoped by user/franchise, image type/size validation, thumbnails, cache strategy, replacement/deletion behavior, and image-attribution metadata.
- An accessible avatar fallback and a no-photo option.
- Portrait rendering tests for layering order, recoloring, and missing assets.

### Exit criteria

- Every roster view has a fast, consistent portrait/avatar experience.
- User-provided images are secure, bounded in cost, and can be removed by the owner or moderation process.

## Phase 2 — League, season, and world simulation

**Goal:** turn roster management into an ongoing basketball world.

### Deliverables

- League configuration: divisions/conferences, schedule format, playoffs, tiebreakers, season calendar, and difficulty settings.
- League screens: standings, schedule, results, team pages, player leaders, awards, injuries/news, and historical records.
- A fast game simulator that can run AI-vs-AI results deterministically.
- Progression between games: fatigue/recovery, injuries, morale, player development/regression, basic contracts/transactions, and event/news generation.
- Season lifecycle: preseason, regular season, playoffs, offseason, draft/free agency (start simple), and multi-season history.
- Balancing tools: simulation batches, exported diagnostics, distribution checks, and seeded regression scenarios.

### Exit criteria

- A player can simulate a complete season, understand every result, and begin the next season with persistent history.
- Re-running the same game state with the same simulation version and seed produces the same result.

## Phase 3 — Head-to-head match engine and tactics

**Goal:** make individual games tense, legible, and strategically meaningful.

### Deliverables

- Possession-based engine: pace, shot selection, turnovers, fouls, rebounds, substitutions, clock/game states, and end-game logic.
- Team tactics: offensive style, defensive coverage, pace, rotation rules, matchups, shot priorities, and coaching adjustments.
- Player roles and tactical fit that materially affect outcomes without reducing games to a single overall rating.
- Match presentation: live play-by-play first, then a visual court/shot-chart layer if it improves understanding. Do not block Phase 3 on expensive animation.
- Pre-game scouting, in-game timeouts/adjustments, post-game box score, advanced stats, and tactical recap.
- Simulation and balance test suite covering edge cases, strategic viability, and statistical realism.

### Exit criteria

- A player can explain why a game was won or lost and make a meaningful tactical adjustment for the rematch.
- Tactics, ratings, fatigue, and randomness each have tested, observable effects.

## Phase 4 — Deeper franchise management

**Goal:** add long-term decisions after the fundamental loop is fun.

- Scouting, draft classes, recruiting/international pipeline, and hidden information.
- Contracts, salary cap/budget, trades, free agency, waivers, and staff/coaches.
- Training plans, facilities, chemistry, player goals, story events, and rivalries.
- Team branding: original logos, uniforms, arena presentation, and franchise customization.
- Historical league records, Hall of Fame, achievements, and challenge scenarios.

## Phase 5 — Online, social, and live operations

**Goal:** add shared experiences only after authoritative game rules and safety controls are ready.

- Cloud save conflict resolution and cross-device continuity.
- Async head-to-head: submit tactics/lineups, run matches in a trusted server function, show replays/results. This is recommended before real-time play.
- Friends, private leagues, leaderboard seasons, sharing controls, blocking/reporting, and moderation tooling.
- If real-time head-to-head is desired: a separate authoritative match service, anti-cheat design, reconnection handling, matchmaking, load testing, and customer support plan. Supabase alone is not a complete real-time competitive game backend.
- Live events and balance updates behind feature flags, with a rollback process and player-facing patch notes.

## Phase 6 — Launch, growth, and iteration

**Goal:** release deliberately, learn from real play, and protect the community.

- Closed alpha with telemetry and structured feedback; then staged regional/platform beta.
- Funnel and gameplay metrics: onboarding completion, first lineup change, first completed game/season, retention, crash-free sessions, and simulation abandonment points.
- Accessibility audit: scalable text, screen-reader labels, color-safe indicators, motion reduction, localization-ready strings, and offline behavior.
- Performance/battery profiling on supported devices; database/storage cost monitoring; backups and incident runbooks.
- Store listing, screenshots/video, support documentation, release checklist, and a small cadence of post-launch improvements.

## Cross-cutting work to do throughout

- Version every simulation rule and saved-game migration; never silently invalidate a franchise.
- Write automated tests for domain logic before UI-level tests. The simulation engine is the highest-value test target.
- Keep authoritative rules and sensitive progression decisions off the client once competition or purchases exist.
- Treat analytics, notifications, and any monetization as opt-in/product decisions with clear privacy and regional compliance review.
- Maintain a playable vertical slice at all times: create/choose team → manage roster → play/simulate game → see consequences → save.

## Suggested milestones

| Milestone | Player-visible outcome |
| --- | --- |
| Foundation demo | Sign in or play as a guest, with a polished app shell. |
| Roster vertical slice | Choose a team, inspect/edit a lineup, and save it. |
| Season vertical slice | Simulate a short season, view standings, and reach playoffs. |
| Tactical vertical slice | Make tactical choices in a playable game and receive an understandable box score. |
| Beta candidate | Play multiple seasons reliably with balanced results and recovered saves. |

## Decisions to make before implementation begins

1. Is the MVP a pure franchise/GM game, a coach game with live tactical calls, or a hybrid? This determines the detail level of Phase 3.
2. Should the initial release be completely offline after download, cloud-synced single-player, or online-first? The recommended answer is offline-capable with optional sign-in/sync.
3. Are users creating fictional players only, or can they use real names, photos, and data? Rights and moderation scope change sharply if real people are involved.
4. What is the intended business model: premium paid app, free with no monetization, cosmetic purchases, or something else? Avoid designing progression around monetization before this is settled.
5. Is portrait customization a central creative feature or simply a way to distinguish players? That determines whether Phase 1.5 is minimal or substantial.
6. Is cross-platform launch (iOS + Android) required on day one, and what accessibility/localization commitments are non-negotiable?

## First implementation target

The best first build is a thin vertical slice, not all of Phase 1: guest sign-in → choose one of several original teams → browse generated players → set a valid starting five and bench → simulate one exhibition game → read the box score → save and restore. It validates the app foundation, data model, roster UX, and game loop before league and multiplayer scope expand.
