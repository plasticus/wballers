import 'dart:math';

import '../../player/generation/name_pools_by_country.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/generation/portrait_generator.dart';
import '../domain/coach.dart';
import '../domain/coach_archetype.dart';
import '../domain/coach_lifecycle.dart';
import '../domain/coach_stats.dart';

/// Per-stat weighting used when distributing a fixed total across the 5
/// `CoachStats` fields (`_distributeStats`) -- same "archetype rolled
/// first, then biases the stat block" shape `player_generator.dart`
/// uses, just spent as *how likely this stat is to get the next point*
/// rather than *how much to nudge an independent roll*, since generation
/// is age-first now (`coach_lifecycle.dart`): the total is fixed by age,
/// not free to vary with the bias.
typedef _StatDeltas = ({
  int offense,
  int defense,
  int development,
  int motivation,
  int management,
});

const _zeroDeltas = (
  offense: 0,
  defense: 0,
  development: 0,
  motivation: 0,
  management: 0,
);

const Map<CoachArchetype, _StatDeltas> _archetypeBias = {
  CoachArchetype.offensiveInnovator: (
    offense: 14,
    defense: -6,
    development: 0,
    motivation: 2,
    management: 0,
  ),
  CoachArchetype.defensiveMastermind: (
    offense: -6,
    defense: 14,
    development: 0,
    motivation: 2,
    management: 0,
  ),
  CoachArchetype.playersCoach: (
    offense: 0,
    defense: 0,
    development: 8,
    motivation: 14,
    management: -6,
  ),
  CoachArchetype.talentDeveloper: (
    offense: 0,
    defense: 0,
    development: 14,
    motivation: -6,
    management: 0,
  ),
  CoachArchetype.programBuilder: (
    offense: 0,
    defense: 0,
    development: -4,
    motivation: -6,
    management: 14,
  ),
  CoachArchetype.oldSchoolDisciplinarian: (
    offense: -8,
    defense: 10,
    development: -2,
    motivation: 10,
    management: -2,
  ),
  CoachArchetype.fieryCompetitor: (
    offense: 4,
    defense: 4,
    development: -10,
    motivation: 14,
    management: -4,
  ),
  // Deliberately zero -- a "no real weakness, no real standout" generalist
  // is its own legitimate archetype, not a missing entry.
  CoachArchetype.steadyHand: _zeroDeltas,
};

enum _Stat { offense, defense, development, motivation, management }

/// Keeps every stat's pick-weight positive even at the single most
/// negative bias any archetype defines today (-10, `fieryCompetitor`'s
/// development) -- a stat that's actively biased *against* should still
/// be pickable sometimes, just rarely, not literally impossible.
const _kBaseWeight = 20;

/// Distributes [age]'s [coachSkillTotalForAge] across the 5 `CoachStats`
/// fields: every stat starts at [kCoachMinStat], then one point at a time
/// (weighted by [bias] -- a stat gets picked roughly
/// `(bias + _kBaseWeight)`-proportionally often, so a +14 archetype lean
/// reads clearly without ever fully starving a -6/-10 one) goes to a
/// randomly chosen stat that hasn't yet hit [kCoachMaxStat], until the
/// full total is placed. Guarantees the exact total and every per-stat
/// bound by construction -- no clamp-and-hope needed the way independent
/// jitter rolls used to require. [coachSkillTotalForAge]'s real range
/// (250-350) never gets close to forcing an impossible distribution: the
/// floor (5×[kCoachMinStat] = 150) and ceiling (5×[kCoachMaxStat] = 395)
/// both comfortably contain it.
CoachStats _distributeStats(
  Random random, {
  required int age,
  required _StatDeltas bias,
}) {
  final biasFor = {
    _Stat.offense: bias.offense,
    _Stat.defense: bias.defense,
    _Stat.development: bias.development,
    _Stat.motivation: bias.motivation,
    _Stat.management: bias.management,
  };
  final values = {for (final stat in _Stat.values) stat: kCoachMinStat};

  var remaining =
      coachSkillTotalForAge(age) - kCoachMinStat * _Stat.values.length;
  while (remaining > 0) {
    final eligible = [
      for (final stat in _Stat.values)
        if (values[stat]! < kCoachMaxStat) stat,
    ];
    assert(
      eligible.isNotEmpty,
      'coachSkillTotalForAge($age) exceeds every stat maxed at kCoachMaxStat',
    );
    final weights = [
      for (final stat in eligible) biasFor[stat]! + _kBaseWeight,
    ];
    final totalWeight = weights.fold(0, (sum, w) => sum + w);
    var roll = random.nextInt(totalWeight);
    var chosen = eligible.last;
    for (var i = 0; i < eligible.length; i++) {
      if (roll < weights[i]) {
        chosen = eligible[i];
        break;
      }
      roll -= weights[i];
    }
    values[chosen] = values[chosen]! + 1;
    remaining--;
  }

  return CoachStats(
    offense: values[_Stat.offense]!,
    defense: values[_Stat.defense]!,
    development: values[_Stat.development]!,
    motivation: values[_Stat.motivation]!,
    management: values[_Stat.management]!,
  );
}

