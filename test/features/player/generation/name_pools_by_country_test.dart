import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/generation/name_pools_by_country.dart';

void main() {
  group('kAllGivenNames / kAllSurnames (2026-08-19: coach generation folded '
      'into these -- see the pools\' own doc comments, "coach names... '
      'they should pull from the same pool")', () {
    test('flatten every country\'s pool, with nothing missing or '
        'duplicated in the flattening itself', () {
      final expectedGivenCount = kGivenNamesByCountry.values.fold<int>(
        0,
        (sum, names) => sum + names.length,
      );
      final expectedSurnameCount = kSurnamesByCountry.values.fold<int>(
        0,
        (sum, names) => sum + names.length,
      );

      expect(kAllGivenNames, hasLength(expectedGivenCount));
      expect(kAllSurnames, hasLength(expectedSurnameCount));
    });

    test('includes names folded in from the old coach-only pool', () {
      // A sample spanning both "new to USA" and "already existed
      // elsewhere" cases from the merge.
      expect(kAllGivenNames, containsAll(['Chidinma', 'Thandiwe', 'Yuki']));
      expect(kAllSurnames, containsAll(['Okafor', "O'Brien", 'Nakamura']));
    });
  });
}
