# Roster legality — status and open scoping

Everything scattered across `TODO.md`, `0A_Completed.md`,
`0D_Season_2_Roadmap.md`, `star_system.md`, and `season2roadmap.md` about
roster-legality enforcement, gathered in one place (2026-08-19, a direct
GM ask: "I can't look at them at the same time").

## The rule itself (`star_system.md`)

The star-tier system is the permanent salary-cap substitute — no money,
no contracts, ever. Current bands (revised 2026-08-10, replacing an
earlier 5-tier proposal):

* **4-Star (90+ OVR):** at most **2** per roster.
* **3-Star (80–89 OVR):** combined with 4-Star, at most **6** per roster.
* **2-Star (70–79 OVR), 1-Star (60–69), no stars (<60):** uncapped.

Star limits lock only at the regular season's final buzzer — a mid-season
violation (a hot rookie call-up, a trade-deadline upgrade) is allowed, on
purpose, to let a real playoff push happen even if it temporarily breaks
the caps.

## What's actually built (AI teams only)

`roster_legality_advancer.dart`'s `enforceAiRosterLegality`, shipped
2026-08-11 (`0D_Season_2_Roadmap.md`): at the season boundary, waives the
lowest-overall excess player(s) off any AI roster that's still over cap
after that season's training/aging, straight into `Franchise.freeAgents`
— currently the only real free-agent pool the game has.

**Deliberately AI-only.** The GM's own roster is explicitly
**advisory-only** — no auto-waive, and (confirmed while gathering this
doc) no GM-facing check screen either. Quoting the roadmap doc directly:

> Deliberately AI-only — the GM's own roster stays advisory-only, since
> auto-waiving the GM's own player without a say is a bigger, separate
> feature (the fuller Assistant-GM-mail/grace-period/AI-trade-offer flow
> `star_system.md` already describes but which isn't built).

Wiring order matters here: this gate runs *after* training/aging (so it
judges post-growth rosters) and *after* the retirement-persuasion flow
(so it doesn't waive a player who was actually just retiring anyway).

Also relevant: roster **statuses** themselves already exist and are
enforced independently of the star caps (`0A_Completed.md`) — Active
(where the star caps apply), Developmental (at most 2 active
developmental slots, ≤3 years of service, exempt from star caps),
Reserve/Inactive (unconstrained catch-all).

## What's designed but NOT built at all — the fuller flow

`star_system.md` and `season2roadmap.md` (2026-08-10 GM answers session)
both describe a real GM-facing enforcement flow that's never been coded:

1. Season starts → engine checks **every** roster, GM's included, against
   the caps.
2. GM gets a real **Assistant GM mail warning** for any violation of
   their own, naming a fix-by date.
3. That date is a **fixed grace period after the draft concludes** (draft
   picks can never break the cap on their own — a rookie never generates
   above 2-star — so the grace period exists purely to let trades/cuts
   land). *Suggested default: 2 weeks of in-game time post-draft — never
   confirmed, still an open number.*
4. After the cutoff, a still-illegal roster gets enforced for real (a
   forced cut of the newest violating player, most likely — exact
   mechanic explicitly still TBD).

**AI trade-offer behavior**, also designed, also unbuilt: an AI team over
cap doesn't just sit on the violation or waive immediately — it first
picks one excess player at random and offers a trade **to the human GM**;
only if that doesn't resolve it does the player hit waivers into free
agency. Flagged in `season2roadmap.md` as real scope of its own: this
needs a whole AI trade-offer system that doesn't exist yet at all, not
just a smaller add-on.

## The still-open ask (`TODO.md` item 1, moved here 2026-08-19)

A direct GM ask (2026-08-12), for a real recap screen/mail item once a
season wraps, that (among other things) surfaces **roster legality**:
active/developmental/reserve counts against whatever roster-size rules
the game enforces, flagged if something's out of bounds going into the
new season. (The other 3 facets of that same off-season-report ask —
who declined/improved, who's retiring, who wants traded — aren't roster-
legality and stay on `TODO.md` itself, not moved here.)

## What actually needs deciding

Two genuinely different sizes of feature are tangled together above —
worth deciding which one you're actually asking for before scoping either:

1. **Small: a GM-facing legality *screen/report*, informational only.**
   Just surfacing what `enforceAiRosterLegality` already computes for AI
   teams, but for your own roster too — "you're over cap on 4-stars,
   here's who" — with no enforcement behavior at all. This is what
   `TODO.md`'s off-season-report ask actually describes, and it's the
   smaller lift: the star-cap check logic already exists, this would
   mostly be a real read of it plus a screen.
2. **Big: the full designed flow above** — Assistant GM mail warning,
   real fix-by date, a real grace period, forced enforcement after it
   expires, and (a genuine prerequisite, not optional) a whole AI
   trade-offer system before any of that can work as designed. This is
   what `star_system.md`/`season2roadmap.md` actually spec out, and it's
   substantially more work — an entire trade system is a hard blocker on
   step 4 working as designed.
