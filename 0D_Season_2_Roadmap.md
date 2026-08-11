# Path to Season 2

A tracked checklist for everything that has to exist before a "Begin Season 2"
button on the Dashboard could actually work — first raised as a direct GM ask
for "an explicit checklist... not just a conversational answer" (TODO.md's
former Roadmap item). Supersedes the original chat answer this was raised in.

Every item below was checked against the real codebase (not guessed) as of
2026-08-10. Check items off here as they land, and add a line to
`0A_Completed.md` the same way every other feature does — this file tracks
*what's left*, same spirit as `TODO.md`, just scoped to one big multi-part
feature instead of a punch list of small ones.

## Foundation

These have to exist first — nearly everything else on this list either reads
a season number or reuses a seed offset that doesn't account for one yet.

- [ ] **A real season counter on `Franchise`.** There is no season/year field
      today at all — `resolveSeasonEndAging`'s own doc comment says so
      directly: "there's no multi-season flow yet... 'the off-season' is, for
      now, just that one moment a season wraps up, not an actual calendar
      phase." Everything below assumes this exists.
- [ ] **Fold the season number into every generation seed.** Every generator
      (`generateSeasonSchedule`, `generateDraftOrder`, the free-agent pool,
      AI-team training, season-end aging, ...) seeds its `Random` off
      `franchise.simulationSeed + someFixedOffsetConstant` — a flat constant,
      the same one every time. Left as-is, Season 2's schedule, draft class,
      and free-agent pool would generate *identically* to Season 1's, just
      re-rolled from the same starting point. Needs the season number folded
      into every one of these seeds (`simulationSeed + offset + season * N`,
      or similar) before a second season would look like a second season at
      all.
- [ ] **A real "season transition" entry point.** `simulatePostseasonAndPersist`
      already resolves the postseason, veteran aging, and AI-team training
      the moment a season completes — but nothing currently follows that with
      "and now start the next one." Something has to own that hand-off.

## Aging & roster churn

- [ ] **Player age increments.** Confirmed by search: nothing anywhere
      increments `Player.age`. Every player is frozen at whatever age they
      were generated at, forever.
- [ ] **`yearsOfService` increments.** Same gap, separate field — nothing
      increments it either, so "Rookie" would never stop being true for a
      player who's actually completed a season.
- [ ] **AI roster aging/decline.** `resolveSeasonEndAging` (the veteran
      decline lump) only ever runs against `franchise.roster` — the GM's own
      team. The 19 AI teams get `resolveAiTeamSeasonTraining`'s growth (this
      session's work) but never decline. AI veterans currently only ever get
      better, never worse. Needs the same treatment AI training just got:
      replay the real decline pass across every AI roster too.
- [ ] **Retirement.** No concept exists at all — nothing removes a player
      from the league for any reason. Without it, every roster (AI and the
      GM's own) only ever accumulates players season over season, with no
      natural attrition. See the open question below on what rule should
      drive it.
- [ ] **Roster legality enforcement at the season boundary.** `star_system.md`
      calls for exactly this ("The Off-Season Reconciliation: Rosters must be
      legal before free agency and the draft"), but `roster_legality.dart`
      today is advisory-only — `RosterLegality` exposes raw counts for a
      screen to display a warning with, nothing actually blocks an illegal
      roster from carrying over. Needs a real gate at the transition point,
      not just a display warning.

## Player pool refresh

- [ ] **Free agent pool refresh.** `Franchise.freeAgents` is generated once,
      at franchise creation, and never regenerated — `player_market_screen.dart`
      's own doc comment confirms Free Agents is the one real (signable) tab
      on that screen, but the pool behind it is static for the life of the
      save. A season transition needs a fresh pool: retirees and any
      roster-legality cuts feeding back in, plus a newly-generated batch.
- [ ] **A new draft class each season.** `draft_generator.dart`'s prospect
      generation is already proven out — it's what powers both the Market
      screen's Draft tab preview and Season Recap's projected pick — but
      nothing calls it to persist a real, new class at a season boundary
      today; every "class" shown anywhere in the app right now is a
      regenerate-fresh-every-render preview, not saved data.

## The draft, for real

- [ ] **A real draft-day flow.** `PlayerMarketScreen`'s Draft tab is
      explicitly preview-only today — its own on-screen banner says so, and
      says why: "there is no trade system and no draft-day flow wired to
      `Franchise` yet." `generateDraftOrder` and prospect generation both
      already exist and work; nothing lets a GM actually spend a pick and
      land a player on their roster. This is the single biggest missing
      piece on this whole list — everything above it exists to make this
      possible, not the other way around.
- [ ] **AI teams making their own picks.** A real draft needs the other 19
      teams to draft too, not just sit out while the GM picks — otherwise
      the AI player pool never refreshes and every rookie ends up on the
      GM's own roster.

## Presentation

- [ ] **A real end-of-season ceremony.** `SeasonRecapScreen` already says so
      explicitly — its "What's Next" section is a deliberate placeholder,
      not a finished feature (2026-08-05 GM call to defer it). Once awards
      exist (see the separate Awards Catalog design doc) and a real
      season-transition flow exists, this is where they'd actually get
      presented together: champion, awards, nicknames/hair-colors unlocked,
      in one batch moment.
- [ ] **The "Begin Season 2" button itself.** The actual Dashboard entry
      point a GM taps once everything above is in place — should probably
      only appear once the ceremony above has been seen, not the instant the
      postseason ends.

## Open questions for GM review

1. **Contracts/salary cap** — `star_system.md` deliberately replaces a
   salary cap with the star-tier system. Worth confirming Season 2 doesn't
   secretly need a contracts system too (multi-year deals, cap sheets), or
   whether roster-legality enforcement alone is the entire off-season gate,
   with no money involved at all.
2. **Retirement rule** — age-based cutoff, age combined with declining
   ratings, or a random chance weighted by both? This needs its own small
   design pass, not just "someone eventually leaves the league."
3. **Does anything else quietly assume "one season only"?** `trainingReports`
   and Mail history both just append forever today — worth an audit for
   whether either needs a per-season reset/archive once seasons actually
   repeat, or whether unbounded growth across a multi-season save is fine to
   just leave as-is.
4. **Free agent pool composition** — should it include players waived by AI
   teams during roster-legality cleanup, or purely fresh-generated each
   season?
5. **How many rounds/picks feel right for a real draft?** `kDraftRounds = 3`
   already exists in `draft_generator.dart` (real WNBA draft length) — worth
   confirming that's still the right number once picks actually matter, not
   just when they're flavor text.

## Suggested build order

1. Foundation — season counter, seed scoping, the transition entry point.
2. Aging & churn — age/experience increments, AI decline, the legality gate.
3. Player pool refresh — free agents, a real new draft class.
4. The real draft flow, GM and AI both.
5. Ceremony, awards, and the "Begin Season 2" button itself.

Roughly in dependency order — each stage's items either read data the
previous stage produces, or would be actively wrong to ship without it (a
real draft with no roster-legality gate first could hand a team an illegal
roster with no way to fix it, for instance).
