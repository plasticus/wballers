# Season beat sheet — every scheduled/simulated event, in order

Reference doc only, not shown in-game (2026-08-20, a direct GM ask: "I'm
interested in printing out every beat of a team's season schedule...
whether or not the player sees that event/timing on their dashboard...
Part of being a GM is knowing the dates that things happen, so none of it
should be hidden"). Pulled straight from the real code that generates each
date/event -- `game_day.dart`'s `formatFictionalDate`,
`season_schedule_generator.dart`'s week constants, `trade_window.dart`,
`all_star_generator.dart`, `postseason_generator.dart` -- not guessed or
approximated. Dates are the fictional in-game calendar (`formatFictionalDate`,
anchored at Week 1 Sunday = May 3, 2026 -- the year is arbitrary and never
shown to the GM; only month/day is).

Two real screens currently carry this information, and they're not the
same doc/list:

- **Team Calendar** (`team_calendar_screen.dart`, "Calendar" button on the
  Team page) -- *your* club's full season: every one of your own games
  (played and upcoming), byes with a reason when there is one, and every
  milestone below. The closest thing to this whole document, in-game.
- **Schedule** (`schedule_screen.dart`, the Schedule tab) -- game-by-game
  results/upcoming for your team by default, with a **Full League** toggle
  that lists every team's games league-wide, grouped by week. This is the
  "games even if my team isn't in it" view -- Team Calendar deliberately
  never shows those (it's a *your-club* calendar, not a league schedule).
- **Dashboard** — a compact **"Upcoming Games"** list, your next **3**
  unplayed games (`upcomingGamesFor`, `limit: 3`), with the Trade Deadline
  and All-Star Break spliced in as their own rows *only when either one
  falls within that next-3 window*. This is intentionally a glance, not
  the full picture -- Team Calendar is where the full picture lives.

Legend for the "Visible today" column: **Dashboard** (the 3-upcoming
splice), **Calendar** (Team Calendar screen), **Schedule** (Schedule tab,
Full League toggle for other teams' games), **Nowhere** (no screen shows
it at all today).

## The full order, one season

| # | Beat | Week | Fictional date | Visible today |
|---|------|------|-----------------|----------------|
| 1 | **Draft Day** — every AI pick resolves instantly, then your own turns as they come up | Not a calendar week -- fires the instant the previous postseason's Finals resolve and you tap "Begin Next Season" | No fixed date (see Gap 1, below) | Calendar (a generic "Draft -- Once the postseason wraps up" milestone, no real date). **Not on Dashboard at all.** |
| 2 | **Trade Window opens** — the instant the draft finalizes | Same moment as #1 | Same as #1 | **Nowhere.** Only the *close* (Trade Deadline) is shown anywhere. |
| 3 | **Preseason Game 1** | Week 0/1 | May 3, 2026 (Sun) | Dashboard, Calendar, Schedule |
| 4 | **Preseason Game 2** | Week 0/1 | May 7, 2026 (Thu) | Dashboard, Calendar, Schedule |
| 5 | **Regular Season tips off** | Week 2 | May 10, 2026 (Sun) | Dashboard, Calendar, Schedule (the game itself shows; there's no separate "regular season starts" milestone anywhere, but it's the obvious first non-preseason game) |
| 6 | **Continental Cup Round 1** | Week 4 | May 28, 2026 (Thu) | Dashboard, Calendar, Schedule (every team plays Round 1 -- no true byes yet) |
| 7 | **Continental Cup Round 2** | Week 6 | Jun 11, 2026 (Thu) | Dashboard, Calendar, Schedule (survivors only -- Calendar shows a Bye + elimination note for everyone else) |
| 8 | **Trade Deadline** — window closes the instant Week 7 begins | End of Week 6 | Jun 11, 2026 (closes at the Jun 14 boundary) | Dashboard (spliced in when upcoming), Calendar (its own milestone row) |
| 9 | **Continental Cup Round 3 (Quarterfinals)** | Week 8 | Jun 25, 2026 (Thu) | Dashboard, Calendar, Schedule (survivors only) |
| 10 | **Continental Cup Round 4 (Semifinals)** | Week 10 | Jul 9, 2026 (Thu) | Dashboard, Calendar, Schedule (survivors only) |
| 11 | **Continental Cup Final** | Week 12 | Jul 23, 2026 (Thu) | Dashboard, Calendar, Schedule (2 survivors only) |
| 12 | **Regular Season ends** | Week 18 | ~Sep 3, 2026 (your own last regular-season game day) | Calendar (its own milestone row). **Not spliced onto Dashboard** as a milestone -- your own last regular-season game just reads like any other game there. |
| 13 | **All-Star Skills Competition** (Full Press Frenzy, H-O-R-S-E, Defensive Skills Challenge + squad announcement) | Week 19 | Sep 6, 2026 (Sun) | Calendar, Schedule (a real game row, full detail). Dashboard shows a combined **"All-Star Break -- Week 19"** milestone, not this event by name specifically. |
| 14 | **All-Star Game** | Week 19 | Sep 10, 2026 (Thu) | Calendar, Schedule (a real game row). Same Dashboard "All-Star Break" milestone as #13 covers both. |
| 15 | **Postseason First Round** (best-of-3) | Week 20 | Sep 17, 2026 (Thu) onward | Dashboard/Calendar/Schedule *only once you're actually in it and games exist*; Calendar shows a "Postseason: First Round -- If your club qualifies" placeholder beforehand. Not spliced onto Dashboard ahead of time the way Trade Deadline/All-Star Break are (see Gap 2). |
| 16 | **Postseason Semifinals** (best-of-5) | Week 22 | Oct 1, 2026 (Thu) onward | Same as #15 |
| 17 | **Postseason Finals** (best-of-7) | Week 24 | Oct 15, 2026 (Thu) onward | Same as #15 |
| 18 | **Off-season resolves**: aging, training, coach growth/retirement/hiring, roster-legality enforcement (AI), AI off-season trades, League Retirements, your own pending-retirement decisions | Same moment the Finals conclude (week 24) -- one atomic pass, `simulatePostseasonAndPersist` | Same moment as #17, no separate date | **Nowhere as a date/milestone.** The *results* show up as real Mail (League Retirements, Retirement Decisions, Roster Legality) and on the Season Recap screen once you're there -- but nothing on Calendar/Dashboard ever says "this is when the off-season happens." |
| 19 | **Season Recap** (the "end-of-season report") becomes available | Same moment as #18 | Same as #17 | **Nowhere as a date.** It's a real screen (reachable from the Dashboard's trophy banner once a champion's been crowned), just never called out as a calendar beat anywhere. |
| 20 | **Next Draft** — tapping "Begin Next Season" on the Season Recap screen | Whenever you tap it (no forced timing) | Nominal next Sunday if you went immediately (Oct 18, 2026) -- but genuinely open-ended, this is a GM action, not a clock | Calendar shows next season's draft the same generic way as #1, once a new season's under way |

## Gaps found (nothing built here, just flagged per your "nothing hidden" goal)

1. **The Draft has no real date anywhere.** Every other milestone
   (`_MilestoneRow`) at least gets a week number; the Draft is the only
   one that's *also* missing a real `formatFictionalDate` -- structurally
   it can't have one today, since it fires the instant you tap "Begin Next
   Season" rather than being pinned to a `GameDay`. If you want a real
   date here, it'd need either (a) a nominal fixed date (e.g. "the Sunday
   after the Finals," which the table above already computes as Oct 18)
   that's cosmetic only and doesn't actually gate anything, or (b) leaving
   it exactly as-is ("once the postseason wraps up") since it's genuinely
   GM-paced, not calendar-paced.
2. **Trade Window opening is invisible.** Only the close (Trade Deadline)
   shows up anywhere. Since it opens the instant the draft finalizes --
   the same moment as Gap 1 -- it inherits the same "no fixed date" issue.
3. **Postseason rounds aren't spliced onto the Dashboard ahead of time**
   the way the Trade Deadline and All-Star Break are, even once you've
   clinched a spot -- the Dashboard only ever shows a real postseason game
   once one's actually been generated (each round's bracket/game count
   isn't known ahead of the previous round finishing). This one's a real
   structural limit, not just an oversight -- there's no "Round 1 starts
   Week 20" to splice in *for you specifically* the way there is for a
   date that's true regardless of results.
4. **Regular Season End (Week 18) isn't spliced onto the Dashboard** as a
   milestone, unlike the Trade Deadline/All-Star Break -- it's real on
   Calendar, invisible on Dashboard.
5. **The off-season's own resolution moment and the Season Recap's
   availability have no calendar presence at all**, on either screen --
   they just silently happen the instant the Finals conclude, and the
   *results* surface elsewhere (Mail, the Recap screen itself) with no
   "this is when" marker pointing back at them.

None of this is broken -- `upcomingGamesFor`/`isTradeWindowOpen`/
`isAllStarWeekUpcoming` are all real, live logic, not stubs. This is a
completeness gap, not a bug: several real beats (Draft, Trade Window open,
the off-season pass, Season Recap's availability) simply have no
representation on either screen today. Say the word if you want any of
Gaps 1-5 actually closed.
