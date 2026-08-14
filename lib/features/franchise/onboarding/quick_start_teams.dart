import '../../league/domain/team.dart';

/// One club's identity -- name, city/state, abbreviation, colors, emoji,
/// and a small pool of hokey candidate GM names -- with no roster and no
/// conference. A direct GM ask (2026-08-14): "I'm tired of typing in my
/// team info on each restart," followed immediately by "put in a random
/// name for the GM. Hokey names that sound like women from the city/
/// emoji selected." `OnboardingScreen`'s own text fields stay exactly as
/// editable after a tap as they were before it; this just fills them in
/// (`_applyQuickStart` picks one of [gmNames] at random, same "random
/// default, GM-overridable" pattern the colors/emoji pickers already
/// use).
class QuickStartTeam {
  const QuickStartTeam({
    required this.clubName,
    required this.homeCity,
    required this.homeState,
    required this.abbreviation,
    required this.colors,
    required this.emoji,
    required this.gmNames,
  });

  final String clubName;
  final String homeCity;
  final String homeState;
  final String abbreviation;
  final TeamColors colors;
  final String emoji;
  final List<String> gmNames;
}

/// 5 curated identities, all checked against `kLeagueTeamPool`'s 40
/// entries -- no abbreviation or emoji collides with anything a GM could
/// actually end up playing against. Deliberately central/dual-coast-
/// agnostic cities (a direct part of the ask: "pretty central, so could
/// fall in either Atlantic or Pacific") -- `OnboardingScreen`'s Conference
/// picker is untouched by a quick-start pick, same as GM name.
const kQuickStartDesMoinesDragons = QuickStartTeam(
  clubName: 'Des Moines Dragons',
  homeCity: 'Des Moines',
  homeState: 'IA',
  abbreviation: 'DSM',
  colors: TeamColors(
    primaryHex: '#1C3B2C',
    secondaryHex: '#D4AF37',
    accentHex: '#F4F1DE',
  ),
  emoji: '🐉',
  gmNames: ['Blaze Cornwell', 'Ember Kowalczyk', 'Sable Thornbury'],
);

const kQuickStartWichitaWitches = QuickStartTeam(
  clubName: 'Wichita Witches',
  homeCity: 'Wichita',
  homeState: 'KS',
  abbreviation: 'WIC',
  colors: TeamColors(
    primaryHex: '#2D1B4E',
    secondaryHex: '#7B2CBF',
    accentHex: '#E0AAFF',
  ),
  emoji: '🧙',
  gmNames: ['Wanda Hexworth', 'Hazel Broomfield', 'Circe Winterbourne'],
);

/// Bison, not "Stampede" -- `kLeagueTeamPool` already has a Calgary
/// Stampede (a direct GM catch, 2026-08-14: "don't we already have a
/// team that's Stampede?").
const kQuickStartOmahaBison = QuickStartTeam(
  clubName: 'Omaha Bison',
  homeCity: 'Omaha',
  homeState: 'NE',
  abbreviation: 'OMA',
  colors: TeamColors(
    primaryHex: '#4A2C2A',
    secondaryHex: '#C08552',
    accentHex: '#F5E6CA',
  ),
  emoji: '🦬',
  gmNames: ['Dakota Byrnes', 'Prairie Combs', 'Sage Thundersen'],
);

/// Aviators, not "Wildfire" -- the GM's own call ("I really don't like
/// Wildfire, choose something else"), 2026-08-14.
const kQuickStartKansasCityAviators = QuickStartTeam(
  clubName: 'Kansas City Aviators',
  homeCity: 'Kansas City',
  homeState: 'MO',
  abbreviation: 'KCY',
  colors: TeamColors(
    primaryHex: '#0B3D91',
    secondaryHex: '#B0BEC5',
    accentHex: '#E8F1F8',
  ),
  emoji: '✈️',
  gmNames: ['Amelia Jetstream', 'Skyler Vance', 'Breezy Callahan'],
);

/// Dallas, TX -- the one city in this set left to me to pick (a direct
/// GM ask: "another midwest-ish or texas city we don't have"). Not
/// already in `kLeagueTeamPool` (only Houston and Oklahoma City are).
const kQuickStartDallasMustangs = QuickStartTeam(
  clubName: 'Dallas Mustangs',
  homeCity: 'Dallas',
  homeState: 'TX',
  abbreviation: 'DAL',
  colors: TeamColors(
    primaryHex: '#2B2D42',
    secondaryHex: '#EF8354',
    accentHex: '#F4F1DE',
  ),
  emoji: '🐎',
  gmNames: ['Reata Steele', 'Sierra Colton', 'Dusty Calloway'],
);

const kQuickStartTeams = <QuickStartTeam>[
  kQuickStartDesMoinesDragons,
  kQuickStartWichitaWitches,
  kQuickStartOmahaBison,
  kQuickStartKansasCityAviators,
  kQuickStartDallasMustangs,
];
