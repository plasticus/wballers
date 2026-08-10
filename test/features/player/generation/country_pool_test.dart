import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/country.dart';
import 'package:womensbballmgr/features/player/generation/country_pool.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';

void main() {
  group('kCountrySelectionWeights (TODO.md item 10: a flat 80/20 mix)', () {
    test('USA carries exactly 80 of the weight', () {
      expect(kCountrySelectionWeights[Country.usa], 80);
    });

    test('every non-USA country -- Canada included -- carries an equal '
        'share of the remaining 20, not a bigger slice for Canada', () {
      final nonUsaCountries = Country.values.where((c) => c != Country.usa);
      final expectedShare = 20 / nonUsaCountries.length;

      for (final country in nonUsaCountries) {
        expect(kCountrySelectionWeights[country], expectedShare);
      }
      // Canada is domestic for hometown/college purposes, but that's a
      // separate flag (`Country.isDomestic`) -- its selection odds here
      // are identical to every other non-USA country's.
      expect(
        kCountrySelectionWeights[Country.canada],
        kCountrySelectionWeights[Country.nigeria],
      );
    });

    test('sums to 100', () {
      final total = kCountrySelectionWeights.values.fold<double>(
        0,
        (a, b) => a + b,
      );
      expect(total, closeTo(100, 0.001));
    });

    test('draws land on USA roughly 80% of the time across a large sample', () {
      final random = Random(1);
      var usaCount = 0;
      const sampleSize = 5000;
      for (var i = 0; i < sampleSize; i++) {
        if (pickWeighted(random, kCountrySelectionWeights) == Country.usa) {
          usaCount++;
        }
      }
      final usaRate = usaCount / sampleSize;
      expect(usaRate, closeTo(0.8, 0.03));
    });
  });
}
