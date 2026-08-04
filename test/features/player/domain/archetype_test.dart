import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';

void main() {
  test('every archetype has a non-empty label', () {
    for (final archetype in Archetype.values) {
      expect(archetype.label, isNotEmpty);
    }
  });

  test('every position maps to at least one archetype', () {
    for (final position in Position.values) {
      expect(kArchetypesByPosition[position], isNotEmpty);
    }
  });

  test('isArchetypeValidForPosition matches the table', () {
    expect(
      isArchetypeValidForPosition(Archetype.floorGeneral, Position.pointGuard),
      isTrue,
    );
    expect(
      isArchetypeValidForPosition(Archetype.rimRunner, Position.pointGuard),
      isFalse,
    );
    expect(
      isArchetypeValidForPosition(Archetype.threeAndD, Position.shootingGuard),
      isTrue,
    );
    expect(
      isArchetypeValidForPosition(Archetype.threeAndD, Position.smallForward),
      isTrue,
    );
  });
}
