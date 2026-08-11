# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Stats

1. **Rebounds-per-game leaderboard looks statistically off** — a point guard was ranked #3 league-wide, which should be rare (bigs and SFs should generally dominate that stat). Unconfirmed/one anomalous case so far — flagged to watch, not a confirmed bug yet.

## Open questions

2. **Do coach attributes actually do anything yet?** — confirmed 2026-08-10: only Development is wired to anything real (a genuine multiplier on weekly training growth, `training_advancer.dart`). Offense/Defense/Motivation/Management are all display-only on the coach-hiring screen, each blocked on a system that doesn't exist yet (in-game tactics, morale/chemistry, trades). Not worth building piecemeal -- revisit whichever one pairs naturally with whatever system it's blocked on gets built (Motivation could ride along with Coach free agency's morale angle, e.g.).

## Blocked / waiting on the GM

3. **League team pool's City/State/Team Name data is still a mess** — the 40-team league pool's city/state/name combinations need real cleanup. GM is going to acquire better data for this before it can be fixed properly. Not started.

## Awards & All-Star (see SeasonAwardsAnswers.md)

4. **Coach free agency in the off-season** — Coach of the Year needs every AI team to have a real generated coach first. Pair with an off-season sim where the bottom ~5 teams by record fire their coach (newly hired coaches get a 2-season grace period), plus the actual hiring flow for the resulting vacancies.
