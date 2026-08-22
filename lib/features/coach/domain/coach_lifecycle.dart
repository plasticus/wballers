/// Age-driven coach generation/growth/retirement -- locked 2026-08-19,
/// `coach-lifecycle-notes.md`. Replaces the old fixed-`qualityCenter`
/// jitter-based generation (`coach_generator.dart`'s original
/// `_generateStat`): a coach's total skill (the 5 `CoachStats` fields
/// summed, see `CoachStats.skillTotal`) is now a pure function of their
/// age, and grows by a flat amount every off-season instead of being
/// independently rolled once and never touched again.
library;

/// The age a coach enters the league at -- "coaches... enter into the
/// game around 45," a direct GM call. [kCoachEntryAge] alone (used only
/// by [coachSkillTotalForAge]'s own formula, and by tests checking that
/// formula's exact anchor point) is untouched by the widening below.
const kCoachEntryAge = 45;

/// What every *replacement* hire (the GM's own voluntary hires off
/// [AvailableHeadCoachesScreen], and an AI team's fired-and-rehired or
/// mandatory-retirement replacements) draws its age from -- as opposed
/// to [kCoachInitialLeagueMinAge]/[kCoachInitialLeagueMaxAge], which is
/// specifically for the one-time moment every team's very first coach is
/// generated (league/franchise creation).
///
/// Originally a tight 44-46 band around [kCoachEntryAge] -- every
/// replacement hire deliberately reading as the *same* just-entering
/// coach, philosophy (`CoachArchetype`) aside, so the only way to field
/// an established, higher-skill coach again was to grow one over time.
/// Widened here (2026-08-22, a direct GM ask: "Off-season coach hires
/// -- needs more options, bigger variety in age") -- a real, direct
/// trade-off against that original reasoning: a lucky hire at the new
/// ceiling (55, [coachSkillTotalForAge] 300) can now start meaningfully
/// stronger than a freshly generated original coach at the bottom of
/// [kCoachInitialLeagueMinAge]-[kCoachInitialLeagueMaxAge] (49,
/// [coachSkillTotalForAge] 270) -- accepted deliberately, in exchange for
/// a hiring pool of 10 that doesn't read as "the same coach, 8 different
/// labels."
const kCoachEntryMinAge = 40;
const kCoachEntryMaxAge = 55;

/// The age band every team's *original* head coach (GM's own and all 19
/// AI teams, generated once at league/franchise creation) is rolled
/// within -- "Head Coaches on team creation should all be 50, +/- 1," a
/// direct GM call, confirmed to mean *age* (not OVR) by the GM's own
/// worked example: "if they're 49 to 51, they'll have skills of 270 to
/// 280" lines up exactly with [coachSkillTotalForAge]'s own math. A
/// deliberately older, stronger starting point than [kCoachEntryMinAge]/
/// [kCoachEntryMaxAge] -- every real *replacement* hire thereafter (the
/// GM's own voluntary hires, and an AI team's fired-and-rehired or
/// mandatory-retirement replacements) draws a fresh, weaker,
/// just-entering-the-league coach instead; the only way to field an
/// established, higher-skill coach again is to grow one over time,
/// exactly like "higher-skill coaches will be older" describes.
const kCoachInitialLeagueMinAge = 49;
const kCoachInitialLeagueMaxAge = 51;

/// A coach's last active season -- "coaches retire at 65," a direct GM
/// call, matching [coachSkillTotalForAge]'s own worked ceiling ("at age
/// 65 (their final season prior to retirement) they are worth 350
/// points"). The season *after* turning 66 is when they actually leave
/// -- see [kCoachMandatoryRetirementAge].
const kCoachRetirementAge = 65;

/// The age at which a coach is actually removed and replaced --
/// `coach_aging_advancer.dart`'s `resolveCoachAging` checks this *after*
/// applying that off-season's growth, so a coach plays out their full
/// [kCoachRetirementAge] (65) season first, same "one final season, then
/// gone" shape [kMandatoryRetirementAge] already gives players (just no
/// persuasion-to-stay mechanic -- nothing like that was ever described
/// for coaches).
const kCoachMandatoryRetirementAge = kCoachRetirementAge + 1;

/// Per-stat floor and ceiling for every `CoachStats` field -- "Coach
/// skill min of 30, max of 79," a direct GM call. [kCoachMaxStat] also
/// happens to match `coach_generator.dart`'s old *real* generation
/// ceiling almost exactly (qualityCenter 50 + the strongest archetype
/// bias 14 + max jitter 15 = 79) -- not a coincidence the GM noticed and
/// called out, now a real locked bound instead of an emergent one.
const kCoachMinStat = 30;
const kCoachMaxStat = 79;

/// A coach's total skill (`CoachStats.skillTotal`) for [age] -- "flat +1
/// per skill every off-season... At age 45, they are worth 250 overall
/// points. At age 65... they are worth 350 points," a direct GM call.
/// The two endpoints and the growth rate aren't 3 independent numbers:
/// 65 − 45 = 20 seasons × 5 stats × 1 point/season = 100 points of
/// growth, and 250 + 100 = 350 exactly -- this linear formula is just
/// that same fact, generalized to every age in between (and used as the
/// starting total for a freshly generated coach of any age, not only 45
/// or 65).
int coachSkillTotalForAge(int age) => 250 + 5 * (age - kCoachEntryAge);

/// Whether a coach at [age] has hit mandatory retirement --
/// `coach_aging_advancer.dart`'s own trigger, checked once per off-season
/// after that season's growth has already applied.
bool coachHasReachedMandatoryRetirement(int age) =>
    age >= kCoachMandatoryRetirementAge;
