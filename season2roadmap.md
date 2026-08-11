# Season 2 Roadmap — GM Answers (2026-08-10)

Answers to the 5 open questions from [`0D_Season_2_Roadmap.md`](0D_Season_2_Roadmap.md) / the [Path to Season 2 roadmap doc](https://claude.ai/code/artifact/73e79042-8c88-4a6a-814e-c97cadec9e90). Numbered to match that file's "Open questions for GM review" section.

## 1. Contracts/salary cap

**No money, no contracts.** Confirmed: the star-tier system stays the entire off-season gate, same as `star_system.md` already intended — but the bands and caps change:

| Stars | OVR range |
|---|---|
| ★★★★ (4-star) | 90+ |
| ★★★ (3-star) | 80–89 |
| ★★ (2-star) | 70–79 |
| ★ (1-star) | 60–69 |
| — (no stars) | below 60 |

**Roster caps:**
- Max **6 players at 3-star or higher** (OVR 80+).
- Within that 6, max **2 at 4-star** (OVR 90+).
- 2-star and below: **unlimited**.

This replaces the earlier `Aug10Questions.md` 5-tier proposal (90-99/78-89/65-77/50-64/<50) — the top tier is now 4-star, not 5-star, and the cap is defined in terms of stars rather than just a display threshold.

**Enforcement timeline** (answers the roster-legality-gate design from the roadmap's Aging & Roster Churn section too):
1. Season 2 starts → engine checks every roster (GM and AI) against the new caps.
2. GM gets an Assistant GM mail warning for any violation, naming a **fix-by date**.
3. That date is a **fixed grace period after the draft concludes** — draft picks can't break the cap on their own (a rookie is never generated above 2-star), so the grace period exists purely to let trades/cuts land. *Suggested default: 2 weeks of in-game time post-draft — needs confirmation on the exact number.*
4. After the cutoff, an still-illegal roster gets enforced (forced cut of the newest violating player, most likely — exact mechanic still TBD when this gets built).

**AI behavior:** AI teams that are over the 4-star cap will actively try to trade for the human GM's excess 4-star players rather than just sit on the violation — see item 4 below, this is the same AI-initiated trade system.

## 2. Retirement rule

Multiple trigger conditions, not one formula — a player retires (or is offered the chance to) if **any** of these hit:

- **Unsigned for a full season as a free agent** → retires.
- **Lost 10+ OVR from their career peak** → retires.
- **Age 34+ and wins a championship** → considers retirement (a chance, not automatic).
- **Age 38+** → wants to retire (strong pull, presumably close to automatic).
- **On the GM's own roster**, any of the above can be countered: the GM's coach gets a **skill check** to convince the player to play one more year.

Explicitly not an exhaustive list — "there are probably other things that would cause it" — more triggers can be added later without disrupting this set.

## 3. Does anything else quietly assume "one season only"?

Yes, `trainingReports` and Mail both needed a call:

- **Off-season, both get cleared.** Mail inbox and weekly training reports don't carry over season to season.
- **Permanent exceptions:** end-of-season reports and season awards stay visible forever, regardless of how many seasons have passed. Those are the historical record; the weekly noise underneath them isn't.

## 4. Free agent pool composition

**Yes — include AI-waived players.** But waiving isn't an AI team's first move when they're squeezed by the new star caps:

1. If an AI team is over cap (e.g. holding 3 4-star players against the 2-star max), it **picks one of the excess players at random** and **offers a trade to the human GM first**.
2. Only if that doesn't resolve it does the player hit waivers and flow into the free agent pool.

Flagged as real scope: **this needs a whole AI trade-offer system** — the GM doesn't have one yet, and it's now a prerequisite for this behavior, not just a "nice to have."

## 5. How many rounds/picks feel right for a real draft?

**3 rounds is right** — confirms the existing `kDraftRounds = 3` in `draft_generator.dart`. One clarification: **3rd-round picks don't always make the roster.** A late pick landing on the practice squad, getting cut, or not sticking is expected and fine — 3 real rounds doesn't mean 3 guaranteed roster spots every draft.

---

*Open thread: the exact length of the roster-legality grace period (item 1) still needs a number — 2 weeks of in-game time is a placeholder pending confirmation.*
