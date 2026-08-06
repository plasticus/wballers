import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';

void main() {
  test('every archetype has a non-empty, unique label', () {
    final labels = <String>{};
    for (final archetype in CoachArchetype.values) {
      expect(archetype.label, isNotEmpty);
      labels.add(archetype.label);
    }
    expect(labels.length, CoachArchetype.values.length);
  });
}
