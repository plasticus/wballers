/// The North American subset of [kHometowns] -- split out from the
/// international subset below only so the latter can be exported and
/// picked from directly (`kInternationalHometowns`) without fragile-slicing
/// indices out of the combined pool. [kHometowns] itself is still every
/// other generator's single pool, in the exact same concatenated order as
/// before this split.
const _kNorthAmericanHometowns = <String>[
  'Springfield, IL',
  'Albany, NY',
  'Richmond, VA',
  'Tulsa, OK',
  'Fresno, CA',
  'Spokane, WA',
  'Baton Rouge, LA',
  'Chattanooga, TN',
  'Winnipeg, MB',
  'Regina, SK',
  'Saskatoon, SK',
  'Victoria, BC',
];

/// The international subset of [kHometowns] -- exported so
/// `free_agent_pool_generator.dart`'s planted Day-0 free agent (a direct
/// GM ask: "an international rookie") can pick from these directly rather
/// than leaving it to a random roll across the full pool, which could just
/// as easily land on a domestic city.
const kInternationalHometowns = <String>[
  'Sydney, Australia',
  'Melbourne, Australia',
  'Paris, France',
  'Madrid, Spain',
  'Lagos, Nigeria',
  'Nairobi, Kenya',
  'Seoul, South Korea',
  'Manila, Philippines',
  'Zagreb, Croatia',
  'Belgrade, Serbia',
  'Toulouse, France',
  'Osaka, Japan',
  'Accra, Ghana',
  'Dakar, Senegal',
  'Bogota, Colombia',
  'Santiago, Chile',
  'Auckland, New Zealand',
  'Warsaw, Poland',
];

/// Player-specific generation seed data (name pools moved to
/// `core/generation/name_pools.dart` once coach generation needed them
/// too). Flavor only — a mix of North American and international cities,
/// deliberately not the same list as the 20 league cities in `teams.md`.
const kHometowns = <String>[
  ..._kNorthAmericanHometowns,
  ...kInternationalHometowns,
];
