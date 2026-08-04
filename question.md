# Decisions for Women's Basketball Manager

## 1. Core game

**Decision:** A franchise-management-first hybrid. The player manages a roster over multiple seasons, while games provide play-by-play and limited coaching decisions. Automatic substitutions keep the player focused on strategy rather than micromanagement.

## 2. Connectivity

**Decision:** Completely offline-capable. There is no planned multiplayer, account system, cloud sync, or online requirement.

## 3. Fictional world

**Decision:** Every team, athlete, coach, college, logo, and data point is fictional. Teams may use real U.S. and Canadian cities, but must not mirror real organizations. Rookie pipelines will include roughly 100 fictional colleges located in believable U.S. and Canadian places.

## 4. Business model

**Decision:** Free-to-play with AdMob banner placements on selected screens, including the dashboard/home and gameplay screens. Ads should not appear on every screen or interrupt play.

## 5. Portraits

**Decision:** Portrait customization is a core feature. The coach can customize player and coach portraits extensively, including editing individual players after they are generated.

## 6. Platforms

**Decision:** Android launches first. A web build is the next platform priority. iOS is not currently in scope.

## 7. Match presentation

**Decision:** Build in phases: play-by-play first; then quarter-break and timeout coaching choices; then a simple court visualization that shows shot locations and related game action. There is no need for full animated on-court play.

## 8. New-game experience

**Decision:** The player creates an expansion franchise, chooses its name and identity, and inherits a weak roster. Starting rosters should vary between new games.

## 9. Essential franchise systems

**Decision:** Player development, drafts, and trades are priorities for the first playable franchise experience. Other systems can follow after the core loop works.

## 10. Competitive play

**Decision:** No player-vs-player or other online competition is planned. This is a solo game.

## 11. Existing portrait system

**Decision:** Keep the existing LibreSprite artwork and port the layered rendering, weighted part selection, and recoloring behavior to Flutter. Persist the appearance data and render/cache the completed portrait as a PNG.

## 12. League foundation

**Decision:** Start fresh. Create 20 fictional teams with names that evoke professional women's basketball without resembling real teams. Organize the league into Atlantic and Pacific conferences, with 10 teams each.

## 13. Earned identity system

**Decision:** Players can earn nicknames and special hair colors through awards and achievements, such as league MVP, scoring leader, and defensive MVP. The game suggests a nickname, and the coach may edit it. Example: Olivia “The Spectacle” Miles.

## 14. Game name

**Decision:** The game is named **Women's Basketball Manager**.

## 15. Coach statistics

**Decision:** Coaches carry a small stat block, deliberately much smaller than player ratings: Offense, Defense, Development, Motivation, and Management. Offense/Defense affect in-game tactical calls (Phase 3), Development affects player growth (Phase 2), Motivation affects morale/chemistry (Phase 2) and close-game resilience (Phase 3), and Management affects trade/draft shrewdness (Phase 2). Defined in Phase 1 alongside player identity, matching how player ratings are defined before their systems exist.

## 16. Attribute rating scale

**Decision:** Every coach and player numeric rating uses a shared 1-99 scale. 0 and 100 are deliberately excluded — a rating is never "nothing" or "perfect." Implemented once as `kMinRating`/`kMaxRating` in `lib/core/ratings/rating_scale.dart` so coach stats and (later) player ratings stay on the same scale without duplicating the bounds.

## 17. Player shooting ratings

**Decision:** Shooting splits into two ratings, not three: **Inside** (layups, close-range shots at the rim) and **Outside** (one combined rating spanning mid-range through three-point shooting). There is no separate Finishing rating — Inside scoring already covers what that was meant to capture, so it was dropped as redundant rather than kept alongside it.

Superseded/folded into the full attribute architecture in decision 19 below — Inside/Outside survive as `interiorOffense`/`perimeterOffense` (renamed from "Scoring" per decision 20), now two of twelve stats rather than a standalone pair.

## 18. Roster star-rating system

