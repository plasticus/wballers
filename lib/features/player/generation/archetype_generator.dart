import 'dart:math';

import '../domain/archetype.dart';
import '../domain/position.dart';

/// Picks a random archetype valid for [position]. Deterministic for a
/// given [random] stream. Random rather than rating-correlated -- see
/// `archetype.dart`'s doc comment on why.
Archetype generateArchetype(Random random, Position position) {
  final options = kArchetypesByPosition[position]!;
  return options[random.nextInt(options.length)];
}
