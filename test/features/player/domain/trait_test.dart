import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';

void main() {
  test('every trait has a non-empty label and description', () {
    for (final trait in Trait.values) {
      expect(trait.label, isNotEmpty);
      expect(trait.description, isNotEmpty);
    }
  });

  test('oppositeOf is symmetric for every declared pair', () {
    for (final pair in kOppositeTraitPairs) {
      expect(oppositeOf(pair.$1), pair.$2);
      expect(oppositeOf(pair.$2), pair.$1);
    }
  });

  test('oppositeOf returns null for a trait with no declared opposite', () {
    expect(oppositeOf(Trait.gymRat), isNull);
  });

  test('generation-eligible traits exclude only Homegrown', () {
    expect(kGenerationEligibleTraits, isNot(contains(Trait.homegrown)));
    expect(kGenerationEligibleTraits.length, Trait.values.length - 1);
  });

  test(
    'every trait has exactly one category, matching traits.md\'s counts',
    () {
      final byCategory = <TraitCategory, int>{};
      for (final trait in Trait.values) {
        byCategory[trait.category] = (byCategory[trait.category] ?? 0) + 1;
      }

      expect(byCategory[TraitCategory.workEthic], 5);
      expect(byCategory[TraitCategory.durability], 2);
      expect(byCategory[TraitCategory.leadership], 4);
      expect(byCategory[TraitCategory.mental], 5);
      expect(byCategory[TraitCategory.loyalty], 4);
      expect(byCategory[TraitCategory.crowd], 2);
      expect(byCategory[TraitCategory.skillBadge], 7);
    },
  );

  test('Leader and Malcontent (opposite pair) share a category', () {
    expect(Trait.leader.category, Trait.malcontent.category);
  });
}
