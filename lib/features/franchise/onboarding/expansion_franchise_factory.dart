import 'dart:math';

import '../../coach/domain/coach.dart';
import '../../coach/domain/coach_lifecycle.dart';
import '../../coach/generation/coach_generator.dart';
import '../../draft/generation/draft_generator.dart';
import '../../league/domain/team.dart';
import '../../league/generation/league_generator.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../roster/generation/free_agent_pool_generator.dart';
import '../../roster/generation/starting_roster_generator.dart';
import '../../season/domain/season_progress.dart';
import '../../season/generation/season_schedule_generator.dart';
import '../../training/domain/training_plan.dart';
import '../../training/generation/training_coach_generator.dart';
import '../domain/franchise.dart';

/// A curated set of starter palettes for a new expansion club -- onboarding
/// shows these as swatches and the GM picks one (default: a random pick,
/// same "random default, GM-overridable" pattern as the team-to-replace
/// checkbox), rather than a fully free color picker that could collide
/// with another team's existing palette. Full custom color picking is
/// future "Team profile" work (`FLUTTER_APP_PLAN.md`), not onboarding.
///
/// The original 6 all lean dark/moody -- a direct GM ask (2026-08-09,
/// "let's bring in 6 more that are brighter, or semi-bold... Fuschia!
/// Cobalt blue!") added a second bank of 6 bolder/brighter primaries
/// (fuchsia, cobalt, lime, teal, sky, sunset orange) so the swatch grid
/// isn't just dark-navy variations. Appended rather than interleaved --
/// index order here is display order (`onboarding_screen.dart`'s swatch
/// grid), and the original 6 staying first keeps every existing save's
/// picked palette at the same index it was chosen from.
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
  // Fuchsia
  TeamColors(
    primaryHex: '#D6006D',
    secondaryHex: '#FFD60A',
    accentHex: '#FFF0F7',
  ),
  // Cobalt blue
  TeamColors(
    primaryHex: '#0047FF',
    secondaryHex: '#FFB703',
    accentHex: '#F0F4FF',
  ),
  // Lime green
  TeamColors(
    primaryHex: '#5BE12C',
    secondaryHex: '#1B1B1B',
    accentHex: '#F4FFED',
  ),
  // Teal
  TeamColors(
    primaryHex: '#00B4A6',
    secondaryHex: '#FF6B6B',
    accentHex: '#EFFFFC',
  ),
  // Light blue
  TeamColors(
    primaryHex: '#4CC9F0',
    secondaryHex: '#023047',
    accentHex: '#F0FBFF',
  ),
  // Sunset orange
  TeamColors(
    primaryHex: '#FF6B35',
    secondaryHex: '#004E89',
    accentHex: '#FFF4EE',
  ),
];

