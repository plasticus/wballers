import '../domain/country.dart';

/// Player-specific generation seed data (name pools moved to
/// `name_pools_by_country.dart` once [Country] became the shared root of
/// name/hometown/skin-tone generation -- coach generation still uses the
/// old flat `core/generation/name_pools.dart` pools directly, since
/// coaches have no country concept).
///
/// At least 4 cities per [Country] (a direct GM ask, 2026-08-10) so a
/// roster of several players from the same country doesn't keep repeating
/// one hometown. Flavor only -- a mix of North American and international
/// cities, deliberately not the same list as the 20 league cities in
/// `teams.md`. Every non-domestic entry is "City, Country" with the
/// country spelled exactly as [CountryLabel.displayName] -- both
/// `Player.college`'s doc comment and `PlayerDetailScreen`'s
/// `hometown.split(', ').last` parse depend on that exact match.
const kHometownsByCountry = <Country, List<String>>{
  Country.usa: [
    'Springfield, IL',
    'Albany, NY',
    'Richmond, VA',
    'Tulsa, OK',
    'Fresno, CA',
    'Spokane, WA',
    'Baton Rouge, LA',
    'Chattanooga, TN',
  ],
  Country.canada: [
    'Winnipeg, MB',
    'Regina, SK',
    'Saskatoon, SK',
    'Victoria, BC',
  ],
  Country.australia: [
    'Sydney, Australia',
    'Melbourne, Australia',
    'Brisbane, Australia',
    'Perth, Australia',
  ],
  Country.belgium: [
    'Brussels, Belgium',
    'Antwerp, Belgium',
    'Ghent, Belgium',
    'Bruges, Belgium',
  ],
  Country.brazil: [
    'Sao Paulo, Brazil',
    'Rio de Janeiro, Brazil',
    'Belo Horizonte, Brazil',
    'Salvador, Brazil',
  ],
  Country.china: [
    'Shanghai, China',
    'Beijing, China',
    'Guangzhou, China',
    'Shenzhen, China',
  ],
  Country.czechRepublic: [
    'Prague, Czech Republic',
    'Brno, Czech Republic',
    'Ostrava, Czech Republic',
    'Plzen, Czech Republic',
  ],
  Country.finland: [
    'Helsinki, Finland',
    'Tampere, Finland',
    'Turku, Finland',
    'Oulu, Finland',
  ],
  Country.france: [
    'Paris, France',
    'Toulouse, France',
    'Lyon, France',
    'Marseille, France',
  ],
  Country.germany: [
    'Berlin, Germany',
    'Munich, Germany',
    'Hamburg, Germany',
    'Cologne, Germany',
  ],
  Country.greece: [
    'Athens, Greece',
    'Thessaloniki, Greece',
    'Patras, Greece',
    'Heraklion, Greece',
  ],
  Country.hungary: [
    'Budapest, Hungary',
    'Debrecen, Hungary',
    'Szeged, Hungary',
    'Pecs, Hungary',
  ],
  Country.italy: [
    'Rome, Italy',
    'Milan, Italy',
    'Naples, Italy',
    'Turin, Italy',
  ],
  Country.mexico: [
    'Mexico City, Mexico',
    'Guadalajara, Mexico',
    'Monterrey, Mexico',
    'Puebla, Mexico',
  ],
  Country.nigeria: [
    'Lagos, Nigeria',
    'Abuja, Nigeria',
    'Kano, Nigeria',
    'Ibadan, Nigeria',
  ],
  Country.senegal: [
    'Dakar, Senegal',
    'Thies, Senegal',
    'Kaolack, Senegal',
    'Saint-Louis, Senegal',
  ],
  Country.serbia: [
    'Belgrade, Serbia',
    'Novi Sad, Serbia',
    'Nis, Serbia',
    'Kragujevac, Serbia',
  ],
  Country.slovenia: [
    'Ljubljana, Slovenia',
    'Maribor, Slovenia',
    'Celje, Slovenia',
    'Kranj, Slovenia',
  ],
  Country.spain: [
    'Madrid, Spain',
    'Barcelona, Spain',
    'Valencia, Spain',
    'Seville, Spain',
  ],
  Country.turkey: [
    'Istanbul, Turkey',
    'Ankara, Turkey',
    'Izmir, Turkey',
    'Bursa, Turkey',
  ],
};
