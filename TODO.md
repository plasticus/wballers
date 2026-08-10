# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Stats

1. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Player cards / roster display

2. **Real star-quality indicator on the roster page** — off `star_system.md`'s OVR thresholds (90+ = 5★, 78-89 = 4★ are spelled out there; the 1-3★ bands below that still need a judgment call before this can be built).

## Open questions

3. **Do coach attributes actually do anything yet?** — need to confirm whether coach stats (Motivation, Offense, etc.) currently have any real gameplay effect, or are still cosmetic/unused.

## Main Menu / save slots

4. **App boot should bounce to the Main Menu if the last-used save fails to load** — right now, opening the app tries to load whatever slot was last active, and if that load fails there's no automatic recovery; it should just kick out to `MainMenuScreen` instead (which, as of 2026-08-10, has a real Delete button for exactly this "save won't load" case).
5. ~~**Main Menu visual polish**~~ — **Done (2026-08-10).** Slot cards rebuilt as tight `Card`s (own compact button style, info condensed onto fewer rows) instead of `AppCard`'s generous padding; logo now sized off `MediaQuery` width (75%) instead of a flat 96px literal. Still needs a writeup in `0A_Completed.md` and a commit.

## Training

6. **Individual-coaching player picker needs reformatting again — too wide** — the pulldown for assigning a player to one of the 3 individual coaching slots is cutting off important info. Priority order for what must stay visible: Position, jersey #, OVR, POT, age -- name is the *least* important of the bunch and should be what gets truncated/cut first if something has to give (a direct GM example: with a long surname like "Richardson" or "Henderson," POT is getting pushed off-screen entirely). Also, the dropdown itself should just use the full width of the screen -- no real reason to constrain it narrower than 100%.
7. **Individual coaches shouldn't have their own independent Development rating at all** — a real design decision, not just a display tweak: "I hate the idea of those 3 being different from one another. They should all simply be an extension of the head coach's capabilities." Currently (`training_coach_generator.dart`) each of the 3 individual coaches gets its own independently-rolled `developmentRating`, separate from the head coach's own `CoachStats.development` -- that's what needs to go. Two things to change together: (1) the generation/mechanics side (`training_coach_generator.dart`, and wherever `training_advancer.dart`'s `_effectiveFocusAndCoach` currently reads an individually-assigned coach's own rating) should have all 3 slots use the head coach's own development capability instead of rolling something separate; (2) the Training screen's per-card "DEV NN" readout should come off entirely, since there'd no longer be a distinct number worth showing per coach ("that's engine stuff the player doesn't need to see").

## Blocked / waiting on the GM

8. **League team City/State/Team Name data is still a mess** — the 40-team league pool's city/state/name combinations need real cleanup. GM is going to acquire better data for this before it can be fixed properly. Not started.
