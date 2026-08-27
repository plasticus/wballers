# Trade Value Study Tool

A standalone local tool (not part of the Flutter app) for rating a batch of
generated trades and building up a real dataset of "does this feel fair?"
judgments, to compare against the game's own trade math.

## Run it

```
cd tools/trade_study
php -S localhost:8000
```

Then open http://localhost:8000/ in a browser.

To rate trades from another device on the same network (phone, laptop,
etc.), bind to all interfaces instead and use the host machine's LAN IP:

```
php -S 0.0.0.0:8000
```

Then open `http://<host-machine-LAN-IP>:8000/` from the other device
(e.g. `http://10.23.0.137:8000/` -- check with `ip -4 addr show` if
that IP has changed).

## How it works

- Every visit generates 6 trades (assuming a coach with 70 Management,
  matching the real `tradeSwing()` formula from
  `lib/features/trade/domain/trade_value.dart`). Reloading the page keeps
  the same batch; submitting the form rolls a brand new one, so you can
  run this as many times as you want.
- Every batch guarantees exactly one trade per real Trade Board toggle --
  **Anything**, **Gain Picks**, **Shed Picks**, **Offload Depth**,
  **Get Younger** (`tradeBoardIntentLabel()` in `trade_offer.dart`) --
  plus one **Going Big** trade, a study-only category that isn't a
  shipped toggle yet: a real package of draft picks and/or a young
  high-potential prospect, chasing one real 88+ overall star. Each
  trade is badged with its category so they're easy to tell apart at a
  glance. Gain Picks/Shed Picks both use a wider discount tolerance than
  ordinary trades (`EXTRA_PICK_TOLERANCE`, matching
  `kSellForPicksExtraTolerance`/`kPickSpendExtraTolerance` in the real
  game) -- expect those two to read as more one-sided than an ordinary
  trade; that's by design, not a bug to flag. Offload Depth/Get Younger
  stay on the ordinary swing tolerance, same as Anything; Going Big
  isn't discounted either.
- Rate each trade -5 (you win big) to +5 (they win big), or leave it on
  "skip" to leave it out. Add notes if you want to remember why.
