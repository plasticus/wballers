# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Player progression / aging

1. **Aging curve too punishing in-season** — smaller week-to-week veteran decay during the season, with more of the decline concentrated in the off-season instead.
2. **End-of-season report should show player development** — a per-player growth/decline summary for the season.

## Stats

3. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Player cards / roster display

4. **Real star-quality indicator on the roster page** — off `star_system.md`'s OVR thresholds (90+ = 5★, 78-89 = 4★ are spelled out there; the 1-3★ bands below that still need a judgment call before this can be built).

## Game engine

5. **Blowout rubber-banding via pace** — when a team is up by ~20+, have the leading team slow the game down (longer possessions) to protect the lead and reduce 40+ point blowouts. Explicitly *not* about weakening/nerfing the leading team's stats — pacing/clock management only.

## Open questions

6. **Do coach attributes actually do anything yet?** — need to confirm whether coach stats (Motivation, Offense, etc.) currently have any real gameplay effect, or are still cosmetic/unused.

## Blocked / waiting on the GM

7. **Player name pool** — same-surname collisions keep showing up on a single roster. GM dropped `~/Downloads/wnba_names_final_v3.csv` (2026-08-10): 1,350 names, `Country,Type,Name` columns -- USA has 250 given + 150 surname, 19 other countries (Australia, Belgium, Brazil, Canada, China, Czech Republic, Finland, France, Germany, Greece, Hungary, Italy, Mexico, Nigeria, Senegal, Serbia, Slovenia, Spain, Turkey) get ~25 given + ~25 surname each -- matches this game's existing international-hometown concept. One malformed row spotted on a first look (`Given,Shona` -- looks like a missing Country value shifted the columns) to flag before building against it. Not started -- discussing the actual design (how it replaces `core/generation/name_pools.dart`, whether it ties to `Player.college`/hometown-country, collision-avoidance approach) before implementing.

## Polish

8. **Real app icon** — replace the default Flutter icon with the WBL logo (`branding/wbl_logo_alpha.png` already in the repo).
