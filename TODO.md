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

5. **Individual-coaching pulldown still doesn't look right — wants a design Lab, not a direct fix this time** — the GM has a sketch of one option (a 2-line dropdown item: "C #42 Henderson" / "  68 OVR, 93 POT, 21y", collapsing to a 1-line "SF #13 Henderson" once selected) but is explicitly asking for a Lab page showing **5 different formatting options** to compare, not just this one implemented directly — "everything in caps like that looks like crap, too... I maybe just don't know how to fix it." Build a throwaway/reachable Lab screen presenting 5 real candidate layouts side by side (this codebase already has precedent for a "Lab" page -- `player_card_lab_screen.dart`) before picking one to actually ship in `training_screen.dart`.
6. **A real "how training works" explainer, brief on-screen + detailed off-screen** — direct GM quote: "I am writing the program, and even I don't know how it works." Two deliverables: (1) a brief, plain-language summary directly on `TrainingScreen`, below the Save Training Plan button; (2) a much more detailed standalone HTML doc (self-contained, matches this project's established HTML-artifact convention for design docs) with **3 concrete worked examples**, specifically covering: how team focus affects a player's growth odds and which ratings actually move; how potential/gap-to-potential drives the ceiling; how age factors in (the confirmed growth/decline curve); how the 3 individual coaches factor in (focus override, individual-attention multiplier) now that they no longer carry their own rating; how minutes played gates growth; and the difference between a broad focus category vs. a specific-rating hyper-focus, including what picking one category/skill over another actually does mechanically.
7. **New "Season To Date Report" on the Training page** — an ongoing, always-current report (not a one-off like `TrainingReportScreen`) listing every roster player's total stat-field growth so far this season, sorted most-improved to least; within a player's own row, their individual field deltas sorted descending too (e.g. "Agility +7, Passing +5, Disruption +3" in that order). Strong reuse opportunity: `SeasonRecapScreen`'s "Player Development" section (2026-08-10) already does almost exactly this via `aggregateSeasonGrowth`/`PlayerGrowthCard` -- the only real difference is this needs to be readable *mid-season*, not just after the season ends, so it can't include the season-end aging lump the way the recap screen's version does.
8. **Are AI teams training at all?** — confirmed no: `training_advancer.dart`'s own doc comment already says so ("the other 19 AI teams' rosters don't age or improve through this system yet"), tracked as known follow-up work in `0B_Planned.md`. The GM flagged this as a real fairness concern on replay (every AI team's roster staying static all season while only the GM's own team develops/declines) -- promoting it here to make sure it actually gets picked up, not just left as a background note.

## Awards

9. **End-of-season awards need a real design pass** — no list exists yet of what awards this game actually gives out (MVP, Most Improved, etc.). Wants a full brainstormed catalog (everything from MVP down) written up as an HTML doc, matching this project's established HTML-artifact convention for open design questions, before any of it gets built.

## Roadmap

10. **A real path to Season 2** — the GM wants an explicit checklist of everything that has to exist before a "Begin Season 2" button could work at all (multi-season `Franchise` concept, aging the whole league forward including AI rosters, the draft actually wiring into a real flow, an end-of-season ceremony, etc.) -- see the chat answer this was first raised in for a first-pass list; needs to become a real tracked plan, not just a conversational answer.
