import 'dart:math';

import '../domain/trait.dart';

/// Rolls a small set of generation-eligible traits (`traits.md`) for a
/// newly generated player: somewhere between none and [maxTraits],
/// distinct, never both sides of an opposite pair (`kOppositeTraitPairs`).
/// Deterministic for a given [random] stream.
///
/// Most traits are earned in-season or in-game (Phase 2/3 systems that
/// don't exist yet) — this only covers the subset assignable at
/// generation/draft time (question.md decision 21), which is everything
/// except [Trait.homegrown].
Set<Trait> generateTraits(Random random, {int maxTraits = 3}) {
  final shuffled = kGenerationEligibleTraits.toList()..shuffle(random);
  final count = random.nextInt(maxTraits + 1);

  final selected = <Trait>{};
  for (final trait in shuffled) {
    if (selected.length >= count) break;
    final opposite = oppositeOf(trait);
    if (opposite != null && selected.contains(opposite)) continue;
    selected.add(trait);
  }
  return selected;
}
