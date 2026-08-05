import 'dart:math';

import '../domain/trait.dart';

/// Rolls a small set of generation-eligible traits (`traits.md`) for a
/// single player: somewhere between none and [maxTraits] (a hard ceiling,
/// not a target -- see [_rollTraitCount]), distinct, never both sides of
/// an opposite pair (`kOppositeTraitPairs`). Deterministic for a given
/// [random] stream.
///
/// Used by the draft-prospect generator (`draft_generator.dart`) -- most
/// traits enter the league this way, one incoming player at a time,
/// rather than through `distributeTraits`' team-wide roster-generation
/// pass. Weighted the same "rare to have even one, very rare to have two"
/// way that pass is, per the trait-redesign design intent (`0A_Completed.md`).
///
/// Most traits are earned in-season or in-game (Phase 2/3 systems that
/// don't exist yet) — this only covers the subset assignable at
/// generation/draft time (question.md decision 21), which is everything
/// except [Trait.homegrown].
Set<Trait> generateTraits(Random random, {int maxTraits = 3}) {
  final count = _rollTraitCount(random, maxTraits);
  final shuffled = kGenerationEligibleTraits.toList()..shuffle(random);

  final selected = <Trait>{};
  for (final trait in shuffled) {
    if (selected.length >= count) break;
    final opposite = oppositeOf(trait);
    if (opposite != null && selected.contains(opposite)) continue;
    selected.add(trait);
  }
  return selected;
}

/// Weighted toward few traits regardless of [maxTraits] -- most prospects
/// get none, a solid minority get one, a second is rare, a third rarer
/// still. [maxTraits] only ever clamps this down (e.g. `maxTraits: 0`
/// always returns 0), it never raises the odds of a higher count.
int _rollTraitCount(Random random, int maxTraits) {
  final roll = random.nextDouble();
  final uncapped = switch (roll) {
    < 0.55 => 0,
    < 0.90 => 1,
    < 0.98 => 2,
    _ => 3,
  };
  return uncapped > maxTraits ? maxTraits : uncapped;
}

/// Picks one trait not already in [existingTraits] and not the opposite of
/// one already held -- `null` if no eligible trait remains (shouldn't
/// happen in practice with 29 traits and at most a couple already held).
/// The single-trait building block both [generateTraits] and
/// `distributeTraits` use.
Trait? pickEligibleTrait(Random random, Set<Trait> existingTraits) {
  final candidates = kGenerationEligibleTraits.where((trait) {
    if (existingTraits.contains(trait)) return false;
    final opposite = oppositeOf(trait);
    return opposite == null || !existingTraits.contains(opposite);
  }).toList();
  if (candidates.isEmpty) return null;
  return candidates[random.nextInt(candidates.length)];
}
