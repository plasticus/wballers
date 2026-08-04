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
