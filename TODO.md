# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Team page / roster management

1. **Development/Inactive roster slots UI** — visible Development (2) and Inactive (2) slots on the Team page, with a way to move players in/out.
2. **Roster re-order dropdown** — sort the Team page roster by Position, OVR, Exp, Age, or Potential.
3. **Bench Order auto-fill button** — a button to have the Coach set the order (by OVR, win-now mode), with a brief note/info-link that developmental players' minutes are the GM's own call to make, not the coach's.

## Player progression / aging

4. **Aging curve too punishing in-season** — smaller week-to-week veteran decay during the season, with more of the decline concentrated in the off-season instead.
5. **End-of-season report should show player development** — a per-player growth/decline summary for the season.

## Stats

6. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Player cards / roster display

7. **Real star-quality indicator on the roster page** — off `star_system.md`'s OVR thresholds (90+ = 5★, 78-89 = 4★ are spelled out there; the 1-3★ bands below that still need a judgment call before this can be built).

## Game engine

8. **Blowout rubber-banding via pace** — when a team is up by ~20+, have the leading team slow the game down (longer possessions) to protect the lead and reduce 40+ point blowouts. Explicitly *not* about weakening/nerfing the leading team's stats — pacing/clock management only.

## Open questions

9. **Do coach attributes actually do anything yet?** — need to confirm whether coach stats (Motivation, Offense, etc.) currently have any real gameplay effect, or are still cosmetic/unused.

## Blocked / waiting on the GM

10. **Player name pool** — same-surname collisions keep showing up on a single roster. On hold: the GM is building a larger name pool to pull from, not ready yet.

## Polish

11. **Real app icon** — replace the default Flutter icon with the WBL logo (`branding/wbl_logo_alpha.png` already in the repo).
