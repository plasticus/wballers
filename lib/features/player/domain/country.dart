/// A generated player's country of origin -- the shared root
/// `player_generator.dart` uses to pick a name pool
/// (`name_pools_by_country.dart`), a hometown city
/// (`player_generator_data.dart`'s `kHometownsByCountry`), and a skin-tone
/// distribution (`weights.json`'s `skin_tone_by_country`) together, rather
/// than three independent random rolls that could disagree with each other
/// (a Nigerian name in a Finnish hometown, a Norwegian name paired with a
/// Nairobi-weighted skin tone, etc).
///
/// Exactly the 20 countries in the GM-provided name CSV
/// (2026-08-10, `name_pools_by_country.dart`'s doc comment) -- adding a
/// 21st means adding a value here, then a name pool, a hometown list, and
/// a skin-tone table for it, in that order.
enum Country {
  usa,
  canada,
  australia,
  belgium,
  brazil,
  china,
  czechRepublic,
  finland,
  france,
  germany,
  greece,
  hungary,
  italy,
  mexico,
  nigeria,
  senegal,
  serbia,
  slovenia,
  spain,
  turkey,
}

extension CountryLabel on Country {
  /// Human-readable name -- also the exact tail end of every
  /// non-[isDomestic] `Player.hometown` string ("Prague, Czech Republic"),
  /// which `PlayerDetailScreen`'s `hometown.split(', ').last` parse
  /// depends on matching exactly.
  String get displayName => switch (this) {
    Country.usa => 'USA',
    Country.canada => 'Canada',
    Country.australia => 'Australia',
    Country.belgium => 'Belgium',
    Country.brazil => 'Brazil',
    Country.china => 'China',
    Country.czechRepublic => 'Czech Republic',
    Country.finland => 'Finland',
    Country.france => 'France',
    Country.germany => 'Germany',
    Country.greece => 'Greece',
    Country.hungary => 'Hungary',
    Country.italy => 'Italy',
    Country.mexico => 'Mexico',
    Country.nigeria => 'Nigeria',
    Country.senegal => 'Senegal',
    Country.serbia => 'Serbia',
    Country.slovenia => 'Slovenia',
    Country.spain => 'Spain',
    Country.turkey => 'Turkey',
  };

  /// USA and Canada read as domestic -- every other [Country] reads as
  /// international. Drives `Player.college` (domestic gets one,
  /// international gets `null`) and matches `kColleges`' existing
  /// `CollegeRegion.canada` roster of real Canadian schools -- Canada has
  /// always been domestic for hometown/college purposes even before this
  /// enum existed, it just now also gets its own name pool and skin-tone
  /// table rather than sharing USA's.
  bool get isDomestic => this == Country.usa || this == Country.canada;

  /// The `weights.json` `skin_tone_by_country` key for this country --
  /// the enum's own identifier name, not [displayName], so the JSON key
  /// stays a plain identifier (no spaces, e.g. `czechRepublic` not
  /// `Czech Republic`).
  String get weightsKey => name;
}
