# WNBA Rules — Reference Sources

Not a design doc — pointers to real-world source material, kept so we
don't have to re-derive them later. Don't reproduce large verbatim
excerpts of these into the repo; they're copyrighted third-party material.

## Official on-court rules (2026)

<https://cdn.wnba.com/sites/4/2026/05/2026-WNBA-Official-Rule-Book.pdf>

91 pages, on-court game rules only (fouls, substitutions, timing,
officiating) — nothing about roster construction. Relevant for Phase 3's
match engine, not Phase 1's roster work. Sections worth returning to
when building the possession-based engine:

- Rule 3 — Players, Substitutes, and Coaches (foul-out at 6 personal
  fouls, substitution procedure, captain rules)
- Rule 5 — Scoring and Timing (timeouts, overtime, shot clock resets)
- (Full rules index is on the PDF's first page if more sections are
  needed later.)

## Roster / CBA rules (2026 season)

Roster construction (active roster size, developmental spots, injury/
inactive handling) is governed by the WNBA-WNBPA Collective Bargaining
Agreement, not the rule book above — it's a separate document. Findings
from press coverage, not yet mapped into a game decision:

- Active roster: 12 players (some inconsistency in reporting on the
  exact minimum-before-penalty; not fully reconciled).
- Developmental roster: 2 spots per team, optional, exempt from the
  salary cap, restricted to players with 0-3 years of WNBA service,
  activation capped at 12 games/season without a full contract.
- No single clean "injured reserve" bucket — a hardship exception
  (temporary extra spot, 2+ players out 3+ weeks) and a suspended list
  (specifically for injuries from outside WNBA play) cover different
  cases; in-season injuries mostly just stay on the 12-man roster.
- Sources: [Key terms of the new WNBA CBA](https://sports.yahoo.com/articles/key-terms-wnba-cba-111103528.html), [WNBA CBA news deal details](https://www.cbssports.com/wnba/news/wnba-cba-news-deal-details-salaries-explainer/), [Development players](https://www.swishappeal.com/wnba/77598/development-player-contracts-roster-new-cba-stipend-active-benefits-mystics-fever-liberty-sparks-fire-littlepage-buggs-fauthoux-pissott), [WNBA hardship exceptions](https://frontofficesports.com/wnba-hardship-exceptions-developmental-roster-spots-cba-rules/), [WNBA CBA salary cap explained](https://herhoopstats.com/wnba_cba_salary_cap_explained)
