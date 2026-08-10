# Aug 9 Bugs & Feedback

Playtest notes from Corey, captured 2026-08-09. Raw numbering preserved from the original list for reference.

## Bugs

- **[9] Training report mail badge / disappearing reports** — ✅ **Fixed 2026-08-09.** New training reports don't light up the mail icon unread badge. Worse: if a training report notification on the dashboard isn't clicked when it first appears, it seems to vanish — not visible in Mail or in the "all training reports" list afterward, and it's unclear whether the training even applied to the players. Reproduced pattern: report showed on dashboard, wasn't clicked, disappeared entirely; next report (clicked immediately) showed up fine in both places. Asst GM mail (start-of-season) badges correctly, so the mail-badge system itself is probably fine — this looks isolated to training notifications specifically. **Needs a full audit of the training report generation/notification/storage pipeline.**
  Root cause: training only ever resolved when the Dashboard's "Training Report Ready" card was tapped, and that card was only visible in a narrow mid-week window — playing past it without tapping meant the skipped week's report never got created at all, just silently folded into whichever week's report resolved next. Fixed by auto-resolving training every time a game day advances (see `0A_Completed.md`'s "Training report pipeline" entry for the full writeup); the Mail badge now updates immediately since it always reflects `Franchise.trainingReports`.
- **[5] Training reports arriving inconsistently** — ✅ **Fixed 2026-08-09**, same root cause and fix as #9. Weekly training reports should generate every week; instead they appeared on weeks 2, 6, 8, and 9 only during a played season. Every fully-completed week now gets its own report automatically, regardless of Dashboard visit timing.

## League Setup / Balance

- **[11] Team OVR spread too narrow / user team too weak** — ✅ **Fixed 2026-08-10.** Player's team OVR is 66 while every other team is 73–75, resulting in a blowout every game. Want a wider, more randomized spread of team quality at league creation (roughly 69–76 range). After signing the featured free agent (#17), the user's starting team should land around 69.
  Root cause: every AI team shared the exact same generation shape, so individual-player jitter mostly canceled out over a 12-player average (~72-76, barely 4 points wide). Separately, signing the Day-0 free agent was *lowering* the team average, not raising it, since only her potential had ever been shaped. AI teams now get a real per-team quality offset (spread verified ~69-76 empirically); the GM's own roster + free-agent signing now lands at 68-70, mean ~69.3.
- **[12] Team OVR calculation should be weighted by roster depth** — ✅ **Fixed 2026-08-10.** Currently likely a flat average of the whole roster. Proposed weighting so bench/deep players don't drag down or inflate the number as much:
  - Rank 1–6 (starters + first bench wave): 100% weight
  - Rank 5–8: 80% weight
  - Rank 9–12: 60% weight
  - Rank 13+: 0% weight (not really playing)
  
  (Note: ranges 5–8 and 1–6 overlap in the original note — needs a real tiering decision, e.g. 1–4 / 5–8 / 9–12 / 13+, before implementing.)
  Resolved the overlap as 1-6 / 7-8 / 9-12 / 13+ (non-overlapping). "Rank" is the roster's own list/bench order — the same rank `target_minutes.dart` already uses for actual playing time — not a re-sort by rating.
- **[15] Conference display order on team creation** — ✅ **Fixed 2026-08-09.** Team creation screen shows Atlantic on the left, Pacific on the right. Flip so Pacific is on the left (west-to-east / geographic left-to-right convention).

## Free Agents / Roster Management

- **[2] Free agent cards missing face + potential** — ✅ **Fixed 2026-08-09.** Free agent listings should show the player's portrait/face and their Potential rating — potential is a huge factor in deciding whether to sign someone, currently invisible.
  Root cause for the face: `generateFreeAgentPool` was the one player-generation call that never got `portraitWeights` threaded through to it, so every free agent's portrait was `null` (generic placeholder) by construction, not a rendering bug. Potential now shows as a "POT" chip alongside OFF/DEF/PHY on every Player Market card (Free Agents, Trade Block, and Draft all share the same row widget).
- **[17] Starting free agent should be a young international prospect** — ✅ **Fixed 2026-08-09.** The free agent offered at the very start of a new game/season should be age 23, tagged as an international rookie, so the user has some development runway.
  The planted Day-0 "decent" prospect (the one the Assistant GM mail points to) is now pinned to age 23, 0 years of service, and a hometown drawn from the pool's international cities specifically — no longer left to a random roll that could land domestic.
- **[20] No way to drop a player** — ✅ **Fixed 2026-08-09.** Need a "release/drop player" action so the user can free up a roster spot to sign a free agent.
  Reachable from Player Detail (roster row → "Drop from Roster" in the AppBar), with a confirm dialog. Per the follow-up ask, a dropped player lands back on the Free Agents pool (jersey number cleared) rather than disappearing — a real, allowed choice even if it drops you below 12 active, same as Day 0.