- Submitting saves every non-skipped rating to `ratings.json` in this
  same folder -- permanent, appends across every run, never overwritten.
  That file is gitignored (it's your personal working data, not app code).
- "View Saved Data" shows every rating you've ever saved, plus a quick
  comparison: average rating for trades the engine's own math would
  actually allow ("within tolerance") vs. ones it wouldn't. If those
  numbers don't line up with your gut, that's a real signal the
  `tradeSwing()`/`kDraftPickTradeValue` numbers in the real game might
  need retuning.

## Name Your Price (Value Check mode)

A second, separate mode (2026-08-24) -- a direct reverse-elicitation test,
complementing the trade-rating mode above: instead of judging an already-
built trade, name a fair return for one real player, in your own words.
Link at the top of either page ("Name Your Price" / "View Saved Value
Checks").

- Every batch shows 6 player profiles: 3 are **pick anchors**, one per
  round, each shaped like what the real Dart draft generator's own pick
  10/11 of that specific round actually looks like on average
  (empirically measured -- 3000 simulated draft classes, sorted by
  `draftProspectValue()`, averaged at slots 10-11 within each round --
  not eyeballed, and not a round-wide average either). Badged "PICK N
  ANCHOR." The other 3 are ordinary roster-quality profiles for broader
  calibration.
- For the 3 ordinary profiles, type what you'd actually take (or give)
  to trade for her -- a pick, a player, a combo, whatever's real -- or
  tap a quick-fill button (`Nothing real` / `A 3rd` / `A 2nd` / `A 1st` /
  `Two 1sts` / `A similar player`) and edit from there.
- For the 3 pick anchors specifically, answer with an ordinary
  **player's** quality instead ("about as good as a 72 OVR/72 POT bench
  piece"), not another pick -- its own quick-fills reflect that
  (`Worth nothing much` / `A weak rotation player` / `A decent rotation
  player` / `A real starter` / `A similar player`). The first real round
  of these answered in pick currency ("a 2nd + a sweetener"), which
  can't actually settle what a 2nd is worth since that's the very thing
  being measured -- a real, caught mistake in the original framing, not
  a wasted round (the *ordinary*-profile answers from that same round
  were still the direct hit that shipped the 2026-08-24 no-upside-discount
  tightening).
  Leave any you're not sure about blank -- an empty answer isn't saved.
- Answers save permanently to `value_checks.json` (same gitignored,
  append-only posture as `ratings.json`). "View Saved Value Checks"
  shows every answer alongside what `playerTradeValue()` currently
  computes for that exact profile, so a real mismatch between your
  answer and the engine's own number is easy to spot.
- The 3 pick-anchor answers, framed this way, are the cleanest way to
  settle what `kDraftPickTradeValue` should actually be -- rating an
  already-built trade can only ever say "this feels wrong"; naming a
  real player's quality for the pick-anchor profile directly says what a
  real 1st/2nd/3rd should be worth.

## What's This Pick Worth (Pick Check mode)

A third mode (2026-08-24 evening) -- the flip side of Name Your Price's
pick-anchor question. That question asked "name a player worth this
pick," which turned out to be genuinely hard to answer freehand ("it's
hard for me, with my human brain, to just type out a player that's
worth a particular pick"). This one shows a pick (or a pick combo) and
asks you to pick the closest match from a small, **fixed** multiple-choice
ladder instead -- recognition instead of generation.

- Each batch draws 6 pick packages from a 14-combo pool
  (`PICK_CHECK_COMBO_POOL` -- every same-round stack 2/3 deep, every
  cross-round pair, a 3-pick kitchen sink), **prioritized by how little
  real data each combo already has** (2026-08-27, "reconfigure it so I
  just get those ones, and not random stuff") -- a combo with 0 saved
  answers always beats one with 5, so batches keep landing on real gaps
  instead of re-asking whatever's already well-covered.
- The multiple-choice ladder (`PICK_CHECK_COMPARISON_PROFILES`) is a
  small set of fixed player profiles -- decent rotation piece / quality
  starter / really good starter / near-star-or-real-riser / true star,
  each with a real OVR/POT/age shown -- plus "not much of anything
  real" and "more than any of these" for the tails. Fixed on purpose
  (unlike the jittered pick anchors) so every answer, across every
  batch you ever run, is directly comparable against the same
  yardstick. Trimmed 2026-08-27 from 8 rungs down to these 5 -- with 42
  real answers in hand, usage made the cut obvious (the 3 dropped rungs
  had 0-2 uses each vs. 6-11 for the ones that stayed). Retired rungs'
  labels still render correctly for old saved answers
  (`PICK_CHECK_RETIRED_LABELS`), they just can't be picked anymore.
- Pick the closest one; notes are free text for "in between X and Y,"
  "about 2 of these," or (especially useful when a big same-round stack
  hits the "more than any of these" ceiling) roughly how much more.
- Answers save to `pick_checks.json` (same gitignored, append-only
  posture as the other two data files). "View Saved Pick Checks" shows
  every answer next to the combo's current combined engine value.

## Rate 5 Even Trades

A fourth mode (2026-08-27, a direct GM ask after several rounds of
retuning constants in the abstract: "show me a page that shows me 5
trades that you think are pretty even, and I'll evaluate"). A
different kind of check than the other 3 -- instead of asking what a
player or pick is worth, it shows what `playerTradeValue()`/
`kDraftPickTradeValue` currently consider fair, and lets a real gut
check catch anything the abstract numbers missed.

- `generate_even_batch()` draws from the same 6 real-shape builders
  `generate_batch()` uses, but tries ~25 candidates per shape and keeps
  only the tightest one by *relative* gap (`|gap| / trade size`, so a
  trivial trade landing dead-on doesn't crowd out a big, meaningfully-
  balanced one) -- then returns the 5 tightest of those 6 overall.
- Rating and saving reuses "Rate Trades" mode's own UI and
  `ratings.json` entirely (same slider, same notes field) -- each row
  just carries an extra `even_check: true` flag. "View Saved Data"'s
  stat cards include a dedicated "Rate 5 Even Trades" average |rating|
  -- since these were hand-picked for a near-zero gap, a rating that
  drifts from 0 here means something different than everywhere else on
  the page: not "how lopsided does this read," but "how far off
  dead-even does the formula's own idea of fair actually feel."

## Notes

- The player generator here is a simplified standalone approximation
  (not the real Dart generator) -- realistic enough to judge a trade by
  eye, not a faithful port. `skillPoints`/`tradeSwing`/pick values/the
  full `playerTradeValue()` formula (potential upside, age-risk
  discount included) *are* the real formulas, hand-copied from
  `trade_value.dart`.
- If you ever change the real trade math, update the constants at the
  top of `index.php` to match -- there's no shared code between this and
  the Flutter app. (This file drifted out of sync with the 2026-08-23
  `kDraftPickTradeValue` re-tune for a while before being caught and
  fixed the same day -- worth double-checking after any future
  `trade_value.dart` change.)
