# Basketball GM Architecture: Star System & Attribute Mechanics

## 1. Overview: Replacing the Salary Cap
Traditional sports management games rely on rigid financial structures like salary caps and luxury taxes. This framework replaces accounting-based parity with a **structural star rating system**. Franchises face hard roster limits on elite talent, preventing wealth hoarding and forcing continuous roster evolution, mid-season strategy shifts, and natural team churn.

---

## 2. League-Wide Scope & Star Limits
Designed for a **20-team league** with a standard 12-player active roster (240 total active players), the game utilizes a **1–99 attribute scale** mapped to an intuitive star-rating system:

* **5-Star Players (90–99 OVR):** Elite max-impact players and MVP candidates (~30 total in the league).
* **4-Star Players (78–89 OVR):** Solid starters and high-level rotation pieces (~80 total in the league).
* **3-Star & Below (1–77 OVR):** Bench players, specialists, and developmental rookies (~130+ total in the league) filling out the remaining roster slots.

### Roster Configuration Options (12-Player Active Limit)
Rather than fixed recipes, roster construction is governed by two nested caps:
* At most **2** players may be 5-Star.
* At most **6** players total may be 4-Star-or-better (5-Star and 4-Star combined).
* 3-Star & Below players are uncapped and fill whatever active roster slots remain, up to 12 total.

This means a team with zero 5-Star players can carry up to six 4-Star players — the 4-Star cap doesn't shrink just because no 5-Star slots are used. Revised from an earlier two-fixed-configuration draft (2+3+7 or 1+5+6) because the nested-cap framing is simpler to reason about and produces the same spirit of constraint without hardcoding every valid distribution.

---

## 3. Season-Over-Season Churn & The Off-Season Reckoning
* **Mid-Season Grace Period:** Star limits lock only at the final regular-season buzzer. Calling up a rookie or trading for an upgrade mid-season lets teams make a high-stakes playoff push even if it temporarily violates structural norms.
* **The Breakout Dilemma:** If a 3-star youngster or 4-star starter explodes statistically during a deep playoff run, their overall rating increases, pushing them into 5-star status.
* **The Off-Season Reconciliation:** Rosters must be legal before free agency and the draft. Teams facing an illegal star surplus must choose between trading their original superstar, offloading the newly popped asset at peak value, or letting core players walk.

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
