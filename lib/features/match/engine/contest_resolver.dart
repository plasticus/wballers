import 'dart:math';

/// Converts a rating gap into a win probability for [attackerRating], on a
/// logistic curve centered at 50% when the two ratings are equal. This is
/// the shared shape behind every contested in-game check (shots, passes,
/// drives, rebounds, tip-offs, ...) -- each action type tunes its own feel
/// via [floor]/[ceiling]/[steepness] rather than every action re-deriving
/// its own formula.
///
/// [floor] and [ceiling] bound the result so neither side is ever a lock:
/// even a hopeless mismatch keeps a sliver of a chance ([floor]) and even a
/// dominant one is never a certainty ([ceiling]). [steepness] controls how
/// fast probability moves away from 50% per point of rating gap -- higher
/// means skill gaps matter more.
double contestProbability({
  required int attackerRating,
  required int defenderRating,
  double floor = 0.05,
  double ceiling = 0.95,
  double steepness = 0.05,
}) {
  final gap = (attackerRating - defenderRating).toDouble();
  final logistic = 1 / (1 + exp(-steepness * gap));
  return floor + (ceiling - floor) * logistic;
}

/// Rolls one contested check and returns whether the attacker won it.
/// Deterministic for a given [random] stream, same pattern as the rest of
/// generation: pass the same stream across a whole game so results chain
/// off one seed.
bool resolveContest(
  Random random, {
  required int attackerRating,
  required int defenderRating,
  double floor = 0.05,
  double ceiling = 0.95,
  double steepness = 0.05,
}) {
  final probability = contestProbability(
    attackerRating: attackerRating,
    defenderRating: defenderRating,
    floor: floor,
    ceiling: ceiling,
    steepness: steepness,
  );
  return random.nextDouble() < probability;
}
