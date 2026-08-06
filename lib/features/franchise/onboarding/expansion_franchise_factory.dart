import 'dart:math';

import '../../coach/generation/coach_generator.dart';
import '../../league/domain/team.dart';
import '../../league/generation/league_generator.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../roster/domain/starting_lineup.dart';
import '../../roster/generation/starting_roster_generator.dart';
import '../../season/domain/season_progress.dart';
import '../../season/generation/season_schedule_generator.dart';
import '../domain/franchise.dart';

/// A curated set of starter palettes for a new expansion club -- onboarding
/// shows these as swatches and the GM picks one (default: a random pick,
/// same "random default, GM-overridable" pattern as the team-to-replace
/// checkbox), rather than a fully free color picker that could collide
/// with another team's existing palette. Full custom color picking is
/// future "Team profile" work (`FLUTTER_APP_PLAN.md`), not onboarding.
const kStarterPalettes = <TeamColors>[
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
/// try to be clever about word boundaries -- a GM who wants a specific
/// abbreviation can get that from the future team-profile editor.
String deriveTeamAbbreviation(String clubName) {
  final lettersOnly = clubName.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  final letters = lettersOnly.padRight(3, 'X');
  return letters.substring(0, 3);
}

/// Builds a brand-new expansion franchise: the GM persona [gmName], a
/// fresh [Team] (not tied to any of the 20 original teams -- see the note
/// on [Franchise.team]), a generated head coach (see the note on `Coach`
/// -- the GM doesn't invent their own coach's identity, they get hired
/// staff), and a weak generated starting roster.
///
/// [simulationSeed] should come from real entropy at creation time (e.g.
/// `Random().nextInt(...)`, not a fixed seed); everything downstream of
/// that seed is deterministic. The coach and roster are generated from
/// deliberately offset seeds derived from [simulationSeed] so their random
/// streams don't correlate with each other.
///
/// [portraitWeights] is optional -- omit it (e.g. in tests) to skip
/// portrait generation entirely, leaving every generated `Player`/`Coach`
/// with `appearance: null`. The real onboarding flow awaits
/// `portraitWeightsProvider`/`portraitManifestProvider` and passes both in.
/// [portraitManifest] is only used for the coach's shoulders (see
/// `generateCoach`'s doc comment) -- omitting it just leaves those `null`.
///
/// [replacedTeamAbbreviation] must be one of the 20 teams
/// `drawLeagueTeams(Random(simulationSeed + kLeagueDrawSeedOffset))`
/// actually draws for this [simulationSeed] -- not just any
/// `kLeagueTeamPool` abbreviation. `generateLeague` (called internally,
/// see [Franchise.league]) asserts the resulting AI league has exactly 19
/// teams, which fails if [replacedTeamAbbreviation] wasn't actually drawn.
/// Onboarding gets this right by construction (it draws the league first,
/// then only offers picks from within that draw); a caller building a
/// franchise directly must keep the two in sync itself. See the note on
/// [Franchise.replacedTeamAbbreviation].
///
/// [colors] should be one of [kStarterPalettes] -- the GM's pick from
/// onboarding's curated swatch picker. Not asserted here (unlike
/// [replacedTeamAbbreviation]'s pool membership); an arbitrary [TeamColors]
/// is harmless, just outside the curated set onboarding actually offers.
Franchise createExpansionFranchise({
  required String gmName,
  required String clubName,
  required String homeCity,
  required Conference conference,
  required int simulationSeed,
  required String replacedTeamAbbreviation,
  required TeamColors colors,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final team = Team(
    abbreviation: deriveTeamAbbreviation(clubName),
    location: homeCity,
    name: clubName,
    conference: conference,
    colors: colors,
    identityNote: 'A new franchise chasing its first banner.',
  );

  final roster = generateStartingRoster(
    simulationSeed + 1,
    portraitWeights: portraitWeights,
  );

  final league = generateLeague(
    simulationSeed: simulationSeed,
    replacedTeamAbbreviation: replacedTeamAbbreviation,
    portraitWeights: portraitWeights,
  );

  // The full 20-team league this playthrough actually plays, with [team]
  // substituted in for the AI team it replaced -- same shape
  // `LeagueScreen` builds for display, needed here so the schedule
  // includes the GM's own club rather than the team it replaced.
  final scheduleTeams = [...league.aiTeams.map((aiTeam) => aiTeam.team), team];
  final schedule = generateSeasonSchedule(
    scheduleTeams,
    Random(simulationSeed + kSeasonScheduleSeedOffset),
  );

  return Franchise(
    id: 'franchise-$simulationSeed',
    gmName: gmName,
    team: team,
    coach: generateCoach(
      Random(simulationSeed),
      portraitWeights: portraitWeights,
      portraitManifest: portraitManifest,
    ),
    roster: roster,
    startingLineup: StartingLineup.bestAvailable(roster),
    simulationSeed: simulationSeed,
    replacedTeamAbbreviation: replacedTeamAbbreviation,
    league: league,
    seasonProgress: SeasonProgress(
      schedule: schedule,
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
  );
}