/// Derives a 3-letter team abbreviation from a club name: the first three
/// letters, uppercased, padded with `X` if the name is too short. Doesn't
/// try to be clever about word boundaries. Real onboarding no longer uses
/// this as the primary path (2026-08-10) -- the GM now picks their own
/// abbreviation directly (`onboarding_screen.dart`'s "Abbreviation"
/// field), since a derived one can't tell "DSM" from "DMD" apart -- this
/// is now only [createExpansionFranchise]'s fallback for a caller that
/// doesn't pass one explicitly (mostly tests).
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
///
/// [emoji] should be one of the 20 `kLeagueTeamPool` teams *not* drawn
/// into this playthrough's league -- onboarding's picker only offers
/// those, so nothing visible in the league shares the GM's own emoji.
/// Not asserted here, same reasoning as [colors].
///
/// [coach] is optional -- when given, it's used as-is instead of
/// generating one internally (onboarding's Head Coach selection step
/// generates 3 candidates via `generateCoachCandidates` and passes the
/// GM's pick straight through here). Omitted, this falls back to the
/// original single-random-coach behavior, which every pre-existing
/// caller (mostly tests) still relies on.
///
/// [homeState]/[abbreviation] are both optional (2026-08-10, a direct GM
/// report with a screenshot: the GM's own club was showing "Deebers" /
/// "DEE · Des Moines" instead of the AI pool's "Chicago Gale" / "CHI ·
/// Chicago, IL" convention) -- real onboarding always passes both now
/// (new "State/Province" and "Abbreviation" fields, `onboarding_screen.dart`),
/// but every pre-existing caller (mostly tests, dozens of them, none of
/// which care about this distinction) keeps working unchanged: omitting
/// [homeState] leaves [Team.location] as bare [homeCity] exactly like
/// before, and omitting [abbreviation] falls back to [deriveTeamAbbreviation].
/// [clubName] itself is unchanged -- always [Team.name] verbatim -- but
/// onboarding now asks the GM to type the *whole* branded name directly
/// ("Des Moines Deebers," or "Iowa Deebers" if they'd rather name the
/// club after the state than the city) instead of a bare nickname the
/// UI used to silently prepend [homeCity] to only in its own preview,
/// never in the actual saved [Team.name] -- that mismatch was the real
/// bug underneath the GM's report, not just a missing field.
Franchise createExpansionFranchise({
  required String gmName,
  required String clubName,
  required String homeCity,
  String? homeState,
  String? abbreviation,
  required Conference conference,
  required int simulationSeed,
  required String replacedTeamAbbreviation,
  required TeamColors colors,
  required String emoji,
  Coach? coach,
  PortraitWeights? portraitWeights,
  PortraitManifest? portraitManifest,
}) {
  final team = Team(
    abbreviation: abbreviation ?? deriveTeamAbbreviation(clubName),
    location: (homeState == null || homeState.isEmpty)
        ? homeCity
        : '$homeCity, $homeState',
    name: clubName,
    conference: conference,
    colors: colors,
    identityNote: 'A new franchise chasing its first banner.',
    emoji: emoji,
  );

  final roster = generateStartingRoster(
    simulationSeed + 1,
    portraitWeights: portraitWeights,
  );

  // The hand-placed "grizzled vet" narrative slot is always roster index
  // 0 (`starting_roster_generator.dart`'s own doc comment: only
  // *positions* get shuffled per-franchise, never the roster list order)
  // -- captured here, once, since nothing else in the game keeps a
  // player's data around once she eventually leaves the roster (a direct
  // GM ask, 2026-08-12: the pre-game screen's Analyst panel wants to seat
  // her there for real once she retires). See `Franchise
  // .narrativeVeteranPlayerId`'s own doc comment.
  final narrativeVeteran = roster.first.player;

  // The one standard position the 4 narrative slots (roster indices 0-3)
  // don't cover -- a direct GM ask (2026-08-14): the Day-0 free agent
  // should be generated to fill exactly this position, completing a real
  // starting five instead of landing wherever chance puts her. See
  // `missingStartingPosition`'s own doc comment.
  final missingPosition = missingStartingPosition(roster);

  // One player short of a full active roster on purpose -- see
  // `generateStartingRoster`'s doc comment. `freeAgents` is what the GM
  // has to sign from to fill it, generated once here and persisted from
  // here on (not regenerated every save/reload).
  final freeAgents = generateFreeAgentPool(
    Random(simulationSeed + kFreeAgentPoolSeedOffset),
    portraitWeights: portraitWeights,
    plantedPosition: missingPosition,
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
    coach:
        coach ??
        generateCoach(
          Random(simulationSeed),
          minAge: kCoachInitialLeagueMinAge,
          maxAge: kCoachInitialLeagueMaxAge,
          portraitWeights: portraitWeights,
          portraitManifest: portraitManifest,
        ),
    roster: roster,
    simulationSeed: simulationSeed,
    replacedTeamAbbreviation: replacedTeamAbbreviation,
    league: league,
    seasonProgress: SeasonProgress(
      schedule: schedule,
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
    trainingCoaches: generateTrainingCoaches(
      Random(simulationSeed + kTrainingCoachSeedOffset),
    ),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: kPreseasonWeek,
    freeAgents: freeAgents,
    // The real prospects for this franchise's *first* draft (the one that
    // resolves once season 0 wraps), rolled here rather than waiting for
    // that transition -- same "seasoned a full season ahead" reasoning
    // [Franchise.upcomingDraftClass]'s own doc comment covers.
    // `kSeasonSeedSpan + kDraftClassSeedOffset` is season 1's own future
    // [Franchise.seasonSeed] plus the real-class offset -- exactly what
    // `beginNextSeason` would compute for `newDraftClass` when season 0
    // transitions into season 1, just computed now instead of then.
    upcomingDraftClass: generateDraftClass(
      Random(simulationSeed + kSeasonSeedSpan + kDraftClassSeedOffset),
      portraitWeights: portraitWeights,
    ),
    narrativeVeteranPlayerId: narrativeVeteran.id,
    narrativeVeteranName: narrativeVeteran.name,
    narrativeVeteranAppearance: narrativeVeteran.appearance,
  );
}
