# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

2026-08-20 cleanup pass: items 4, 5, 8 confirmed genuinely done (5 and 8 moved to `0A_Completed.md` with real writeups; 4 needed no new code -- the 5 analysts already each read a real, distinct number, confirmed against a direct GM check-in, nothing to build). Item 9 turned out to already be fully built too -- `PlayedGame.boxScoreByPlayerId` is a real, persisted per-game box score, `PlayedGameDetailScreen` already renders it, and it's already tappable straight from the Schedule screen; `SeasonProgress.playedGames` (and every box score in it) already resets to empty at `copyWithNewSeason`, so nothing carries over season to season either. Items 2, 3, 6, and 7 were built for real this pass (see `0A_Completed.md`). Item 1 moved to the MAYBE pile, below (an open question, not a build order).

2026-08-20, later the same day: the Player Health section's Injuries item was built for real, its own forward-looking spec note (the post-game-report prominence ask) included -- see `0A_Completed.md`. That was the last item on this list outside the MAYBE pile; nothing outstanding remains here right now.

2026-08-21: fresh playtest pass, folded in from `8-21notes.md` (all 10 items), then built out the same day -- see `0A_Completed.md`. Notes on how a few of them actually landed, since the note text alone doesn't capture it:
- Item 4 (real draft preview) turned into a real architecture change -- `Franchise.upcomingDraftClass`, rolled a full season ahead and promoted at transition, not just a wording fix.
- Item 7 (offers dropping to 4 after a decline) was investigated but never reproduced as a real bug -- `resolvedTradeOfferIds` already resets every real game-day advance; whatever the GM saw was most likely the board just sitting on the same still-open day, or a slot that naturally didn't fill that day. Folded into item 5's fix anyway, since pinning the board (rather than regenerating it) makes the "why did this shrink" story legible either way.
- Item 8 (scouting report) was flagged as possibly stale against yesterday's rebuild before removing it -- GM confirmed still wanted it gone.
- Item 9 (2:1 trades) was scoped down from a full GM-proposal system to a 6th always-attempted AI-generated slot, a direct GM call once the real size of the full version came up.

Nothing outstanding remains here right now.

## MAYBE pile — parked, not committed to

1. **An off-season report covering who's asking to be traded.** A direct GM ask (2026-08-12) originally had 3 facets: who declined/improved (already covered, the Season Recap's Player Development section), who's retiring (built 2026-08-20, League Retirements), and who's asking to be traded -- the one facet left. Needs a real trade-request mechanic that doesn't exist at all yet (not just the Trade Block preview). Moved here 2026-08-20, a direct GM call: "I'm not sure if I want to do that. I've kind of been dropping morale/chemistry stuff as we go" -- a trade-request system would lean on exactly that kind of player-sentiment modeling this game has been steering away from. Revisit only if that changes.
