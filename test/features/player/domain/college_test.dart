import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/college.dart';

void main() {
  test('has exactly 100 colleges', () {
    expect(kColleges.length, 100);
  });

  test('weightedColleges repeats each college by prestige (premier x3, '
      'strong x2, developing x1)', () {
    final pool = weightedColleges();
    final counts = <CollegePrestige, int>{};
    for (final tier in CollegePrestige.values) {
      counts[tier] = kColleges.where((c) => c.prestige == tier).length;
    }
    final expectedTotal =
        counts[CollegePrestige.premier]! * 3 +
        counts[CollegePrestige.strong]! * 2 +
        counts[CollegePrestige.developing]! * 1;
    expect(pool.length, expectedTotal);

    for (final college in kColleges) {
      final expectedCount = switch (college.prestige) {
        CollegePrestige.premier => 3,
        CollegePrestige.strong => 2,
        CollegePrestige.developing => 1,
      };
      expect(
        pool.where((c) => c.abbreviation == college.abbreviation).length,
        expectedCount,
        reason: college.abbreviation,
      );
    }
  });

  test('every abbreviation is unique and exactly 3 uppercase letters', () {
    final abbreviations = kColleges.map((c) => c.abbreviation).toSet();
    expect(abbreviations.length, kColleges.length);

    final threeUppercase = RegExp(r'^[A-Z]{3}$');
    for (final college in kColleges) {
      expect(threeUppercase.hasMatch(college.abbreviation), isTrue);
    }
  });

  test('every college has a non-empty name and location', () {
    for (final college in kColleges) {
      expect(college.name, isNotEmpty);
      expect(college.location, isNotEmpty);
    }
  });
}