**Decision:** Replaces a salary cap with a structural star-rating system — see `star_system.md` for the full design. 1-99 OVR maps to stars: 5-star (90-99), 4-star (78-89), 3-star and below (1-77). A 12-player active roster is governed by two nested caps rather than fixed recipes: at most 2 five-star players, and at most 6 players total who are four-star-or-better (five-star and four-star combined) — a team with zero five-stars can still carry up to six four-stars, since the four-star cap doesn't shrink when no five-star slots are used. Three-star-and-below players are uncapped and fill the rest of the 12. Star limits lock only at the regular-season buzzer (mid-season moves are exempt), and rosters must be legal again before free agency and the draft — a mid-season breakout can temporarily overshoot the cap.

## 19. Player attribute architecture

**Decision:** Twelve stored ratings — four physical (speed, agility, strength, stamina), four offensive (ball control, passing, interior offense, perimeter offense), four defensive/playmaking (perimeter defense, interior defense, disruption, blocking) — plus potential as a separate ceiling rating, all on the shared 1-99 scale. Full detail in `star_system.md`. In-game action success uses one universal formula: Physical Stat + Skill/Defensive Stat, applied per action at simulation time (Phase 3) rather than pre-computed on the player. Rebounding is not a stored or derived rating at all — it's just that formula applied twice: an offensive rebound checks strength + interior offense, a defensive rebound checks strength + interior defense.

## 20. Interior/Perimeter Offense naming

**Decision:** Renamed Inside/Outside "Scoring" to **Interior Offense** and **Perimeter Offense**, mirroring Interior/Perimeter Defense so the sheet reads as one symmetric system. "Scoring" was too narrow — Interior Offense also covers offensive rebounding instinct and boxing out, Perimeter Offense also covers shot fakes and footwork, not just makes/misses.

## 21. Player personality: traits, not hidden stats

**Decision:** Dropped the hidden-numeric-stat idea (Ego, Motivation, Coachability, Composure, etc.) entirely in favor of a **Traits** system: a catalog of at least a dozen discrete, visible, earnable traits a coach can scout for — not numbers they can't see. Rationale: in a management game, an unmanageable hidden number is a worse fit than a visible, scoutable trait; Leadership was the case that made this obvious — it's clearly something a coach should be able to hunt for on the trade market, not something invisible.

The "Potential" hidden-stat idea survives as two traits instead, **High Potential** and **Low Potential** — they don't replace the numeric `potential` rating in `PlayerRatings`, they modify how easy or hard the player is to train (interacts with Coach's `development` stat once Phase 2's development system exists). The naming collision with the existing `potential` rating is deliberate context, not a conflict: the rating is the ceiling, the trait is how easily a player closes the gap to it.

Traits and the refined nickname-award criteria both live in Phase 1.5 (`FLUTTER_APP_PLAN.md`), alongside each other as the "earned identity" system. The full 27-trait catalog lives in `traits.md`, grouped into work ethic/development, durability, leadership/chemistry, mental/clutch, loyalty/career, crowd, and a skill-specific "badge" set (rebounding, stealing, blocking split into front-court and back-court, three-pointers, layups, free throws) that work like NBA 2K badges rather than archetypes — narrow earnable bonuses on one check, not a description of overall playing style. Off-court/media-flavored ideas (e.g. Media Magnet) are deliberately excluded from the active catalog and parked in `traits.md`'s shelved section instead.

## 22. Roster status: Active / Developmental / Reserve-Inactive, loosely WNBA-mirrored

**Decision:** Three roster statuses (`RosterStatus`, roster feature) — loosely mirroring the real 2026 WNBA CBA, not replicating it, since this game has no salary cap for the real CBA's finer mechanics (hardship-exception timing, external-vs-WNBA-injury distinctions) to hook into. See `wnba_rules_reference.md` for the source research.

