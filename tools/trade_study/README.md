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

- Every visit generates 5 trades (assuming a coach with 70 Management,
  matching the real `tradeSwing()` formula from
  `lib/features/trade/domain/trade_value.dart`). Reloading the page keeps
  the same batch; submitting the form rolls a brand new one, so you can
  run this as many times as you want.
- Every batch guarantees at least one 1st-round-pick trade, one
  2nd-round-pick trade, one **SELL FOR PICKS** trade (a player, no
  return player, straight for picks -- the real "Gain Picks" toggle's
  flat sell-off shape), and one **MOVE UP** trade (spending a worse
  pick you own, maybe with a player thrown in, for one real better pick
  -- the toggle's other shape), each badged so you can tell them apart.
  Both new shapes (added 2026-08-23) use a wider discount tolerance than
  ordinary trades (`EXTRA_PICK_TOLERANCE`, matching
  `kSellForPicksExtraTolerance`/`kPickSpendExtraTolerance` in the real
  game) -- expect these to read as more one-sided than an ordinary
  trade; that's by design, not a bug to flag.
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
