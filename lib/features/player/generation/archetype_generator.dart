import 'dart:math';

import '../domain/archetype.dart';
import '../domain/position.dart';

/// Picks a random archetype valid for [position]. Deterministic for a
/// given [random] stream. Uniform among the options -- rating correlation
/// happens downstream, in `generatePlayer`, which biases ratings to fit
/// whichever archetype this returns (see `archetype.dart`'s doc comment).
Archetype generateArchetype(Random random, Position position) {
  final options = kArchetypesByPosition[position]!;
  return options[random.nextInt(options.length)];
}
