import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/draft/domain/college.dart';

void main() {
  test('has exactly 100 colleges', () {
    expect(kColleges.length, 100);
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
