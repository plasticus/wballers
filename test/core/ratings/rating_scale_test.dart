import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/ratings/rating_scale.dart';

void main() {
  test('excludes 0 and 100', () {
    expect(isValidRating(0), isFalse);
    expect(isValidRating(100), isFalse);
  });

  test('includes the 1-99 bounds', () {
    expect(isValidRating(1), isTrue);
    expect(isValidRating(99), isTrue);
  });

  test('includes values in between', () {
    expect(isValidRating(50), isTrue);
  });
}
