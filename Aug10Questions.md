# Open questions on the remaining Aug 9 items (2026-08-10)

Couldn't create this directly in Google Keep (no Keep integration available from this session) — copy/paste into a new note instead.

## #6 — Aging curve (in-season vs off-season decay)

Real blocker: there's no "off-season" / "start next season" concept in the game at all yet — one continuous season, no year field, nothing to hang "decline concentrated in the off-season" off of.

- Do you want a stopgap now — just soften in-season weekly decay for veterans — with the "move it to the off-season" half deferred until a real multi-season system exists? Or hold the whole thing until that system is built?
- If doing the stopgap: how much softer? Cut veteran weekly decline roughly in half? A specific number?
- Should this only apply to older/declining players (the ones actually affected today), or reshape the whole age curve?

## #13 — End-of-season report: player development

Turns out this might NOT be blocked on multi-season support — weekly TrainingReports already store per-player, per-field deltas for the whole season. A "how much did this player improve" summary could likely be built by summing those, without a new season-start snapshot.

- Want this scoped to just your own roster, or league-wide (so you can also see how a rival's rookie developed)?
- Show total OVR change per player, or a full stat-by-stat breakdown (like a single training report, but season-long)?
- Sort/highlight by biggest gainers and decliners, or just list the roster in order?

## #19 — Star-quality indicator (the other half of the Starter-badge fix)

star_system.md only defines the top two tiers (90-99 = 5-star, 78-89 = 4-star) and lumps everything else into one "3-star & below" bucket. Real bands are needed for 1-3 stars.

- My default proposal: 5-star 90-99, 4-star 78-89, 3-star 65-77, 2-star 50-64, 1-star below 50. Good, or do you want different cutoffs?
- Display as repeated glyphs (⭐⭐⭐⭐⭐) or compact "N ⭐"?
- Where should it show — roster row, player detail, both?

## #21 — Blowout rubber-banding (pace only, no stat nerfing)

- Trigger margin: is +20 the right threshold, or should it scale continuously with margin (e.g., a bit slower at +15, a lot slower at +30)?
- Roughly how much slower — a target possession-length increase (e.g., +20%), or should I just tune by feel and report back what it does to blowout frequency?
- Should the trailing team get any complementary effect (e.g., pushing pace to climb back in it), or is this strictly "leading team protects the lead" and nothing else?

## #8 — Rebounds-per-game anomaly (PG ranked #3 in the league)

- Want me to actually dig into the rebounding formula now and check whether it's a real bug, or keep this as "watch for now" until it recurs?

## #16 — Coach attributes (informational, not a bug)

Confirmed: only Development is wired in (feeds training growth). Offense/Defense/Motivation/Management are generated and shown but do nothing yet.

- Worth scoping as a real feature soon, or stays on the shelf for now? If soon: any starting thoughts on what each stat should affect (e.g., Motivation → training bonus, Offense/Defense → in-game play-calling bias, Management → rest/rotation decisions)?