- **Active** — subject to the star-tier caps (decision 18). No enforced minimum size, only the 12-player ceiling: a team can choose to run fewer than 12, and the game won't block it or model the real CBA's 72-hour fill-the-roster deadline. That's a self-inflicted disadvantage, not an illegal state.
- **Developmental** — at most 2 players, exempt from the star-tier caps, restricted to players with at most 3 years of service (`yearsOfService`, a new `Player` field — tracked independently of `age`, since an international player can debut as a rookie well into their late twenties).
- **Reserve/Inactive** — a single catch-all for "under contract, not currently active, for any reason." Deliberately not split into injury/suspension/hardship sub-categories the way the real CBA is, since none of those distinctions currently affect anything in this game.

Also captured: an **Assistant GM advice** feature idea (a staff member who proactively surfaces roster suggestions, e.g. "player X would fill our open roster spot") — parked for Phase 4 alongside the other staff/front-office deliverables, not designed yet.

## 23. Seeded player generation

**Decision:** `generatePlayer` (player feature) takes a seeded `Random` and a position, and returns a fully-formed `Player` — name and hometown drawn from small invented pools (`player_generator_data.dart`; not real athlete names), age 20-34 with `yearsOfService` derived from a separately-rolled debut age (19-28, so an international rookie debuting late is a natural outcome, not a special case), and ratings built from a quality center plus per-stat jitter plus a per-position bias table (e.g. centers skew strength/interior up and speed/perimeter down) reflecting standard basketball archetypes. `potential` gets its own wider, upward-skewed roll so even a weak roster can hide a gem.

`generateStartingRoster` (roster feature) composes this into a new expansion franchise's 12-player active roster: a fixed position plan (2 PG, 3 SG, 3 SF, 2 PF, 2 C) guarantees full position coverage, and the quality center/spread (48 ± 14, positions bias further within that) is chosen so the roster average is *structurally* incapable of reaching the four-star threshold (78) even in the extreme case — verified by both the arithmetic and a 50-seed test loop, not just spot-checked. Different seeds produce different rosters by construction, satisfying the plan's "meaningfully different weak starting roster" requirement.

## 24. The player is the GM, not the coach

**Decision:** At onboarding, the human player creates their General Manager persona (`Franchise.gmName`), not a coach. The coach (`Coach`) is a hired NPC staff member — generated (`generateCoach`, coach feature), not player-named, the same way a player roster spot is generated rather than hand-typed. This was a correction to the original onboarding flow, which had the player naming "the coach" as if that were their own persona.

This actually resolves a latent inconsistency rather than creating new scope: `CoachStats` (decision 15) was always framed as *coach* competencies (in-game tactical calls, player development, morale management) — those are head-coach duties in real sports organizations, not GM duties, so treating the coach as a distinct hire the GM manages (and later, per the Assistant-GM idea in decision 22, receives advice about) was the correct model all along.

Name pools moved from the player feature to `core/generation/name_pools.dart` since coach generation needed them too. `simulationSeed + 1` is used for roster generation (coach generation uses `simulationSeed` directly) so the two generated-random streams don't correlate just because they share a starting seed.

Downstream implication for Phase 1.5 portraits, not resolved now: the GM presumably wants their own customizable persona/portrait distinct from the coach's `isCoach` portrait — worth revisiting when portraits are actually built.

## 25. Starting lineup: one player per position, GM-editable

**Decision:** `StartingLineup` (roster feature) is a `Map<Position, String playerId>` — one starter per position. A player fills a slot if it's their primary position or one of their secondary positions (`StartingLineup.isEligible`), so a combo guard can start at PG or SG.

Default at franchise creation: `StartingLineup.bestAvailable` picks the highest-`overall` eligible active player per position, processed in `Position.values` order with each pick excluded from later positions so the default itself can never double-book a player. Not a global optimum, just a reasonable starting point — the GM is expected to adjust it.

`evaluateLineupLegality` checks three independent rules (all positions filled, no player in two slots, every starter active and eligible for their slot) and exposes which one failed, not just pass/fail — same pattern as `RosterLegality`. `LineupEditorScreen` uses this to disable Save with a specific message rather than silently blocking or allowing an inconsistent state; it doesn't try to prevent an illegal pick at the dropdown level (e.g. a combo player selected for two slots), since making every position's dropdown reactive to every other position's current pick is more complexity than the problem needs when a save-time check with a clear message does the same job.

