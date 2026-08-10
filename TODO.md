# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Stats

1. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Player cards / roster display

2. **Real star-quality indicator on the roster page** — off `star_system.md`'s OVR thresholds (90+ = 5★, 78-89 = 4★ are spelled out there; the 1-3★ bands below that still need a judgment call before this can be built).

## Open questions

3. **Do coach attributes actually do anything yet?** — need to confirm whether coach stats (Motivation, Offense, etc.) currently have any real gameplay effect, or are still cosmetic/unused.

## Blocked / waiting on the GM

4. **League team pool's City/State/Team Name data is still a mess** — the 40-team league pool's city/state/name combinations need real cleanup. GM is going to acquire better data for this before it can be fixed properly. Not started.

## Training

5. **New "Season To Date Report" on the Training page** — an ongoing, always-current report (not a one-off like `TrainingReportScreen`) listing every roster player's total stat-field growth so far this season, sorted most-improved to least; within a player's own row, their individual field deltas sorted descending too (e.g. "Agility +7, Passing +5, Disruption +3" in that order). Strong reuse opportunity: `SeasonRecapScreen`'s "Player Development" section (2026-08-10) already does almost exactly this via `aggregateSeasonGrowth`/`PlayerGrowthCard` -- the only real difference is this needs to be readable *mid-season*, not just after the season ends, so it can't include the season-end aging lump the way the recap screen's version does.

## Awards

6. **End-of-season awards need a real design pass** — no list exists yet of what awards this game actually gives out (MVP, Most Improved, etc.). Wants a full brainstormed catalog (everything from MVP down) written up as an HTML doc, matching this project's established HTML-artifact convention for open design questions, before any of it gets built.

## Roadmap

7. **A real path to Season 2** — the GM wants an explicit checklist of everything that has to exist before a "Begin Season 2" button could work at all (multi-season `Franchise` concept, aging the whole league forward including AI rosters, the draft actually wiring into a real flow, an end-of-season ceremony, etc.) -- see the chat answer this was first raised in for a first-pass list; needs to become a real tracked plan, not just a conversational answer.
