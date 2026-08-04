import 'team.dart';

/// The initial 20-team league template: 10 Atlantic teams, 10 Pacific
/// teams. Transcribed from `teams.md`, which remains the editable design
/// source — update both together.
const kInitialLeagueTeams = <Team>[
  // Atlantic Conference
  Team(
    abbreviation: 'BOS',
    location: 'Boston, MA',
    name: 'Boston Beacon',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#0B2D5C',
      secondaryHex: '#F4C542',
      accentHex: '#F4F1E8',
    ),
    identityNote: 'Harbor lights and historic grit.',
  ),
  Team(
    abbreviation: 'BKN',
    location: 'Brooklyn, NY',
    name: 'Brooklyn Comets',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#24124D',
      secondaryHex: '#63D2FF',
      accentHex: '#FFFFFF',
    ),
    identityNote: 'Fast, bright, and city-night energy.',
  ),
  Team(
    abbreviation: 'BUF',
    location: 'Buffalo, NY',
    name: 'Buffalo Blizzard',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#173F5F',
      secondaryHex: '#B9E7F5',
      accentHex: '#FFFFFF',
    ),
    identityNote: 'Lake-effect toughness.',
  ),
  Team(
    abbreviation: 'CLT',
    location: 'Charlotte, NC',
    name: 'Charlotte Crown',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#4B1E3C',
      secondaryHex: '#E5B95C',
      accentHex: '#F7F0E3',
    ),
    identityNote: 'Regal without being precious.',
  ),
  Team(
    abbreviation: 'CIN',
    location: 'Cincinnati, OH',
    name: 'Cincinnati Riveters',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#8C1D40',
      secondaryHex: '#1A2639',
      accentHex: '#E8DCC4',
    ),
    identityNote: 'Industrious, physical, and blue-collar.',
  ),
  Team(
    abbreviation: 'MIA',
    location: 'Miami, FL',
    name: 'Miami Solstice',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#FA5B3D',
      secondaryHex: '#16324F',
      accentHex: '#FFD166',
    ),
    identityNote: 'Heat, color, and late-night confidence.',
  ),
  Team(
    abbreviation: 'MTL',
    location: 'Montreal, QC',
    name: 'Montreal Aurora',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#283593',
      secondaryHex: '#A5E6E1',
      accentHex: '#F7F7FF',
    ),
    identityNote: 'Northern lights and bilingual flair.',
  ),
  Team(
    abbreviation: 'PHL',
    location: 'Philadelphia, PA',
    name: 'Philadelphia Forge',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#9D2235',
      secondaryHex: '#232F3E',
      accentHex: '#C8A45D',
    ),
    identityNote: 'Steel, fire, and relentless work.',
  ),
  Team(
    abbreviation: 'MSP',
    location: 'Minneapolis–St. Paul, MN',
    name: 'Twin Cities Skalds',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#263238',
      secondaryHex: '#8E7CC3',
      accentHex: '#D6E4F0',
    ),
    identityNote: 'Norse storytellers with cool, composed confidence.',
  ),
  Team(
    abbreviation: 'TOR',
    location: 'Toronto, ON',
    name: 'Toronto Talons',
    conference: Conference.atlantic,
    colors: TeamColors(
      primaryHex: '#1D3557',
      secondaryHex: '#E63946',
      accentHex: '#A8DADC',
    ),
    identityNote: 'Sharp, athletic, and international.',
  ),

  // Pacific Conference
  Team(
    abbreviation: 'SDG',
    location: 'San Diego, CA',
    name: 'San Diego Reef',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#005F73',
      secondaryHex: '#F4A261',
      accentHex: '#E9F5F5',
    ),
    identityNote: 'Coastal flow with a colorful edge.',
  ),
  Team(
    abbreviation: 'DEN',
    location: 'Denver, CO',
    name: 'Denver Summit',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#4C1D95',
      secondaryHex: '#F59E0B',
      accentHex: '#EDE9FE',
    ),
    identityNote: 'Altitude, ambition, and mountain scale.',
  ),
  Team(
    abbreviation: 'HFX',
    location: 'Halifax, NS',
    name: 'Halifax Harriers',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#0F4C5C',
      secondaryHex: '#E6B566',
      accentHex: '#F4F1DE',
    ),
    identityNote: 'Atlantic wind and endurance.',
  ),
  Team(
    abbreviation: 'HOU',
    location: 'Houston, TX',
    name: 'Houston Orbit',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#1B4965',
      secondaryHex: '#F25F5C',
      accentHex: '#F7FFF7',
    ),
    identityNote: 'Space-city precision and speed.',
  ),
  Team(
    abbreviation: 'LAS',
    location: 'Las Vegas, NV',
    name: 'Las Vegas Mirage',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#6D1B7B',
      secondaryHex: '#E7B008',
      accentHex: '#FCF6BD',
    ),
    identityNote: 'Desert spectacle with a sharp edge.',
  ),
  Team(
    abbreviation: 'LOU',
    location: 'Louisville, KY',
    name: 'Louisville Larks',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#2F4858',
      secondaryHex: '#E07A5F',
      accentHex: '#F4F1DE',
    ),
    identityNote: 'River-city movement and musical energy.',
  ),
  Team(
    abbreviation: 'PHX',
    location: 'Phoenix, AZ',
    name: 'Phoenix Ember',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#7F1D1D',
      secondaryHex: '#F97316',
      accentHex: '#FFE8A3',
    ),
    identityNote: 'Desert heat and rebirth.',
  ),
  Team(
    abbreviation: 'POR',
    location: 'Portland, OR',
    name: 'Portland Pines',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#1F5F4A',
      secondaryHex: '#D6A84B',
      accentHex: '#EAF4F4',
    ),
    identityNote: 'Evergreen calm and stubbornness.',
  ),
  Team(
    abbreviation: 'SLC',
    location: 'Salt Lake City, UT',
    name: 'Salt Lake City Peaks',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#163B66',
      secondaryHex: '#94D2BD',
      accentHex: '#F1FAEE',
    ),
    identityNote: 'Clean air, heights, and discipline.',
  ),
  Team(
    abbreviation: 'VAN',
    location: 'Vancouver, BC',
    name: 'Vancouver Current',
    conference: Conference.pacific,
    colors: TeamColors(
      primaryHex: '#005F73',
      secondaryHex: '#0A9396',
      accentHex: '#E9D8A6',
    ),
    identityNote: 'Coastal motion and Pacific confidence.',
  ),
];
