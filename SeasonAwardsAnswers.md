# Season Awards — GM Answers (2026-08-10)

Answers to the 5 open questions from the [WBL Awards Catalog](https://claude.ai/code/artifact/1c53c449-9fb1-4ab7-983c-36d57245dbf5) design brainstorm, plus two new pieces of scope (an All-Star Weekend, and a Coach of the Year / coach free agency system) that came out of talking through it. Numbered as the GM gave them, not in the catalog's original order.

## 1. What does "Most Defensive Disruptions" actually mean?

**Disruption = steals + blocks.** It's the GM's own internal shorthand, not a term that should ever be shown to the player — so no separate "Most Defensive Disruptions" award. It folds into **Defensive Player of the Year**, which already proposed a steals+blocks composite score. One award, not two.

## 2. All-WBL Teams: ranked or positional?

Superseded — instead of All-WBL First/Second Team, build a real **All-Star Game**.

- Two squads: **Pacific vs. Atlantic**, by conference.
- Each squad picked as the **top 2 players at each position, per conference** — 10 players a side, 20 players total earn the honor.
- Sim a full game between the two rosters and name a **Game MVP**.
- Selection happens at roughly the **¾ mark of the season**.
- All-Star week is a **full league break** — no regular-season games that week for anyone.
- Same break hosts a **Skills Competition** (see below).
- → **New TODO item: All-Star Game.**
- → **New TODO item: Skills Competition.**

### Skills Competition (part of the same All-Star break)

Confirmed, all 3 locked in:
- **3-Point Shootout**
- **HORSE**
- **Defensive Skills Challenge** — a timed closeout/deflection drill, scored off Steals + Blocks (the same Disruption composite as Defensive Player of the Year) with some variance. Swapped in for an earlier offense-only Skills Challenge idea (Ballhandling/Passing/Finishing relay) once the GM pointed out 3-Point and HORSE already cover offense twice over — this balances the competition at 2 offense / 1 defense instead of 3 offense.
- No dunk contest — not something this game can simulate meaningfully.

## 3. Is Sixth Player worth a real starter/bench data model?

**Yes — this is a must-have.** Keep it simple: use **minutes played**. Rank each team's roster by season minutes, descending; the **#6 player by minutes** is that team's "sixth man." Compare the #6-ranked player across all 20 teams for the league award. No new starter/bench flag needed on `RosterStatus` — minutes rank alone is enough.

## 4. How rare should the rare hair colors stay?

Revised rule, and it now applies to **every award except All-Star selection**:

- **Win one award** (any of them) → the player earns a **nickname** suggestion, same as the catalog proposed.
- **Win a second award** (any award, not necessarily the same one) → the game **automatically assigns a random neon hair color** to that player. That also **unlocks the neon hair-color palette** for that player going forward (previously locked/inaccessible in the editor).
- Until a player has earned a second award, neon hair colors stay locked for them — this replaces the catalog's "reserve the 4 rare colors for MVP/DPOY only" proposal with a simpler earned-progression rule that applies league-wide, across all award types.

## 5. Fine to defer Coach of the Year and Executive of the Year entirely?

Split decision:

- **Coach of the Year: yes, build it.** Every AI team needs a real generated coach (confirmed blocker from the original catalog — 19 of 20 teams have none today).
- Pair it with an off-season coaching sim: at the end of each season, roughly the **bottom 5 teams** (by record) **fire their coach**. A coach who was just hired gets a **2-season grace period** before they're eligible to be fired, so a new hire isn't judged on one bad year.
- → **New TODO item: Coach free agency in the off-season** — the hiring/firing flow itself (open coaching vacancies, AI teams hiring replacements) needs to become a real system, not just the firing trigger.
- **Executive of the Year: no.** Dropped from the catalog — not wanted.

## 6. Most Improved Player / Rookie of the Year overlap (new)

Not one of the original 5 questions, but a rule worth locking in now: **if the same player would win both Most Improved Player and Rookie of the Year, they keep Rookie of the Year, and Most Improved Player rolls down to the next-highest total-growth player instead.** The two awards should never point at the same player in the same season.

---

*Follow-up: TODO.md updated with 3 new items — All-Star Game, Skills Competition, and Coach free agency in the off-season.*
