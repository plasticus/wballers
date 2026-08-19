# Coach lifecycle — age, growth, hiring, retirement

Built 2026-08-19, same session as the AI off-season trades and Trade
Deadline lock (a direct GM ask, then confirmed the same day: "build out
the rest of what I said about coaches. I really think I like it"). Every
locked number below is real, shipped code — only the Assistant Coach idea
at the bottom stays in the MAYBE pile, on the GM's own instruction.

## What's built

1. **Hiring** (`coach/presentation/available_head_coaches_screen.dart`).
   The GM can hire a new head coach every off-season, if they want to —
   entirely voluntary, no forced turnover the way a poor-record AI team
   gets fired (`coach_free_agency_advancer.dart` stays AI-only for *that*
   trigger). A Dashboard button ("Available Head Coaches", shown only
   during the off-season window — a champion crowned, the next season not
   yet begun, same gate `SeasonRecapScreen`'s own button already uses)
   opens a list of `kAvailableHeadCoachesCount` (10) candidates, sortable
   by Overall or any individual stat (`CoachSortKey`) via a dropdown.
   `current_franchise_provider.dart`'s `hireHeadCoach` does the actual
   swap — unconditional there (gated in the UI only, same "gate in the
   UI, not the provider" shape `isTradeWindowOpen` already established).
2. **Age** (`coach/domain/coach.dart`'s `Coach.age`, defaults to 50 so the
   many pre-existing test fixtures didn't all need updating). Real
   replacement hires (`Available Head Coaches`, an AI team's fired-or-
   retired replacement) enter at `kCoachEntryMinAge`-`kCoachEntryMaxAge`
   (44-46, "around 45"); a team's very first-ever coach
   (league/franchise creation only) instead gets the older, stronger
   `kCoachInitialLeagueMinAge`-`kCoachInitialLeagueMaxAge` (49-51) band.
   Retires at `kCoachRetirementAge` (65, their last active season) —
   removed and replaced the moment they'd turn `kCoachMandatoryRetirementAge`
   (66), same "one final season, then gone" shape players' own mandatory
   retirement has (no persuasion-to-stay mechanic for coaches, unlike
   players).
3. **Growth** (`coach_generator.dart`'s `growCoach`). Flat **+1 per stat,
   every off-season**, applied to every currently-employed coach (the
   GM's own and all 19 AI teams') via `coach_aging_advancer.dart`'s
   `resolveCoachAging`, wired into `simulatePostseasonAndPersist` right
   before the existing performance-based AI firing check. Each stat caps
   individually at `kCoachMaxStat` (79) — no overflow rollover to another
   stat. At entry (45): `coachSkillTotalForAge` gives 250 total skill
   points (`CoachStats.skillTotal`, the 5 stats summed — distinct from
   `overall`, their *average*). At 65: 350. Self-consistent by
   construction: 65 − 45 = 20 seasons × 5 stats × 1 point = 100 points of
   growth, 250 + 100 = 350 exactly.
4. **Per-stat bounds** (`coach_lifecycle.dart`'s `kCoachMinStat`/
   `kCoachMaxStat`, 30/79). The 79 ceiling matches the old jitter-based
   generation's real emergent ceiling almost exactly (qualityCenter 50 +
   the strongest archetype bias 14 + max jitter 15) — now a real locked
   bound instead of an emergent one, with a real 30 floor too (the old
   system's was a looser ~29).
5. **Generation algorithm** (`coach_generator.dart`'s `_distributeStats`).
   Age first (a random roll within whichever band the caller passes),
   then `coachSkillTotalForAge(age)` fixes the target total, then that
   total gets distributed one point at a time across the 5 stats: every
   stat starts at the 30 floor, each point goes to a randomly chosen
   stat weighted by the archetype's existing bias table (`_archetypeBias`,
   unchanged from the old system — just spent as *pick weight* now
   instead of *independent jitter magnitude*), skipping any stat already
   at 79. Guarantees the exact total and every per-stat bound by
   construction. Verified the real range (250-350) never gets close to
   forcing an impossible distribution: floor 5×30=150, ceiling 5×79=395,
   both comfortably contain it.
6. **Every team's starting head coach** (GM's own and all 19 AI teams, at
   league/franchise creation — `league_generator.dart`,
   `expansion_franchise_factory.dart`, `coach_selection_screen.dart`) is
   age 49-51 — confirmed by the GM's own worked example ("if they're 49
   to 51, they'll have skills of 270 to 280") to mean *age*, matching
   `coachSkillTotalForAge(49) == 270`/`coachSkillTotalForAge(51) == 280`
   exactly.
7. **A re-roll button** on the onboarding coach-picker
   (`coach_selection_screen.dart`) draws a fresh batch of 3, still inside
   the same 49-51 age band, off a bumped seed (`_rerollCount`) —
   deterministic per press, not true randomness.
8. **Archetypes stay** — all 8 `CoachArchetype` values and their flavor
   are untouched; only the underlying stat-generation math changed to
   fit the new age-driven-total system (point 5 above).

## Real decisions made while building (previously open questions)

1. **Mandatory retirement, GM and AI alike, is a fully automatic
   replacement** — `resolveCoachAging` grows every coach, then checks
   `coachHasReachedMandatoryRetirement` on the *result*; anyone who hits
   it gets replaced on the spot with a fresh `kCoachEntryMinAge`-
   `kCoachEntryMaxAge` hire. Deliberately *not* modeled as a brief "no
   coach" gap (which would have meant making `Coach` genuinely nullable,
   rippling through match simulation/training/the in-game coaching
   picker for a gap nothing would ever actually observe) — same
   reasoning `AiTeamRoster` never models a coaching vacancy either. The
   GM keeps full control regardless: `hireHeadCoach` works identically
   whether their current coach is the one just auto-assigned or one they
   hand-picked seasons ago. Runs *before* `resolveCoachFreeAgency` in the
   pipeline, so a same-turn mandatory-retirement replacement's
   `coachHiredSeason` is already reset and can't also get
   performance-fired the same off-season.
2. **The 10 "Available Head Coaches" candidates generate fresh every
   time the screen opens**, deterministically seeded off
   `franchise.seasonSeed + kAvailableHeadCoachesSeedOffset` (stable for
   the whole off-season, changes each new season) — same "recompute,
   don't persist" posture the Draft/Free Agents preview tabs and the
   onboarding coach-picker already use. No shared, persisted "free agent
   coach pool" concept — never came up as something worth the extra
   surface area.
3. **The GM's old coach is discarded outright when they hire a new
   one** — no persisted "former coaches" list, same as a fired/retired
   AI coach. Only would matter if the Assistant Coach idea below ever
   gets built.

## MAYBE pile — Assistant Coach, still not scoped for real

A second coaching slot, deliberately **not** modifying any `CoachStats`
directly — its only job is to grow while sitting on the roster, so a GM
can develop a future head coach ahead of time: grooming a replacement for
an aging (e.g. 64-year-old) head coach, or "banking" a coach with great
stats for a season or two before promoting them. Two possible mechanics
floated, neither committed to:

- Just sit and grow (the same +1/stat/season everyone gets), with no
  effect on the current head coach at all — purely a "queue up your next
  hire" slot.
- (Flagged by the GM as possibly not worth the complexity) The assistant's
  *highest* single stat contributes 10% of its value as a bonus to the
  head coach's matching stat, for as long as both are employed together.

Stays parked, confirmed again when the rest of this file shipped: "Asst
is still in the maybe column though."
