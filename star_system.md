# Basketball GM Architecture: Star System & Attribute Mechanics

## 1. Overview: Replacing the Salary Cap
Traditional sports management games rely on rigid financial structures like salary caps and luxury taxes. This framework replaces accounting-based parity with a **structural star rating system**. Franchises face hard roster limits on elite talent, preventing wealth hoarding and forcing continuous roster evolution, mid-season strategy shifts, and natural team churn.

---

## 2. League-Wide Scope & Star Limits
Designed for a **20-team league** with a standard 12-player active roster (240 total active players), the game utilizes a **1–99 attribute scale** mapped to an intuitive star-rating system:

* **4-Star Players (90+ OVR):** Elite max-impact players and MVP candidates.
* **3-Star Players (80–89 OVR):** Quality starters and difference-makers.
* **2-Star Players (70–79 OVR):** Solid rotation pieces.
* **1-Star Players (60–69 OVR):** Fringe roster players and specialists.
* **No Stars (below 60 OVR):** Bench depth, developmental rookies, and replacement-level players.

> Revised 2026-08-10 (GM decision, closing the "1-3 star bands need a
> judgment call" question this doc used to leave open): the top tier is
> now 4-star, not 5-star — every band shifted down one rather than adding
> a real 5th tier on top.

### Roster Configuration (12-Player Active Limit)
Roster construction is governed by two nested caps:
* At most **6** players total may be 3-Star-or-better (3-Star and 4-Star combined).
* Within that 6, at most **2** may be 4-Star.
* 2-Star and below are uncapped and fill whatever active roster slots remain, up to 12 total.

This means a team with zero 4-Star players can still carry up to six 3-Star players — the 3-Star cap doesn't shrink just because no 4-Star slots are used.

---

## 3. Season-Over-Season Churn & The Off-Season Reckoning
* **Mid-Season Grace Period:** Star limits lock only at the final regular-season buzzer. Calling up a rookie or trading for an upgrade mid-season lets teams make a high-stakes playoff push even if it temporarily violates structural norms.
* **The Breakout Dilemma:** If a rising player explodes statistically during a deep playoff run, their overall rating increases, pushing them into 4-star status.
* **The Off-Season Reconciliation:** Rosters must be legal before free agency and the draft. Teams facing an illegal star surplus must choose between trading their original superstar, offloading the newly popped asset at peak value, or letting core players walk. A fuller enforcement flow (Assistant GM mail warning, a fixed grace period after the draft, AI teams offering trades before waiving an excess player) is designed but not yet built — see `season2roadmap.md` and `0D_Season_2_Roadmap.md`, both blocked on the same "no real multi-season flow yet" gap.

---

## 4. Universal Attribute Formula
Action success and simulation outcomes are driven by a clean, additive universal formula:

$$\text{Action Success} = \text{Physical Stat} + \text{Skill/Defensive Stat}$$

---

## 5. Final Stat Architecture

### Physical Attributes
* **Speed:** Transition pace, running the floor, and fast-break generation.
* **Agility:** Lateral quickness, perimeter recovery, cutting, and eluding defenders.
* **Strength:** Post-ups, screen-setting, boxing out, and physical resistance.
* **Stamina:** Fatigue mitigation over four quarters and a heavy season schedule.

### Offensive Attributes
* **Ball Control:** Handles, avoiding turnovers, and navigating defensive pressure.
* **Passing:** Court vision, accuracy, and setting up teammates.
* **Inside Scoring:** Layups, post moves, and close-range efficiency.
* **Outside Scoring:** Mid-range and three-point shooting range and efficiency.

### Defensive & Playmaking Attributes
* **Perimeter Defense:** Containment and contesting shots on the perimeter.
* **Interior Defense:** Post defense, contesting drives, and rim resistance.
* **Disruption:** Active hands, passing lane deflections, steals, and loose-ball recovery.
* **Blocking:** Timing, vertical presence, and direct rim protection.

> *Note on Rebounding:* Rebounding output functions as a derivative calculation combining **Strength** with **Inside Scoring or Defense**, allowing high-strength 3-star specialists or grit-and-grind frontcourt players to dominate the glass without taking up expensive 5-star slots.
