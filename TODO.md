# To-Do

The GM's running punch list — playtest feedback and asks not yet built. Superseded `Aug7AfternoonNotes.txt` and `Aug9bugs.md`, which tracked the same kind of thing per-session and got replaced by this single ongoing list once their own outstanding items were folded in here. Finished items don't stay here — they move to `0A_Completed.md` with the real writeup and get deleted from this file, not marked done in place.

## Stats

1. **Tapping any player on the Stats page should open their detail page** — today it's deliberately not wired (`stats_screen.dart`'s own doc comment): `PlayerDetailScreen` only knows how to look a player up on the GM's own `Franchise.roster`, and most Stats-page entries (leaders, team rosters) are AI players. Needs a real "any player, any team" lookup path, not just the GM's own roster.

## Coaching

2. **Wire up the coach stats that still do nothing** — confirmed 2026-08-10: only Development affects anything real (`training_advancer.dart`'s growth multiplier). Offense/Defense are the buildable half: a real match-simulation modifier off the GM's own coach's stats, the same pattern `kHomeAdvantageBonus` already uses for home-court advantage (`possession_engine.dart`) -- a flat rating bump/penalty for the team, not a full Phase 3 tactics system. Motivation and Management are a bigger lift and stay blocked: they're tied to systems that don't exist anywhere in the codebase yet (morale/chemistry, trades), so those two ride along with whichever system lands first, same as the original note said.

## Awards & All-Star (see SeasonAwardsAnswers.md)

3. **Coach free agency in the off-season** — Coach of the Year needs every AI team to have a real generated coach first. Pair with an off-season sim where the bottom ~5 teams by record fire their coach (newly hired coaches get a 2-season grace period), plus the actual hiring flow for the resulting vacancies.
4. **All-Star reports should name the player's team** — the GM asked for it after playing through All-Star week: every player mention in `skills_competition_result_screen.dart`/`all_star_game_result_screen.dart` (honoree lists, event results, MVP banner) should show the 3-letter team abbreviation after the name, since All-Star squads mix players from every team in the conference and the name alone doesn't say who they normally play for.
