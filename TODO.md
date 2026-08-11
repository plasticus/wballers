# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Stats

1. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Player cards / roster display

2. **Real star-quality indicator on the roster page** — the tier bands themselves are now fully defined (`star_system.md`, `StarTier`: 4★ 90+, 3★ 80-89, 2★ 70-79, 1★ 60-69, no stars below 60), so the earlier "1-3★ bands need a judgment call" blocker is resolved. Still needs a display-format decision before this can be built: repeated glyphs (⭐⭐⭐⭐) vs. compact "N ⭐", and where it shows (roster row, player detail, or both) -- see `Aug10Questions.md` #19, not yet answered.

## Open questions

3. **Do coach attributes actually do anything yet?** — need to confirm whether coach stats (Motivation, Offense, etc.) currently have any real gameplay effect, or are still cosmetic/unused.

## Blocked / waiting on the GM

4. **League team pool's City/State/Team Name data is still a mess** — the 40-team league pool's city/state/name combinations need real cleanup. GM is going to acquire better data for this before it can be fixed properly. Not started.

## Awards & All-Star (see SeasonAwardsAnswers.md)

5. **Coach free agency in the off-season** — Coach of the Year needs every AI team to have a real generated coach first. Pair with an off-season sim where the bottom ~5 teams by record fire their coach (newly hired coaches get a 2-season grace period), plus the actual hiring flow for the resulting vacancies.