- **[22] Age missing from individual training pulldown** — ✅ **Fixed 2026-08-09.** The player-select dropdown for individual training should show each player's age (abbreviate as needed to keep the row compact).

## Player Progression / Aging

- **[6] Aging curve too punishing during the season** — Older players currently lose too much skill week-to-week during the active season. Prefer smaller in-season decay for veterans, with more of their decline concentrated in the off-season instead.
- **[13] End-of-season report should show player development** — Want a summary of how much each player improved (or declined) over the season in the end-of-season report.

## Player Cards / Player Detail Page

- **[7] Jersey number placement** — ✅ **Fixed 2026-08-09.** Currently bottom-right on player cards; try moving it to the upper-left.
- **[18] Player detail page is missing info** — ✅ **Fixed 2026-08-10.** Should show College (domestic players) or Country (international players) — one or the other depending on player origin. Should show a large/hero-sized version of the player's portrait. EXP is missing from the page entirely, which suggests other fields may be missing too — do a pass to make sure everything known about a player is actually displayed.
  Bigger than a display fix: no non-draft player had a college concept at all. Added a real `Player.college` field (`null` = international, by design), generated for every player now (not just draft prospects), and moved `College`/`kColleges` out of the draft feature into `player/domain` since it's a general player-origin fact. Header redesigned around a 128px hero portrait with everything else (EXP, handedness, secondary positions, hometown, College/Country, biography) laid out full-width below it, not squeezed beside the photo.
- **[19] Inconsistent star display on roster page** — ✅ **Partially fixed 2026-08-09.** Some players show a single star, which reads as a bug/inconsistency rather than an intentional 1-star rating. Should consistently reflect the full star rating, either as repeated star glyphs (⭐⭐⭐⭐⭐) or a compact "N ⭐" format (e.g. "5 ⭐") to save space.
  Diagnosed: it's not a quality rating at all — it's a "Starter" badge (`team_roster_screen.dart`, top-5-in-roster-order indicator), which rendered as a single gold star with no label, easy to mistake for a 1-star quality rating since there was nothing else on the page showing a real star-quality indicator to contrast it against. The confusing icon is fixed — the Starter badge is now a "STARTER" text chip, can't be misread as a rating. **Still open:** a real star-quality indicator off `star_system.md`'s OVR thresholds (90+ = 5★, 78–89 = 4★ are spelled out there; anything below 78 is one lumped "3-star & below" bucket in the design doc, so the bands for 1–3★ still need a judgment call before that can be built).

## Stats

- **[3] Stats pages need tighter side margins** — ✅ **Fixed 2026-08-09.** Left/right buffer/border on stat tables and pages is too wide; content looks cramped and lines are breaking. Reduce the horizontal padding across stats screens generally.
  Root cause: all 3 Stats tabs double-padded (their own `EdgeInsets.all(lg)` stacked on top of `AppShell`'s own, 48px total on each side). League and Mail checked for the same pattern and were already clean.
- **[8] Rebounds-per-game leaderboard looks statistically off** — A point guard is currently ranked #3 in the league in rebounds per game, which should be rare. Bigs (PF/C) and SF should generally dominate that stat. Might just be one anomalous case, but flag it as something to keep an eye on rather than a confirmed bug for now.

## Dashboard

- **[10] No visible date/week on dashboard** — ✅ **Fixed 2026-08-09.** Add the current in-game date and the corresponding Week number to the dashboard so it's clear where the user is in the season.

## Visual / Cosmetic

- **[1] League standings "your team" indicator** — ✅ **Fixed 2026-08-09.** Replace the "YOUR TEAM" text tag on the standings page with a background/row highlight color instead.
- **[4] Rename Chicago Windy → Chicago Gale** — ✅ **Fixed 2026-08-09.** Same team, same emoji, just the new name.
- **[14] More/brighter team color options** — ✅ **Fixed 2026-08-09.** Only 6 (dark) colors currently available for team creation. Add 6 more, brighter/semi-bold options — e.g. fuchsia, cobalt blue, lime green, teal, light blue, sunset orange.

## Game Engine

- **[21] Blowout rubber-banding via pace, not player nerfing** — When a team is up by ~20+, have the leading team slow the game down (longer possessions) to protect the lead and reduce 40+ point blowouts. Explicitly do **not** want to weaken/nerf the leading team's performance — this is about pacing/clock management only, not stat suppression.

## Open Question

- **[16] Do coach attributes actually do anything yet?** — Need to confirm whether coach stats (Motivation, Offense, etc.) currently have any gameplay effect, or if they're still cosmetic/unused.
