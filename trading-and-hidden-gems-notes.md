# Trading & Hidden Gems — locked design (2026-08-19)

Both grew out of the same question -- what should the coach stat
Management actually *do*? -- worked through by hand, one real scenario
at a time, until the numbers held up across several deliberately
different trade shapes. This doc is the distilled spec; the reasoning
trail (why 290/150/50, why the swing curve, why 11 as a floor) lives in
this session's chat history if it's ever worth re-deriving.

## Hidden Gems (built, `lib/features/draft/generation/hidden_gem.dart`)

A coach's Management occasionally finds real value in a draft pick
nobody else saw.

- **Currency:** skill points (`PlayerRatings.skillPoints`, the raw sum
  of the 12 core ratings `overall` rounds down from) -- not a blunt OVR
  bump. 12 skill points = 1 `overall` point.
- **Floor:** Management ≤ 30 → **0 bonus, every round.** A below-average
  coach doesn't find anything a blind draft wouldn't have. (30 is a
  clean round number close to the real generation floor, 29.)
- **Ceiling:** Management = 79 (the real generation ceiling —
  `coach_generator.dart`: qualityCenter 50 + Program Builder's +14 bias
  + max +15 jitter; no archetype/roll combination can exceed it) →
  **Round 1 +12, Round 2 +24, Round 3 +36** skill points (1/2/3
  OVR-equivalent). Finding a steal in round 3 is a bigger feat than
  round 1, where the league already broadly agrees who's good.
- **Shape:** linear between floor and ceiling, chosen over a concave
  alternative that was also on the table — "if you went concave, you
  only get a couple bonuses at specific times," a direct GM call
  preferring a steadier payoff.
- Applies to **every team's** draft picks, GM's own and all 19 AI
  teams, each off their own head coach's real Management — not just
  the GM's.
- Distribution across the drafted player's 12 fields is a fixed,
  deterministic round-robin (no `Random` needed) — simple on purpose,
  matching `draft_advancer.dart`'s existing "nothing here rolls
  anything" posture for every other pick-resolution step.

## Trading — the value math (built, `lib/features/trade/domain/trade_value.dart`)

This is **only** the objective math: given a set of assets on each
side of a proposed trade, is it something a given coach's Management
could actually pull off? It says nothing about *which* teams offer
*what* to whom — that's the Trade Board (below).

- **Currency:** skill points, same as Hidden Gems. Two players who
  display the same rounded OVR aren't necessarily equal value — a 900
  and a 905 both read "75," but they aren't the same player.
- **Assets:** players, valued at their current skill points, and draft
  picks from the current season's class, valued on a **flat, hand-tuned
  ladder** — deliberately *not* the real average generated outcome by
  round (~889/803/754 skill points), which turned out to be nearly
  useless for trading: too close together to ever offset a real
  star-level gap via a round-swap, and too large to add to an ordinary
  trade without swamping it (a full pick reads as almost a whole extra
  player).

  | Round | Trade value (skill points) |
  |---|---|
  | 1 | **290** |
  | 2 | **150** |
  | 3 | **50** |

  Round 1→2 is a bigger jump (140) than round 2→3 (100) on purpose —
  matches the real generated data's own shape (a 7.2-OVR gap vs. 4.0).

- **Validity:** `|offeredValue − requestedValue| ≤ tradeSwing(management)`,
  symmetric, using whichever coach is *extending* the offer's own
  Management stat. Any mix of players/picks is legal on either side —
  1-for-1, 2-for-1, 2-for-2, 2-for-3, whatever a real offer needs.
- **Swing formula:** `tradeSwing(management) = max(11, round(management² / 104))`.
  - **The floor (11) is exact, not a guess:** 11 is the maximum
    possible skill-points gap between two players who display the
    *same* rounded OVR (a band is 12 points wide). Guarantees even the
    worst coach the game can generate (Management 29, the real floor)
    can always make a same-OVR trade.
  - **Concave, not linear** — chosen after comparing both against 3
    reference points (Management 30/50/70) across 3 different trade
    shapes: linear was too generous at the average (50), letting an
    ordinary coach do things that should've needed real skill.
  - Reference values: Management 30/50/70/79(ceiling) → swing
    **11/24/47/60**.
- **Age/potential:** deliberately **not** a separate adjustment layered
  onto player value. A win-now trade (give up a young high-potential
  piece for a proven star) or a rebuild trade (sell a declining star for
  a dev-slot prospect) get resolved by **adding a draft pick** to
  balance the ledger instead — the pick is the premium a team pays (or
  the discount a seller accepts) for prioritizing timeline over pure
  value. The math never pretends these trades are "fair" — it just
  sizes how big a deliberate mismatch a given coach's Management can get
  away with.