This closes Phase 1's exit criteria: create, inspect, edit a legal lineup, and resume are all now real, working, tested end-to-end.

Prerequisite fix along the way: `Player` had no stable identifier before this. Lineup slots need to keep pointing at the same player across a save/reload, where object identity and list position are both lost — so `Player.id` was added (generated from the same seeded `Random` stream as everything else, practically unique within one franchise's roster, not globally).

## 26. Onboarding/dashboard polish; three items deferred to Phase 2

**Decision:** From a round of hands-on feedback on the onboarding form, Dashboard, and League screen:

Done immediately:
- Club Name field was ambiguous (mascot only, e.g. "Dirtbags," or full name, e.g. "Des Moines Dirtbags"?) — added helper text with a concrete example, since `Team.name` has always meant the full branded name.
- The conference picker now shows that conference's existing 10 teams underneath it (`TeamRow`, extracted as a shared widget so `LeagueScreen` and onboarding don't duplicate the row layout).
- `Conference.name` (the raw lowercase enum identifier, e.g. `atlantic`) was leaking into the UI on the Dashboard summary and `TeamRosterScreen`. Added `Conference.label` ("Atlantic Conference") and fixed both call sites; `.name` stays reserved for JSON (de)serialization, where the raw identifier is exactly what's wanted.

Deferred to Phase 2, noted in `FLUTTER_APP_PLAN.md`, because each depends on a system that doesn't exist yet:
- **Team replacement selection**: a checkbox to choose which existing team in the conference your club replaces (defaulting to random) needs a real `League` runtime concept to persist "which 19 AI teams remain" against — doesn't exist yet (`kInitialLeagueTeams` is static reference data, not consumed as live league state anywhere).
- **Fresh-league team quality**: target ~75-80 average overall once the other 19 teams get real generated rosters — they don't have rosters at all today, only identity (name/colors/city). This is genuinely new scope (full-league roster generation), not a tweak to what exists.
- **League screen as a standings page**: win-loss records, and between seasons, last season's record plus the champion (🏆) — needs season simulation and playoffs to produce any of that data. Building the standings layout now would have nothing real to display.

## 27. Traits and archetypes implemented on `Player`

**Decision:** Built out the domain models for both catalogs referenced in decision 21 and `archetypes.md`, kicking off Phase 1.5.

