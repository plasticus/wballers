import '../domain/country.dart';

/// How often a generated player's [Country] lands on each value -- a flat
/// 80/20 (2026-08-10, a direct GM ask superseding this table's original
/// 60/4/2s split): 80% USA, the international 20% split evenly across
/// all 19 non-USA countries, [Country.canada] included -- it stays
/// [CountryLabel.isDomestic] for hometown/college purposes either way
/// (that flag is untouched by this table), it just no longer gets a
/// bigger slice of selection odds than any other non-USA country. No
/// attempt to model relative basketball-pipeline strength per country,
/// same reasoning the original split already had -- there's no
/// "correct" answer for a fictional league's international mix, and an
/// even split keeps every non-USA country equally likely to show up
/// rather than letting a handful dominate. Sums to 100, though
/// [pickWeighted] doesn't require that.
final Map<Country, double> kCountrySelectionWeights = {
  Country.usa: 80,
  for (final country in Country.values)
    if (country != Country.usa) country: 20 / (Country.values.length - 1),
};
