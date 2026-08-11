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

- [x] **Free agent pool refresh.** Done 2026-08-11 --
      `season_transition_advancer.dart`'s `beginNextSeason` generates a
      fresh `generateFreeAgentPool` batch each season (seeded off the new
      season's own `seasonSeed` slice, folding season in the same way the
      Foundation stage's other recurring generators already do) and
      *appends* it to whatever's still unsigned, rather than replacing --
      any roster-legality waives from the season that just ended (Aging &
      roster churn stage) survive the transition instead of getting
      discarded before the GM ever sees them. Retirees still never appear
      here -- confirmed during Aging & roster churn, a retired player
      leaves the league entirely.
- [x] **A new draft class each season.** Done 2026-08-11 --
      `beginNextSeason` also calls `generateDraftClass` each season
      (`Franchise.draftClass`, a new persisted field -- fully *replaces*
      the previous season's class, unlike free agents, since last year's
      undrafted prospects don't stay draft-eligible into a new one). Fixed
      a real gap in the process: `generateDraftClass` never accepted
      `portraitWeights` at all before this (nothing persisted a class long
      enough for a missing face to matter) -- same class of bug
      `generateFreeAgentPool` once had, fixed the same way, now that a
      real class needs real faces.

## The draft, for real

- [x] **A real draft-day flow.** Done 2026-08-11 -- new `Franchise.draftInProgress`
      (`draft/domain/draft_in_progress.dart`): a fixed pick order (computed
      from the *old* season's final standings, `generateDraftOrder`, its
      own new `kRealDraftOrderSeedOffset` stream so it can never shift
      because some other screen's preview happened to roll differently)
      plus a growing `picks` list. `season_transition_advancer.dart`'s
      `beginNextSeason` sets it up alongside the fresh draft class;
      `draft/generation/draft_advancer.dart`'s `makeOwnPick`/`finalizeDraft`
      let the GM actually spend a pick and land every pick on a real
      roster, with a real jersey number. New `draft/presentation/draft_day_screen.dart`
      is the GM-facing screen -- reached from `SeasonRecapScreen`'s new
      "Begin Next Season" button (`current_franchise_provider.dart`'s
      `beginNextSeasonAndPersist`), the first real (if deliberately
      minimal, no ceremony yet) entry point into a new season at all.
- [x] **AI teams making their own picks.** Done 2026-08-11, same change --
      `draft_advancer.dart`'s `resolveAiPicksUntilOwnTurn` auto-resolves
      every other team's pick ("best player available," the exact
      ranking `simulateDraft`'s old whole-draft preview already used, now
      shared via public `draftProspectValue`) the instant it's not the
      GM's turn, so the AI player pool refreshes right alongside the GM's
      own roster, not just the GM's picks landing anywhere.

## Presentation

- [ ] **A real end-of-season ceremony.** Still a deliberate placeholder --
      award winners, nicknames earned, neon hair unlocked, all presented
      together in one batch moment, once awards exist (see the separate
      Awards Catalog design doc). **Partially superseded 2026-08-11**: the
      season-transition flow this item was waiting on now exists for
      real (see "The draft, for real" above) -- `SeasonRecapScreen`'s
      "Begin Next Season" button already calls it, deliberately without
      any ceremony trapping around it yet. This item is now specifically
      about the presentation layer alone: replacing that plain button
      with the real ceremony once awards exist, not building the
      transition itself again.
- [x] **The "Begin Season 2" button itself.** Done 2026-08-11, in minimal
      form -- `SeasonRecapScreen`'s "Begin Next Season" button, reachable
      the instant the postseason ends (not gated behind the ceremony
      above, since that doesn't exist yet either). The polished version
      this item originally described (only appearing once a real
      ceremony has been seen) is still open, folded into the ceremony
      item above rather than tracked twice.

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
5. ~~**How many rounds/picks feel right for a real draft?**~~ — answered
   2026-08-11: **3 rounds**, confirming `kDraftRounds` (`draft_generator.dart`)
   as-is, real WNBA length. No code change needed — already the right
   number.

## Suggested build order

1. ~~Foundation~~ — done. Season counter, seed scoping, the transition
   entry point.
2. ~~Aging & churn~~ — done. Age/experience increments, AI decline, the
   legality gate.
3. ~~Player pool refresh~~ — done. Free agents, a real new draft class.
4. ~~The real draft flow, GM and AI both~~ — done.
5. Ceremony, awards, and the *polished* "Begin Season 2" button — still
   open. The plain, functional version of the button already shipped
   alongside stage 4 (see "Presentation" above); what's left here is
   specifically the ceremony wrapped around it.

Roughly in dependency order — each stage's items either read data the
previous stage produces, or would be actively wrong to ship without it (a
real draft with no roster-legality gate first could hand a team an illegal
roster with no way to fix it, for instance).