### The 3 canonical cases (regression-tested, `trade_value_test.dart`)

Worked by hand until all 3 held at once — good reference examples for
any future tuning pass.

**Case A — plain 1:1, no picks.** 900 vs. 924 (gap 24): works at
Management 50 (swing 24, right at the edge), fails at 30 (swing 11).

**Case B — a star-for-phenom pick-swap.** All-Star (1080) for Phenom
(960), gap 120. Either a 1st-for-2nd swap (Δ140) or a 2nd-for-3rd swap
(Δ100) closes it to within ±20 — clears at Management 50, fails at 30.
Bump the star up further (1140) and even the best swap needs Management
~65+ to clear.

**Case C — a 2-for-2 sweetened with a pick.** Team A: 900 + 950 = 1850.
Team B: 900 + 900 = 1800, +50 (an R3 pick) = 1850 — **exactly even**,
clears at any Management level. A wider natural gap (1870 vs. 1760)
doesn't close with either pick alone at Management 50, but the better
one (R2) clears at 70.

## Trade Board (built, `lib/features/trade/`, screen in
`market/presentation/player_market_screen.dart`'s "Trade Board" tab)

The screen and offer-generation logic that actually *produces* trade
offers for the value math above to validate.

- **Accept/decline only** — no player-initiated trades. A real,
  deliberate scope cut ("a whole can of worms I'm not sure I want to
  touch"). `CurrentFranchiseNotifier.acceptTradeOffer`/`declineTradeOffer`.
  One 2026-08-21 exception in spirit, not mechanism: `kConsolidationOfferSlotIndex`
  is a 6th slot the generator always tries as a 2-for-1 (2 of the GM's
  own weakest active players for 1 upgrade), shaped around what a GM
  with deep bench depth would want — still AI-generated and
  accept/decline only underneath, the GM never actually proposes it.
- **6 offers visible at a time** (`kTradeOfferCount`), from any teams
  around the league, generated once per Trade Board tab visit
  (`trade_offer_generator.dart`'s `generateTradeOffers`) rather than
  regenerated on every rebuild — accepting one only removes it (plus any
  other offer touching the same players) from that fixed set instead of
  re-deriving all 6 from the just-changed roster, which would otherwise
  silently reshuffle every other slot too (2026-08-21, a direct GM spec:
  confirm-before-accept and a completion popup, then no instant refill
  until the next real game-day advance — "you get more deals next
  week"). Accepting the 2-for-1 slot specifically can also push the AI
  side over `kActiveRosterSize`; `acceptTradeOffer` auto-waives their own
  weakest pre-existing player back to free agency to make room, the same
  crash `targetMinutesForOrderedRoster`'s hard cap would otherwise risk.
- **Trade window** (`trade_window.dart`): opens at the very start of a
  season (preseason included) and runs through **the end of Week
  `kTradeDeadlineWeek` (6)** — locked for real 2026-08-19, a direct GM
  call ("definitively mark the Trade Deadline as End of Week 6"),
  replacing the earlier flat ~15-turn game-day-count fudge. Checked
  against whichever game day is genuinely up next
  (`gameDaysInOrder`/`SeasonProgress.nextGameDayIndex`), not a raw turn
  count — weeks don't all carry the same number of game days (byes, Cup
  rounds, All-Star week), so only a real week comparison lands exactly
  on "closed the instant the GM starts a Week 7 game." Shows up as a
  real calendar entry in 2 places, not just an enforced cutoff:
  `TeamCalendarScreen` (a `_MilestoneRow` sorted to the very end of Week
  6, right before Week 7 begins) and the Dashboard's "Upcoming Games"
  list (spliced in at its real chronological position, only while the
  window's still open and the boundary is one of the next few games).
- **5-slot mix — simplified from the original plan.** The original
  intent (2 contention-window / 2 situational / 1 hairbrained,
  targeted generation) needed a real per-team strategy signal that was
  never designed in detail. What shipped instead: every offer is built
  the same way (closest-value combo + a balancing pick, gated by the
  offering coach's own Management swing), and `TradeOfferCharacter`
  (value/winNow/rebuilding/aggressive) is derived *after the fact*
  from what the offer's own numbers produced — an honest description,
  not a targeted simulation. Revisit if the flat mix ever feels wrong
  in play.
- **Trade Block (2026-08-19, added mid-design):** the GM can flag
  exactly **one** of their own active-roster players as available
  (`Franchise.tradeBlockPlayerId`, set from the Trade Board tab's
  "Set"/"Change"/"Clear" controls). Whenever one's set, the Trade
  Board *tries* to make **3 of the 5** offers involve that specific
  player (`kTradeBlockTargetedOfferCount`) — the other 2 stay general.
  "Tries," not guaranteed: a slot with no legal match for that player
  just falls back to a general offer.
- **Roster-need-driven offer generation** (the 3rd flavor idea from
  earlier in the conversation, using real per-position depth-chart
  gaps) was considered and set aside — "not super into" it, per a
  direct GM call. Parked, not dead.
- **Real draft-pick ownership, multi-season (built 2026-08-19, then
  extended same day, `trade/domain/pick_ownership.dart`).** A traded pick
  genuinely changes who's on the clock at that draft — not just a
  value-only IOU. `PickTradeAsset` carries `originalTeamAbbreviation`
  (whose *natal* pick it is, not necessarily who currently holds it — a
  pick can trade hands more than once) and `draftSeason` (an absolute
  `Franchise.season` number — the season the draft *stocks*).
  `Franchise.pickOwnershipOverrides` accumulates real ownership changes
  over the trade window (`acceptTradeOffer`, via
  `transferFuturePickOwnership`); `season_transition_advancer.dart`'s
  `beginNextSeason` slices off just the season *now* starting its draft
  into the fresh `DraftInProgress`'s own frozen snapshot
  (`DraftInProgress.onTheClock` resolves each slot's natal team through
  it, unchanged from the single-season build) — every other season's
  entries carry forward untouched.
  - **How many seasons out (2026-08-19, direct GM call): "next + one
    more" — `kTradeablePickHorizonSeasons = 2`.** A franchise's very
    first season has no "own draft" to trade at all (that season's
    roster and draft class are both already set at creation), so the
    earliest tradeable draft is always the one that stocks the *next*
    season (`tradeableDraftSeasons`). The Trade Board's offer generator
    (`picksOwnedBy`) only ever offers a pick a team genuinely still
    holds within that 2-season horizon; `player_market_screen.dart`
    labels each pick "(next draft)" or "(the draft after)"
    (`pickHorizonLabel`) rather than a raw season number, so a GM never
    has to do the season-number math themselves.

## AI-to-AI off-season trades (built 2026-08-19, `trade/generation/ai_offseason_trade_advancer.dart`)

A second, entirely separate trade system from the GM-facing Trade Board
above — a direct GM ask: "make a few AI trades happen in the off-season...
only 1:1 trades, trying to balance their rosters closer to... at least 2
players from every position... none of them would make more than one
trade... Max gap of 36." No offer is ever shown to anyone; these trades
just happen, resolved once per off-season inside
`simulatePostseasonAndPersist` (same "one lump" posture
`resolveCoachFreeAgency`/`enforceAiRosterLegality` already have), after
roster-legality enforcement and before tenure advances.

- **1:1 only**, players for players — no picks, no multi-player packages.
- **Target: 2 active players per position** (`kAiOffseasonTradeTargetPerPosition`).
  A team with more than 2 at a position has surplus there; fewer than 2 is
  a need. For each shuffled pair of AI teams, looks for a genuinely
  complementary mismatch — team A has real surplus at a position team B
  needs, *and* team B has real surplus at a (necessarily different)
  position team A needs — and, if found, each side offers its *weakest*
  player at its own surplus position (a team fixing a depth problem gives
  up its extra depth piece, not a starter).
- **Flat gap cap of 36** (`kAiOffseasonTradeMaxGap`), `PlayerRatings.skillPoints`
  currency — deliberately *not* gated by either team's own coach
  Management (unlike the GM-facing board's `tradeSwing`); see
  `coaching-stats-notes.md`'s Management section for why the two trade
  systems use different rules on purpose.
- **Each team trades at most once per off-season** — once matched, both
  teams are excluded from the rest of that pass.
- Deliberately light-touch, not an optimizer: takes the *first*
  complementary position match found (fixed `Position.values` order), not
  the best possible one, and never retries a pair with a different
  position/player combination if the first attempt doesn't clear the gap.
  "Probably none of them would make more than one trade" per the GM's own
  framing — most off-seasons, most teams, nothing happens at all.
- Only `RosterStatus.active` players are ever counted, offered, or
  received — developmental/reserve rosters are untouched, matching every
  other season-end AI system's own active-only scope.
