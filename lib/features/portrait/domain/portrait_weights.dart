import 'dart:math';

/// Weighted random-generation tables (`weights.json`, `portraits.md`).
/// Deliberately kept as data loaded at runtime, not hardcoded Dart consts,
/// so art/balance tuning never requires a code change.
///
/// Choice maps use the bare content key (e.g. `hair_afro`, no `.png`), and
/// some include a sentinel for "nothing generated" (`none` for hair,
/// eyebrows, facial hair, and accessories; `natural` for [neonHair]) that
/// has no corresponding [PortraitManifest] entry.
class PortraitWeights {
  const PortraitWeights({
    required this.skinTone,
    required this.hairColorByTone,
    required this.hair,
    required this.neonHair,
    required this.eyes,
    required this.nose,
    required this.mouth,
    required this.eyebrows,
    required this.facial,
    required this.accessories,
  });

  final Map<String, double> skinTone;
  final Map<String, Map<String, double>> hairColorByTone;
  final Map<String, double> hair;
  final Map<String, double> neonHair;
  final Map<String, double> eyes;
  final Map<String, double> nose;
  final Map<String, double> mouth;
  final Map<String, double> eyebrows;
  final Map<String, double> facial;
  final Map<String, double> accessories;
}

PortraitWeights portraitWeightsFromJson(Map<String, dynamic> json) {
  Map<String, double> weightMap(dynamic value) {
    return (value as Map<String, dynamic>).map(
      (key, weight) => MapEntry(key, (weight as num).toDouble()),
    );
  }

  final hairColorByTone = (json['hair_color'] as Map<String, dynamic>).map(
    (tone, colors) => MapEntry(tone, weightMap(colors)),
  );

  return PortraitWeights(
    skinTone: weightMap(json['skin_tone']),
    hairColorByTone: hairColorByTone,
    hair: weightMap(json['hair']),
    neonHair: weightMap(json['neon_hair']),
    eyes: weightMap(json['eyes']),
    nose: weightMap(json['nose']),
    mouth: weightMap(json['mouth']),
    eyebrows: weightMap(json['eyebrows']),
    facial: weightMap(json['facial']),
    accessories: weightMap(json['accessories']),
  );
}

/// Picks a random key from [weights], proportional to its weight.
/// Deterministic for a given [random] stream.
T pickWeighted<T>(Random random, Map<T, double> weights) {
  final total = weights.values.fold<double>(0, (sum, w) => sum + w);
  var roll = random.nextDouble() * total;
  for (final entry in weights.entries) {
    roll -= entry.value;
    if (roll <= 0) return entry.key;
  }
  // Floating-point edge case: roll landed exactly on the total.
  return weights.keys.last;
}
