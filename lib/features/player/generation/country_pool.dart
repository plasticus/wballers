import '../domain/country.dart';

/// How often a generated player's [Country] lands on each value -- USA-
/// heavy (matches a pro league's domestic-majority roster), Canada next
/// (still [CountryLabel.isDomestic], but a much smaller slice), and the
/// remaining 18 countries splitting the rest evenly rather than trying to
/// model relative basketball-pipeline strength per country. A GM design
/// call (2026-08-10) -- there's no "correct" answer for a fictional
/// league's international pipeline size, and an even split keeps every
/// non-domestic country equally likely to show up rather than letting a
/// handful dominate. Sums to 100, though [pickWeighted] doesn't require
/// that.
final Map<Country, double> kCountrySelectionWeights = {
  Country.usa: 60,
  Country.canada: 4,
  for (final country in Country.values)
    if (!country.isDomestic) country: 2,
};