`Trait` (`lib/features/player/domain/trait.dart`) is an enum covering the full catalog in `traits.md` — 29 traits, not 27 as decision 21 says; that count was stale even before this decision and both docs now say so. `kOppositeTraitPairs`/`oppositeOf` encode mutually-exclusive pairs (the doc-labeled ones like Clutch/Choker, plus a few conceptually-opposite pairs the doc doesn't explicitly flag, like Iron Man/Injury Prone) — `Player`'s constructor asserts a player never carries both sides. `kGenerationEligibleTraits` is everything except Homegrown, which requires having been drafted by this franchise and so can't apply to a freshly generated roster. `generateTraits` (`lib/features/player/generation/trait_generator.dart`) rolls a random count from 0-3 distinct, non-opposite, eligible traits per player — a judgment call, not specified anywhere: real management sims (FM, 2K) treat traits as an occasional distinguishing feature, not something every player is loaded up with, so most generated players end up with one or two, some with none.

`Archetype` (`lib/features/player/domain/archetype.dart`) is an enum of the 16 unique names from `archetypes.md`'s table, plus `kArchetypesByPosition` reproducing that table exactly — names that repeat across positions (3&D, Versatile Forward, etc.) are one shared enum value valid at multiple positions, not separate values. `generateArchetype` picks uniformly at random among the options valid for a player's position; `archetypes.md` explicitly left the rating-threshold question as future work, so building speculative thresholds now would have been guessing past what was actually decided. `Player.archetype` is required and asserted valid for `primaryPosition`.

Both wire into `generatePlayer` (rolled once per generated player, after everything else), `player_json.dart` (archetype by name, traits as a name list), and `TeamRosterScreen` (archetype label shown in the roster row's subtitle; traits have no dedicated UI yet — deferred, see `FLUTTER_APP_PLAN.md`).

Mechanical prerequisite: `Position` moved out of `player.dart` into its own file (`position.dart`, re-exported from `player.dart` so no call site needed to change its import) to break a circular import — `archetype.dart` needs `Position` for its position map, and `player.dart` needs `Archetype` for its validation assert.

## 28. Portrait rendering engine, wired end-to-end

**Decision:** Built the full `portraits.md` pipeline: `PortraitManifest`/`PortraitWeights` (parsed from the real `manifest.json`/`weights.json`, now declared as Flutter assets in `pubspec.yaml` alongside the 151 PNGs that were already there), `PortraitAppearance` (source data, not the rendered image), `generatePortraitAppearance` (seeded, deterministic), a pixel-level recoloring port of `render.js` (`pixel_recolor.dart` -- magenta-placeholder hair/eyebrow/facial recolor, exact-match base-sprite skin/shadow/jersey recolor, nose-shadow recolor, all pure functions over raw RGBA buffers so they're unit-testable without any image decoding), a `dart:ui` compositor (`portrait_renderer.dart`) producing PNG bytes in the doc's exact layer order, and `FilePortraitCache` (mirrors `FileSaveRepository`) for the rendered PNGs.

Two deliberate departures from a literal reading of `weights.json`:
- **No neon/special hair colors at generation time.** `weights.json`'s `neon_hair` table (1.25% each for limegreen/neonpink/skyblue/fuchsia) is never rolled by `generatePortraitAppearance` -- `portraits.md`'s own text says "select special hair colors only from unlocked cosmetic rules," which reads as an explicit instruction for *this* game, not just documentation of the original prototype's behavior. The weight table stays in the file for a future achievement/unlock system to draw on.
- **Coach-only fields (shoulders/hats/glasses) are never auto-generated.** `weights.json` has no weight tables for them at all -- they're pure customization, editable later via the (not-yet-built) portrait editor, matching `portraits.md`'s "Random generation" section, which never mentions them.

**Wiring, without breaking determinism for existing callers:** `Player.appearance` and `Coach.appearance` are both nullable, defaulting to `null`. `generatePlayer`/`generateCoach`/`generateStartingRoster`/`createExpansionFranchise` all take an *optional* `PortraitWeights?` parameter -- omitting it (every existing test, since `PortraitWeights` can only really be obtained by loading `weights.json` as a Flutter asset) skips portrait generation entirely and burns zero random numbers, so no existing generation-order/determinism test needed to change. The real onboarding flow (`OnboardingScreen._createFranchise`) awaits `portraitWeightsProvider` (a `FutureProvider` loading the bundled JSON) before calling `createExpansionFranchise`, so real franchises do get real portraits.

**Cache-key design:** `portraitCacheKey` folds in both the appearance's `version` and the jersey color, because `portraits.md` explicitly calls out jersey color as an invalidation trigger (a trade should never keep showing the old team's collar color) -- version alone wasn't enough.

**Display:** `PortraitImage` (a `ConsumerStatefulWidget`, not stateless -- a plain `FutureBuilder` fed an inline `resolvePortraitPng(...)` call recomputes on every rebuild, which would flicker constantly in a scrolling roster list) shows the cached/rendered PNG or an accessible fallback (person icon + `Semantics` label) when `appearance` is `null` or still resolving. Wired into `TeamRosterScreen`'s roster rows now; a portrait editor and coach-detail display are still open.

Testing note worth keeping in mind for future async-image work: `testWidgets` bodies can't just `await` a `Future` chain built on real asset decoding (`rootBundle.load`, `ui.instantiateImageCodec`) -- it hangs, because that work needs the real event loop that fake-async pumping doesn't drive. `tester.runAsync(() => Future.delayed(...))`, called a few times in a loop, is the fix (see `portrait_image_test.dart`); plain `test()` functions (not `testWidgets()`) don't have this problem at all, which is why `portrait_renderer_test.dart`/`portrait_service_test.dart` could just `await` directly.
