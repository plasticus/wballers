import '../../coach/domain/coach.dart';
import '../../coach/domain/coach_stats.dart';
import '../../league/domain/team.dart';
import '../../roster/generation/starting_roster_generator.dart';
import '../domain/franchise.dart';

/// A handful of curated starter palettes for a new expansion club, picked
/// deterministically from [simulationSeed]. Full custom color picking is
/// future "Team profile" work (`FLUTTER_APP_PLAN.md`), not onboarding.
const _starterPalettes = <TeamColors>[
  TeamColors(
    primaryHex: '#14213D',
    secondaryHex: '#FCA311',
    accentHex: '#E5E5E5',
  ),
  TeamColors(
    primaryHex: '#3A0CA3',
    secondaryHex: '#F72585',
    accentHex: '#F1FAEE',
  ),
  TeamColors(
    primaryHex: '#014F86',
    secondaryHex: '#89C2D9',
    accentHex: '#F8F9FA',
  ),
  TeamColors(
    primaryHex: '#6A040F',
    secondaryHex: '#F4A261',
    accentHex: '#FDF0D5',
  ),
  TeamColors(
    primaryHex: '#1B4332',
    secondaryHex: '#95D5B2',
    accentHex: '#F1FAEE',
  ),
  TeamColors(
    primaryHex: '#3C096C',
    secondaryHex: '#C77DFF',
    accentHex: '#F8F0FC',
  ),
];

/// Derives a 3-letter team abbreviation from a club name: the first three
/// letters, uppercased, padded with `X` if the name is too short. Doesn't
/// try to be clever about word boundaries -- a coach who wants a specific
/// abbreviation can get that from the future team-profile editor.
String deriveTeamAbbreviation(String clubName) {
  final lettersOnly = clubName.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  final letters = lettersOnly.padRight(3, 'X');
  return letters.substring(0, 3);
}

/// Builds a brand-new expansion franchise: a fresh [Team] (not tied to any
/// of the 20 original teams -- see the note on [Franchise.team]), a coach
/// with neutral starting stats, and a weak generated starting roster.
/// [simulationSeed] should come from real entropy at creation time (e.g.
/// `Random().nextInt(...)`, not a fixed seed); everything downstream of
/// that seed is deterministic.
Franchise createExpansionFranchise({
  required String coachName,
  required String clubName,
  required String homeCity,
  required Conference conference,
  required int simulationSeed,
}) {
  final team = Team(
    abbreviation: deriveTeamAbbreviation(clubName),
    location: homeCity,
    name: clubName,
    conference: conference,
    colors: _starterPalettes[simulationSeed.abs() % _starterPalettes.length],
    identityNote: 'A new franchise chasing its first banner.',
  );

  return Franchise(
    id: 'franchise-$simulationSeed',
    team: team,
    coach: Coach(name: coachName, stats: CoachStats.neutral),
    roster: generateStartingRoster(simulationSeed),
    simulationSeed: simulationSeed,
  );
}