/// Generates a coach with a random name, a rolled [CoachArchetype], a
/// random age in [minAge]-[maxAge] inclusive, and stats distributed to
/// hit that age's real [coachSkillTotalForAge] exactly
/// (`_distributeStats`) -- a hired NPC, not a blank [CoachStats.neutral]
/// clone, so a new franchise's starting coach feels like a distinct
/// individual the same way a generated player does. Deterministic for a
/// given [random] stream.
///
/// [archetype] defaults to a random roll; pass one explicitly to force a
/// specific style instead -- what [generateCoachCandidates] does to build
/// a set of head-coach options the GM picks between, each with a
/// different, already-known philosophy rather than another random roll.
///
/// [portraitWeights] is optional, same contract as `generatePlayer`'s: omit
/// it to leave [Coach.appearance] `null` without consuming any random
/// numbers for it. [portraitManifest] is separately optional -- without it,
/// a generated coach's [PortraitAppearance.shoulders] stays `null`, same as
/// before a manifest was threaded through at all.
Coach generateCoach(
  Random random, {
  required int minAge,
  required int maxAge,
  CoachArchetype? archetype,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final resolvedArchetype =
      archetype ??
      CoachArchetype.values[random.nextInt(CoachArchetype.values.length)];
  final bias = _archetypeBias[resolvedArchetype] ?? _zeroDeltas;
  final age = minAge + random.nextInt(maxAge - minAge + 1);

  final firstName = kAllGivenNames[random.nextInt(kAllGivenNames.length)];
  final lastName = kAllSurnames[random.nextInt(kAllSurnames.length)];
  final appearance = portraitWeights == null
      ? null
      : generatePortraitAppearance(
          random,
          isCoach: true,
          weights: portraitWeights,
          manifest: portraitManifest,
        );

  return Coach(
    name: '$firstName $lastName',
    stats: _distributeStats(random, age: age, bias: bias),
    archetype: resolvedArchetype,
    age: age,
    appearance: appearance,
  );
}

/// A set of [count] head-coach candidates to choose between -- each a
/// different, already-known [CoachArchetype] (a shuffle of
/// [CoachArchetype.values], not [count] independent random rolls, so two
/// candidates never duplicate a philosophy up to [CoachArchetype.values]'s
/// own length, then genuinely random archetypes beyond that for a larger
/// [count] like the Available Head Coaches screen's 10) -- "pull from the
/// archetypes at random" per the GM's own framing for the original
/// onboarding picker; the same shape now also powers
/// `AvailableHeadCoachesScreen`'s later hiring pool, just with a wider
/// [minAge]-[maxAge] band and a bigger [count].
List<Coach> generateCoachCandidates(
  Random random, {
  int count = 3,
  required int minAge,
  required int maxAge,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final archetypes = [...CoachArchetype.values]..shuffle(random);
  final resolvedArchetypes = [
    for (var i = 0; i < count; i++) archetypes[i % archetypes.length],
  ];
  return [
    for (final archetype in resolvedArchetypes)
      generateCoach(
        random,
        minAge: minAge,
        maxAge: maxAge,
        archetype: archetype,
        portraitWeights: portraitWeights,
        portraitManifest: portraitManifest,
      ),
  ];
}

/// One off-season's worth of aging for [coach] -- age +1, every one of
/// the 5 `CoachStats` fields +1, each independently capped at
/// [kCoachMaxStat] -- "a flat +1 per skill every off-season," a direct GM
/// call, deliberately *not* a re-derivation from [coachSkillTotalForAge]
/// (that formula only ever sets a *freshly generated* coach's starting
/// total; growth afterward is purely additive). A stat that hits
/// [kCoachMaxStat] before [coach] reaches [kCoachRetirementAge] simply
/// stops growing on that one stat -- no overflow rollover to another
/// stat, matching the flat, simple rule as given. Doesn't check
/// retirement itself -- `coach_aging_advancer.dart`'s
/// `resolveCoachAging` calls [coachHasReachedMandatoryRetirement] on the
/// *result* of this to decide that separately.
Coach growCoach(Coach coach) {
  int grow(int stat) => stat >= kCoachMaxStat ? stat : stat + 1;
  return coach.copyWithGrowth(
    newAge: coach.age + 1,
    newStats: CoachStats(
      offense: grow(coach.stats.offense),
      defense: grow(coach.stats.defense),
      development: grow(coach.stats.development),
      motivation: grow(coach.stats.motivation),
      management: grow(coach.stats.management),
    ),
  );
}
