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
- For each, type what you'd actually take (or give) to trade for her --
  a pick, a player, a combo, whatever's real -- or tap a quick-fill
  button to start from a common answer (`Nothing real` / `A 3rd` / `A
  2nd` / `A 1st` / `Two 1sts` / `A similar player`) and edit from there.
  Leave any you're not sure about blank -- an empty answer isn't saved.
- Answers save permanently to `value_checks.json` (same gitignored,
  append-only posture as `ratings.json`). "View Saved Value Checks"
  shows every answer alongside what `playerTradeValue()` currently
  computes for that exact profile, so a real mismatch between your
  answer and the engine's own number is easy to spot.
- The 3 pick-anchor answers specifically are the cleanest way to settle
  what `kDraftPickTradeValue` should actually be -- rating a
  already-built trade can only ever say "this feels wrong"; naming a
  price for the pick-anchor profile directly says what a real 1st/2nd/3rd
  should be worth.

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
