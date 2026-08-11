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

- [x] **A real season counter on `Franchise`.** Done 2026-08-10 --
      `Franchise.season`, a zero-based counter (same convention
      `PlayerAchievementRecord.season` already used), persisted and
      defaulting to 0 for every existing save.
- [x] **Fold the season number into every generation seed.** Done 2026-08-10
      -- new `Franchise.seasonSeed` getter (`simulationSeed + season *
      kSeasonSeedSpan`) replaces `simulationSeed` at every seed derivation
      that fires once *per season or more* (game-day/postseason/training
      advancement, season-end aging, AI-team training, the schedule itself,
      the draft-order preview). Once-ever franchise-creation generators
      (coach, starting roster, league draw + AI rosters, training coaches)
      deliberately still use plain `simulationSeed` -- they never run again
      regardless of season, and `league_screen.dart`'s own re-derivation of
      the original draw specifically needs to *not* shift. `kSeasonSeedSpan`
      = 10,000, comfortably wider than any offset's own internal variation.
      The free-agent pool's seed offset is unchanged for now -- it has no
      second call site to fold a season into yet; that's "Player pool
      refresh"'s job below.
- [x] **A real "season transition" entry point.** Done 2026-08-10 --
      `beginNextSeason` (`season_transition_advancer.dart`): increments
      `season`, generates a fresh schedule off the new `seasonSeed`, and
      resets `SeasonProgress`/training history/Skills Competition history
      for the new season. Deliberately **Foundation-scoped only** -- no
      aging, no retirement, no roster-legality gate, no free-agent refresh,
      no real draft, no ceremony, and (on purpose) no Dashboard button
      calling it yet. Wiring a real button before the stages below exist
      would let a GM start a new season with an illegal, unaged, stale
      roster -- worse than not offering it at all. See the function's own
      doc comment for the full list of what's deliberately still missing.

## Aging & roster churn

- [x] **Player age increments.** Done 2026-08-11 -- `Player.copyWithSeasonAdvanced`
      increments both `age` and `yearsOfService` by one; applied league-wide
      (GM's own roster + all 19 AI rosters, every `RosterStatus`) by
      `season_tenure_advancer.dart`'s `advancePlayerTenure`, called from
      `simulatePostseasonAndPersist` last of all the season-end resolutions
      -- everything else computes its result against the age a player
      played the season *at*, so incrementing first would shift every one
      of those onto the wrong age band a year early.
- [x] **`yearsOfService` increments.** Done 2026-08-11, same change as above
      -- both fields always move together at a season boundary.
- [x] **AI roster aging/decline.** Done 2026-08-11 -- `resolveAiTeamSeasonEndAging`
      (`training_advancer.dart`) mirrors `resolveSeasonEndAging`'s exact
      per-player decline math (`_declinedPlayer`, factored out so both
      share it) across every AI roster, same call site and idempotency
      guard as the GM's own pass and `resolveAiTeamSeasonTraining`.
- [x] **Retirement.** Done 2026-08-11. GM's rule (multiple triggers, not
      one): an unsigned free agent for a full season retires; losing 10+
      overall from peak retires; hitting age 38 means a player wants to
      retire; age 34+ plus winning a championship means a player considers
      it; for the GM's own roster, the coach can attempt to convince a
      retirement-eligible player to play one more year (a skill check).
      New `Player.peakOverall`/`effectivePeakOverall` (refreshed every
      season alongside the age/experience increment) plus
      `retirement_advancer.dart`'s `resolveAiTeamRetirements` (AI teams --
      mandatory-age and peak-decline apply outright, the championship
      trigger rolls, `kChampionshipRetirementChance`, a documented
      first-pass number) and `evaluateRetirementEligibility` (the GM's own
      roster -- same 2 deterministic triggers plus the un-rolled
      championship trigger, feeding `Franchise.pendingRetirements`). A real
      Mail item (`RetirementDecisionMailItem`,
      `player/presentation/retirement_decision_screen.dart`) lets the GM
      let a pending player retire or have the coach attempt to persuade
      them to stay (`attemptRetirementPersuasion`, a skill check off the
      coach's Motivation, `current_franchise_provider.dart`'s
      `resolvePendingRetirement`). Wired into `simulatePostseasonAndPersist`
      after training/aging (so it reads the season's *final* numbers) and
      before the roster-legality gate (so that gate sees who's actually
      still around). **Still open**: the full-season-unsigned-FA trigger
      needs free-agent tenure tracking the next stage (Player Pool Refresh)
      builds, so it's left out rather than half-built on missing data.
- [x] **Roster legality enforcement at the season boundary.** Done
      2026-08-11 -- `roster_legality_advancer.dart`'s `enforceAiRosterLegality`
      waives the lowest-overall excess player(s) off any AI roster that
      breaches the star-tier caps after that season's training/aging,
      straight into `Franchise.freeAgents` (a direct GM call: "the only
      real free-agent pool that exists today"). Deliberately AI-only --
      the GM's own roster stays advisory-only, since auto-waiving the GM's
      own player without a say is a bigger, separate feature (the fuller
      Assistant-GM-mail/grace-period/AI-trade-offer flow `star_system.md`
      already describes but which isn't built).

## Player pool refresh

- [ ] **Free agent pool refresh.** `Franchise.freeAgents` is generated once,
      at franchise creation, and never regenerated — `player_market_screen.dart`
      's own doc comment confirms Free Agents is the one real (signable) tab
      on that screen, but the pool behind it is static for the life of the
      save. A season transition needs a fresh pool: any roster-legality
      cuts (already feeding in for real, as of the Aging & roster churn
      stage) plus a newly-generated batch. **Not** retirees — a retired
      player leaves the league entirely, confirmed during that same stage,
      never back into free agency.
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

1. ~~**Contracts/salary cap**~~ — answered, again, definitively, 2026-08-11:
   **no contracts/money system, not in this game, not planned.** The
   star-tier system *is* the GM's intentional simplified substitute for a
   salary cap, full stop -- roster-legality enforcement alone is the
   entire off-season gate, no money involved at all. Not revisiting this
   one again unless the GM brings it up first.
2. ~~**Retirement rule**~~ — answered 2026-08-11, see Aging & roster churn
   above: multiple triggers (mandatory age, peak decline, a championship-
   team roll, plus a not-yet-buildable full-season-unsigned-FA trigger),
   not a single cutoff.
3. ~~**Does anything else quietly assume "one season only"?**~~ — checked
   2026-08-11: no action needed. `Franchise.copyWithNewSeason` (Foundation
   stage) already resets `trainingReports`/`skillsCompetitionResults` each
   season, and Mail derives its feed live from those lists rather than
   storing itself, so old mail naturally disappears with the season already.
   `readMailIds` grows by a few dozen entries a season, inconsequential.
4. ~~**Free agent pool composition**~~ — answered 2026-08-11 for the
   roster-legality-waive half: yes, into `Franchise.freeAgents` (see Aging
   & roster churn above). Still genuinely open for the *next* stage's own
   job (Player pool refresh) is whether a fresh season also mixes in
   retirees (no -- retirement removes a player from the league entirely,
   not into free agency) and what a purely-fresh-generated batch alongside
   the waived players should look like.
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
